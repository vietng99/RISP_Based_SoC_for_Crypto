`timescale 1ns / 1ps
// Single-port RAM with byte write enables, read latency 1, read-first.
// Replaces Vivado blk_mem_gen_1 (Write_Depth_A 2048, 32-bit, BRAM_Controller
// mode driven by axi_bram_ctrl). Output holds while ena = 0.
module ram_sp_be #(
    parameter integer DEPTH = 2048,
    parameter integer AW    = 11
) (
    input  wire          clka,
    input  wire          ena,
    input  wire [3:0]    wea,
    input  wire [AW-1:0] addra,
    input  wire [31:0]   dina,
    output reg  [31:0]   douta
);
    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0;
        douta = 32'h0;
    end

    always @(posedge clka) begin
        if (ena) begin
            douta <= mem[addra];
            if (wea[0]) mem[addra][ 7: 0] <= dina[ 7: 0];
            if (wea[1]) mem[addra][15: 8] <= dina[15: 8];
            if (wea[2]) mem[addra][23:16] <= dina[23:16];
            if (wea[3]) mem[addra][31:24] <= dina[31:24];
        end
    end
endmodule
