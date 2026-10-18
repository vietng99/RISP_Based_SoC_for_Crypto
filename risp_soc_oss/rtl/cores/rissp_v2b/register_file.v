`timescale 1ns / 1ps
// Register file: 32 x 32 LUTRAM, two asynchronous read ports, one write port.
// Writes to x0 are dropped and the array starts at zero (FPGA LUTRAM init), so x0
// always reads 0 without a read-port mux. An ASIC build needs that mux back.
module register_file (
    input         clk,
    input  [4:0]  rs1_addr, rs2_addr,
    output [31:0] rs1_data, rs2_data,
    input         wen,
    input  [4:0]  rd_addr,
    input  [31:0] rd_data
);
    (* ram_style = "distributed" *) reg [31:0] regs [0:31];

    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'h0;

    assign rs1_data = regs[rs1_addr];
    assign rs2_data = regs[rs2_addr];

    always @(posedge clk) if (wen && rd_addr != 5'd0) regs[rd_addr] <= rd_data;
endmodule
