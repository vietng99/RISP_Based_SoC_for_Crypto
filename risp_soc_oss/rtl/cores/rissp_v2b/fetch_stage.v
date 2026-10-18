`timescale 1ns / 1ps
// Fetch stage: the PC and its one adder. The instruction ROM has one cycle of read
// latency, so imem_addr carries the PC of the next cycle's instruction. On hold the
// ROM re-reads the current PC. The PC counts words (PC_W bits); a jump adds the
// block's offset, any other instruction adds one word.
module fetch_stage #(
    parameter PC_W = 13
) (
    input             clk, rst_n,
    input             hold,
    input             jump,             // taken branch or JAL
    input  [PC_W-1:0] offset,           // jump offset in words
    output reg [PC_W-1:0] pc,
    output [31:0]     imem_addr
);
    wire [PC_W-1:0] pc_next  = pc + (jump ? offset : {{(PC_W-1){1'b0}}, 1'b1});
    wire [PC_W-1:0] fetch_pc = hold ? pc : pc_next;

    assign imem_addr = {{(30-PC_W){1'b0}}, fetch_pc, 2'b00};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= {PC_W{1'b0}};
        else        pc <= fetch_pc;
    end
endmodule
