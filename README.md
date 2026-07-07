# FIFO Design in SystemVerilog — Synchronous & Asynchronous (CDC)

Two parameterized FIFOs written from scratch in SystemVerilog, verified in simulation, and taken through full synthesis and implementation on a Xilinx Zynq UltraScale+ device. The synchronous FIFO covers the core pointer/flag mechanics; the asynchronous FIFO adds clock-domain-crossing (CDC) with Gray-coded pointers and two-flop synchronizers.

**Target device:** `xczu9eg-ffvb1156-1` (Trenz TEB0911 module)
**Tools:** Vivado 2020.2, XSim
**Language:** SystemVerilog (IEEE 1800)

---

## Why two FIFOs

A synchronous FIFO and an asynchronous FIFO look similar but are fundamentally different circuits. Building both — and reading the reports that distinguish them — is the point:

- The **synchronous** FIFO teaches the pointer/wrap/flag mechanics and the RTL-to-timing-closure flow.
- The **asynchronous** FIFO teaches CDC: why binary pointers can't cross clock domains, why Gray code fixes it, and how to read a `report_cdc` output.

---

## 1. Synchronous FIFO

Single clock domain. Read and write share `clk_i`.

**Parameters:** `WIDTH = 32`, `DEPTH = 16`
**Read latency:** 1 cycle (registered output — `rdata_o` valid the cycle after `rd_en`)
**Flag scheme:** equal pointers disambiguated by a last-operation tracker (write vs. read) to separate full from empty.
**Extras:** registered `overflow` / `underflow` status pulses.

### Utilization (out-of-context synthesis)

| Resource | Count |
|---|---|
| LUTs | 179 |
| Flip-flops | 555 |
| MUXF7 / MUXF8 | 64 / 32 |
| Block RAM | 0 |

**Engineering note — why zero BRAM.** The 16×32 memory (512 bits) is far too small to justify a 36 Kb block-RAM tile, so the synthesizer built it out of flip-flops plus a LUT-based 16-to-1 read multiplexer (the MUXF7/MUXF8 trees). This is the correct choice at this depth. A deeper memory (e.g. an accelerator line buffer) would instead be written for synchronous-read BRAM inference — a deliberate coding difference, not an accident of size.

### Timing (post-implementation, 100 MHz constraint)

| Metric | Value |
|---|---|
| Setup WNS | +7.511 ns (MET) |
| Hold WHS | +0.041 ns (MET) |
| Failing endpoints | 0 |
| Critical-path data delay | 2.294 ns (16% logic / 84% routing) |
| Estimated Fmax | ≈ 400 MHz |

Critical path: write pointer → memory write-enable decode (`wptr_reg → mem_reg/CE`), 2 logic levels. Routing-dominated, as expected for a small design.

---

## 2. Asynchronous FIFO (CDC)

Independent write and read clocks. Built for a 96 MHz → 60 MHz crossing.

**Parameters:** `WIDTH = 32`, `DEPTH = 16`
**Write domain:** `wr_clk_i` @ 96 MHz  **Read domain:** `rd_clk_i` @ 60 MHz

### CDC architecture

- **Dual-clock memory** — written on `wr_clk`, read on `rd_clk`.
- **(N+1)-bit pointers** — one extra MSB (the "lap" bit) distinguishes full from empty when the address bits match.
- **Binary for addressing, Gray for crossing** — pointers increment in binary (to address memory) and are converted to Gray (`g = b ^ (b >> 1)`) before crossing domains, so only one bit changes per step and a mid-flight sample can only ever land on the old or new value — never a phantom.
- **Two-flop synchronizers** — each Gray pointer is resynchronized into the opposite domain (write pointer → read domain for `empty`; read pointer → write domain for `full`).
- **`empty`** computed in the read domain (`rgray == wgray_sync2`); **`full`** computed in the write domain (top two Gray bits inverted — the standard reflected-code full condition).
- **`ASYNC_REG = "TRUE"`** on all four synchronizer flops so the placer packs each pair into one slice and never optimizes them away.

