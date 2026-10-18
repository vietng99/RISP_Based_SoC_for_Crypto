`timescale 1ns / 1ps
// I-type block: ADDI, ANDI and LW.
// ADDI and the LW address use the shared adder (rs1 + imm_i); the block hands imm_i to
// modular_ex as the adder operand and picks its result:
//   LW   (opcode LOAD,   insn[4] = 0)      rd = load data
//   ANDI (opcode OP-IMM, funct3 111)       rd = rs1 & imm_i
//   ADDI (opcode OP-IMM, funct3 000)       rd = rs1 + imm_i
module i_type_block (
    input  [31:0] insn,
    input  [31:0] rs1_data,
    input  [31:0] sum,          // shared adder: rs1 + imm_i
    input  [31:0] load_data,    // AXI read data
    output [31:0] imm,          // adder operand for ADDI / LW
    output [31:0] rd_data
);
    wire is_load = ~insn[4];
    wire is_andi = insn[12];    // funct3[0] tells ANDI (111) from ADDI (000)

    assign imm     = {{20{insn[31]}}, insn[31:20]};
    assign rd_data = is_load ? load_data :
                     is_andi ? (rs1_data & imm) : sum;
endmodule
