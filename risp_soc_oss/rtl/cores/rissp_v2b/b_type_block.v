`timescale 1ns / 1ps
// B-type block: BEQ and BLT.
//   BEQ (funct3 000): taken when rs1 == rs2, from ~|(rs1 ^ rs2)
//   BLT (funct3 100): taken when rs1 < rs2 (signed). The shared adder computes
//                     rs1 - rs2 (rs1 + ~rs2 + 1); if the signs differ, rs1 < rs2 exactly
//                     when rs1 is negative, otherwise the difference cannot overflow
//                     and its sign gives the answer.
// The PC offset is imm_b in words; fetch_stage owns the PC adder.
module b_type_block #(
    parameter PC_W = 13
) (
    input  [31:0]     insn,
    input  [31:0]     rs1_data, rs2_data,
    input  [31:0]     diff,         // shared adder: rs1 - rs2
    output            taken,
    output [PC_W-1:0] offset
);
    wire [31:0] imm = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};

    wire eq = ~|(rs1_data ^ rs2_data);
    wire lt = (rs1_data[31] ^ rs2_data[31]) ? rs1_data[31] : diff[31];

    assign taken  = insn[14] ? lt : eq;    // funct3[2] tells BLT (100) from BEQ (000)
    assign offset = imm[PC_W+1:2];
endmodule
