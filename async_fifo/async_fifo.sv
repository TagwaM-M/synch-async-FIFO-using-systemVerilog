`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/07/2026 10:59:38 AM
// Design Name: 
// Module Name: fifo
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


module fifo #(
    // parameters
    parameter WIDTH = 32,
    parameter DEPTH =16
)
(   //ports
    //----------------------------
    //clk and reset write
    input logic wr_clk_i,
    input logic wr_rst_n_i,
    //----------------------------
    //write 
    input logic [WIDTH-1 : 0] wdata_i,
    input logic wr_en_i,
    output logic full_o,
    //------------------------------
    //read clks
    input logic rd_clk_i,
    input logic rd_rst_n_i,
    
    //read 
    output logic [WIDTH-1 : 0] rdata_o,
    input logic rd_en_i,
    output logic empty_o,
    //-------------------------------
    //over/under flow
    output logic overflow_o,
    output logic underflow_o
    );

    //time scale
    timeunit 1ns;
    timeprecision 100ps;
    //local parametrs
    localparam ADD_WIDTH = $clog2(DEPTH); //determine the number of bits needed to address the depth by getting the depth
    //local signal
    logic [ADD_WIDTH:0] rptr,wptr;
    logic [ADD_WIDTH:0] wgray, rgray;
    logic full, empty;
    //register array
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    
    //write operation
    always_ff @(posedge wr_clk_i or negedge wr_rst_n_i) begin
        if(!wr_rst_n_i) begin
            wptr <= 0;
        end else begin
            if (wr_en_i && !full) begin 
                mem[wptr[ADD_WIDTH-1:0]] <= wdata_i;
                wptr <= wptr + 1'b1;
            end
        end
    end
    //read operation
    always_ff @(posedge rd_clk_i or negedge rd_rst_n_i) begin
        if(!rd_rst_n_i) begin
            rptr <= 0;
        end else begin
            if (rd_en_i && !empty) begin 
                rptr <= rptr + 1'b1;
                rdata_o <= mem[rptr[ADD_WIDTH-1:0]];
            end
        end
    end
    //over/underflow 
    assign wgray = wptr ^(wptr >>1);
    assign rgray = rptr ^(rptr >>1);
    
    // write pointer gray , read domain 
    (* ASYNC_REG = "TRUE" *) logic [ADD_WIDTH:0] wgray_sync1, wgray_sync2;
    always_ff @(posedge rd_clk_i or negedge rd_rst_n_i) begin
        if(!rd_rst_n_i) begin 
            wgray_sync1 <= 0;
            wgray_sync2 <= 0;
        end else begin 
            wgray_sync1 <= wgray;
            wgray_sync2 <= wgray_sync1;
        end
    end
    
   (* ASYNC_REG = "TRUE" *) logic [ADD_WIDTH:0] rgray_sync1, rgray_sync2;
    always_ff @(posedge wr_clk_i or negedge wr_rst_n_i) begin 
        if(!wr_rst_n_i) begin
            rgray_sync1 <= 0;
            rgray_sync2 <= 0;
        end else begin 
            rgray_sync1 <= rgray;
            rgray_sync2 <= rgray_sync1;
            
        end
    end
    assign empty = (rgray == wgray_sync2);
    
    assign full = (wgray == {~rgray_sync2[ADD_WIDTH:ADD_WIDTH-1], rgray_sync2[ADD_WIDTH-2:0]});
    
    assign full_o = full;
    assign empty_o = empty;
    //overflow 
    always_ff @(posedge wr_clk_i or negedge wr_rst_n_i) begin 
        if(!wr_rst_n_i) begin
            overflow_o <= 0;
        end else begin
            overflow_o <= wr_en_i && full;
        end
    end
    always_ff @(posedge rd_clk_i or negedge rd_rst_n_i) begin 
        if(!rd_rst_n_i) begin
            underflow_o <= 0;
        end else begin
            underflow_o <= rd_en_i && empty;
        end
    end

    
endmodule
