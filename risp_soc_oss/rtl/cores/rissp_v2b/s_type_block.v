`timescale 1ns / 1ps
// S-type block: SW. The address is rs1 + imm_s from the shared adder; the block
// hands imm_s to modular_ex as the adder operand and drives the store data.
module s_type_block (
    input  [31:0] insn,
    input  [31:0] rs2_data,
    output [31:0] imm,          // adder operand for SW
    output [31:0] wdata
);
    assign imm   = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    assign wdata = rs2_data;
endmodule
