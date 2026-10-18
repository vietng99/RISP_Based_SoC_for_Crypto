`timescale 1ns / 1ps
// The one 32-bit adder of the execute stage, shared by the I, S and B blocks:
// ADDI and LW (rs1 + imm_i), SW (rs1 + imm_s), BEQ/BLT (rs1 + ~rs2 + 1).
// The carry-in rides in an extra low bit, so the adder maps to one CARRY4 chain.
module alu_adder (
    input  [31:0] op_a, op_b,
    input         cin,
    output [31:0] sum
);
    wire [32:0] wide = {op_a, 1'b1} + {op_b, cin};
    assign sum = wide[32:1];
endmodule