### Constraints

```tcl
create_clock -period 10.417 -name wr_clk [get_ports wr_clk_i]   # 96 MHz
create_clock -period 16.667 -name rd_clk [get_ports rd_clk_i]   # 60 MHz

set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]
```

The `set_clock_groups -asynchronous` line is essential: it tells static timing analysis not to time paths *between* the two domains (those crossings are protected by the synchronizers, not by timing), which prevents false failures on the pointer crossings.

### Timing (post-implementation, per domain)

| Domain | Setup WNS | Hold WHS | Failing endpoints |
|---|---|---|---|
| `rd_clk` (60 MHz) | +14.500 ns (MET) | +0.066 ns (MET) | 0 |
| `wr_clk` (96 MHz) | +8.105 ns (MET) | +0.071 ns (MET) | 0 |

Both domains close timing with large margins, and — thanks to the async clock group — there are **no inter-clock timing paths** reported. The worst-case hold paths are the `sync1 → sync2` synchronizer hops, placed in a single slice by `ASYNC_REG`.

### CDC report (`report_cdc`)

| Source → Dest | Endpoints | Safe | Unsafe |
|---|---|---|---|
| `wr_clk → rd_clk` | 37 | 33 | 4 |
| `rd_clk → wr_clk` | 5 | 1 | 4 |

**Reading this correctly:** the "Safe" endpoints are the Gray pointer bits crossing through the two-flop synchronizers — recognized and certified. The four "Unsafe" endpoints on each side are the **first-stage synchronizer flops themselves** — the flops that are *designed* to absorb metastability. Vivado flags them because it cannot auto-certify a hand-written synchronizer the way it certifies its own `XPM_CDC` library macros (hence its recommendation to use `XPM_CDC`).

The design is functionally correct — this is the canonical hand-built async-FIFO structure. In production, the synchronizers would be instantiated as pre-verified `xpm_cdc_gray` macros, which report as fully Safe. Building it by hand once was the point: it makes clear what those macros contain.

---

## Verification

Both FIFOs were validated in XSim with directed testbenches:

- **Reset behavior** — empty after reset, flags correct.
- **Fill to full** — `full` asserts after `DEPTH` writes; further writes ignored, `overflow` pulses.
- **Drain to empty** — data reads back in FIFO order (0…15); `empty` asserts; reads-while-empty ignored, `underflow` pulses.
- **Async FIFO** — two independent clocks (96/60 MHz) with settling time between phases to observe synchronizer latency; data verified to cross domains intact.

---

## Repository structure

```
.
├── sync_fifo/
│   ├── fifo.sv                 # synchronous FIFO
│   ├── fifo_tb.sv              # directed testbench
│   └── fifo_timing.xdc         # 100 MHz clock constraint
├── async_fifo/
│   ├── async_fifo.sv           # asynchronous (CDC) FIFO
│   ├── async_fifo_tb.sv        # dual-clock testbench
│   └── async_fifo_timing.xdc   # two clocks + async clock group
└── README.md
```

---

## Key takeaways

- Full RTL-to-hardware flow driven in Tcl: `synth_design` / `launch_runs` → `report_utilization` → `report_timing_summary` → `report_cdc`.
- Timing closure read and interpreted (WNS/WHS, critical-path logic-vs-route split, Fmax from slack).
- CDC handled correctly: Gray coding, two-flop synchronizers, `ASYNC_REG`, and an async clock group — plus the judgment to interpret a "Critical" CDC severity as a hand-written-synchronizer limitation rather than a functional bug.

---

## References

- [FIFO Design and Implementation Tutorial in RTL SystemVerilog](https://medium.com/@aiclab.official/fifo-design-and-implementation-tutorial-in-rtl-systemverilog-f11d4c78e3e8) — AIClab, the tutorial this project is based on.
