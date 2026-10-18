`timescale 1ns / 1ps
// J-type block: JAL. The PC offset is imm_j in words; fetch_stage owns the PC adder.
// With JAL_LINK = 1 the block also returns the link address pc + 4 for rd.
// With JAL_LINK = 0 only jal x0 is legal (the firmware has no other), so no link adder.
module j_type_block #(
    parameter PC_W     = 13,
    parameter JAL_LINK = 0
) (
    input  [31:0]     insn,
    input  [PC_W-1:0] pc,
    output [PC_W-1:0] offset,
    output [31:0]     rd_data
);
    wire [31:0] imm = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

    assign offset = imm[PC_W+1:2];

    generate
        if (JAL_LINK) begin : g_link
            wire [PC_W-1:0] pc_inc = pc + 1'b1;
            assign rd_data = {{(30-PC_W){1'b0}}, pc_inc, 2'b00};
        end else begin : g_no_link
            assign rd_data = 32'h0;
        end
    endgenerate
endmodule
