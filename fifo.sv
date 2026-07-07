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
    //clk and reset
    input logic clk_i,
    input logic rst_n_i,
    //----------------------------
    //write 
    input logic [WIDTH-1 : 0] wdata_i,
    input logic wr_en_i,
    output logic full_o,
    //------------------------------
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
    logic [ADD_WIDTH-1:0] rptr,wptr;
    logic full, empty;
    logic last_read;
    //register array
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    
    //write operation
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            wptr <= 0;
        end else begin
            if (wr_en_i && !full) begin 
                mem[wptr] <= wdata_i;
                wptr <= wptr + 1'b1;
            end
        end
    end
    //read operation
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            rptr <= 0;
        end else begin
            if (rd_en_i && !empty) begin 
                rptr <= rptr + 1'b1;
                rdata_o <= mem[rptr];
            end
        end
    end
    //last opertation tracker
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            last_read <= 1;
        end else begin
            if (rd_en_i && !empty) begin 
                last_read <= 1;
            end else if (wr_en_i && !full) begin
                last_read <= 0;
            end else begin
                last_read <= last_read;
            end
        end
    end
    //over/underflow 
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if(!rst_n_i) begin
            overflow_o <= 1'b0;
            underflow_o <= 1'b0;
        end else begin 
            overflow_o <= wr_en_i && full;
            underflow_o <= rd_en_i && empty;
        end
    end
    //full/empty flag
    assign full = (wptr == rptr) && !last_read;
    assign empty = (wptr == rptr) && last_read;
    
    assign full_o = full;
    assign empty_o = empty;
    
endmodule
