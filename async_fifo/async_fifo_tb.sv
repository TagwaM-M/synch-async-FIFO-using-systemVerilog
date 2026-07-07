`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/07/2026 11:52:22 AM
// Design Name: 
// Module Name: fifo_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_tb;
    //parameters
    localparam int WIDTH = 32;
    localparam int DEPTH = 16;
    
    //DUT signal 
    //clk & reset
    logic wr_clk_i;
    logic rd_clk_i;
    logic wr_rst_n_i;
    logic rd_rst_n_i;
    //write
    logic [WIDTH-1:0] wdata_i;
    logic wr_en_i;
    logic full_o;
    //read
    logic [WIDTH-1:0] rdata_o;
    logic rd_en_i;
    logic empty_o;
    //over/underflow
    logic overflow_o;
    logic underflow_o;
    
    //bookkeeping
    //int errors = 0;
    //int reads_checked = 0;
    
    // Reference model: a queue mirroring what SHOULD be inside the FIFO, in
    // order. push_back on every successful write, pop_front on every read.
    
    //logic [WIDTH-1:0] model_q;
    
    //DUT instantiation
    int i;
    
    fifo #( .WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .wr_clk_i(wr_clk_i),
        .rd_clk_i(rd_clk_i),
        .wr_rst_n_i(wr_rst_n_i),
        .rd_rst_n_i(rd_rst_n_i),
        .wdata_i(wdata_i),
        .wr_en_i(wr_en_i),
        .full_o(full_o),
        .rdata_o(rdata_o),
        .rd_en_i(rd_en_i),
        .empty_o(empty_o),
        .overflow_o(overflow_o),
        .underflow_o(underflow_o)
    );
    // clock = 96MHz
    initial wr_clk_i = 0;
    always #5.21 wr_clk_i = ~wr_clk_i;
    
    //read clk 
    initial rd_clk_i = 0;
    always #8.33 rd_clk_i = ~rd_clk_i;
    // SCOREBOARD
    // rdata_o is a REGISTERED output: a value read at edge T appears on
    // rdata_o just after edge T, so it is sampled at edge T+1. We therefore
    // pipeline the expected value by one cycle to line up with that latency.
    //logic expected_valid;
    //logic [WIDTH-1:0] expected_data;
    
    // main 
    initial begin 
        // reset 
        wr_rst_n_i = 0;
        rd_rst_n_i = 0;
        wr_en_i = 0;
        rd_en_i = 0;
        wdata_i = 0;
        repeat (2) @(negedge wr_clk_i);
        wr_rst_n_i = 1;
        repeat (2) @(negedge rd_clk_i);
        rd_rst_n_i = 1;
        $display("after reset : full =%b empty = %b", full_o, empty_o);
        
        // write 0-15
        for( i =0; i<DEPTH; i = i+1) begin
            @(negedge wr_clk_i);
            wr_en_i = 1;
            wdata_i = i;
        end 
        @(negedge wr_clk_i);
        wr_en_i = 0;
        $display("after 16 write : full =%b  (expected full =1) empty = %b", full_o, empty_o);
        
        //allow write to cross to read domain
        
        repeat(4) @(negedge rd_clk_i);
        $display("after 16 write : full =%b  (expected full =1 , empty =0) empty = %b", full_o, empty_o);
            
        //read everything 
        $display("reading check");
        
        for(i=0; i<DEPTH; i = i+1) begin 
            @(negedge rd_clk_i);
            rd_en_i = 1;
            @(negedge rd_clk_i);
            rd_en_i = 0;
            $display("read #%0d => %0d", i, rdata_o);
            
        end
        $display("after draining: full =%b  (expected empty =1) empty = %b", full_o, empty_o);
        
        // try reading while empty 
        @(negedge rd_clk_i);
        rd_en_i = 1;
        @(negedge rd_clk_i);
        rd_en_i = 0;
        $display("reading while empty: underflow =%b  (expected underflow=1) empty = %b", underflow_o, empty_o);
        $display("Done");
        $finish;
    end
endmodule
