`timescale 1ns / 1ps
// U-type block: LUI. rd = imm_u.
module u_type_block (
    input  [31:0] insn,
    output [31:0] rd_data
);
    assign rd_data = {insn[31:12], 12'b0};
endmodule
