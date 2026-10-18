`timescale 1ns / 1ps
// Execute stage: one hardware instruction block per instruction type, the shared adder,
// and the mux that picks the block for the current opcode.
//
//   block          instructions      result
//   u_type_block   LUI               rd
//   i_type_block   ADDI ANDI LW      rd, LW address (shared adder)
//   r_type_block   XOR               rd
//   s_type_block   SW                store address (shared adder), store data
//   b_type_block   BEQ BLT           PC jump and offset
//   j_type_block   JAL               PC jump and offset (and rd with JAL_LINK)
//
// Routing reads only the opcode bits that tell the nine instructions apart
// (insn[6:2]: LUI 01101, OP-IMM 00100, OP 01100, LOAD 00000, STORE 01000,
// BRANCH 11000, JAL 11011). The full opcode/funct3/funct7 check is a separate
// signal, `illegal`, which stops the core instead of letting another instruction
// run through a block that happens to share its routing bits.
module modular_ex #(
    parameter PC_W         = 13,
    parameter JAL_LINK     = 0,
    parameter ILLEGAL_HALT = 0
) (
    input  [PC_W-1:0] pc,
    input  [31:0]     insn,
    output [4:0]      rs1_addr, rs2_addr,
    input  [31:0]     rs1_data, rs2_data,
    input  [31:0]     load_data,
    output [4:0]      rd_addr,
    output [31:0]     rd_data,
    output            rd_wen,
    output            pc_jump,
    output [PC_W-1:0] pc_offset,
    output            mem_read, mem_write,
    output [31:0]     mem_addr, mem_wdata,
    output            illegal
);
    assign rs1_addr = insn[19:15];
    assign rs2_addr = insn[24:20];
    assign rd_addr  = insn[11:7];

    // ---------------- routing ----------------
    wire is_lui    =  insn[4] &  insn[2];
    wire is_op_imm =  insn[4] & ~insn[5] & ~insn[2];
    wire is_op     =  insn[4] &  insn[5] & ~insn[2];
    wire is_load   = ~insn[6] & ~insn[5] & ~insn[4];
    wire is_store  = ~insn[6] &  insn[5] & ~insn[4];
    wire is_branch =  insn[6] & ~insn[2];
    wire is_jal    =  insn[6] &  insn[2];

    // ---------------- legality ----------------
    generate
        if (ILLEGAL_HALT) begin : g_check
            wire [6:0] opcode = insn[6:0];
            wire [2:0] funct3 = insn[14:12];
            wire [6:0] funct7 = insn[31:25];
            wire legal =
                (opcode == 7'b0110111)                                              | // LUI
                (opcode == 7'b0010011 && (funct3 == 3'b000 || funct3 == 3'b111))    | // ADDI, ANDI
                (opcode == 7'b0110011 && funct3 == 3'b100 && funct7 == 7'b0000000)  | // XOR
                (opcode == 7'b0000011 && funct3 == 3'b010)                          | // LW
                (opcode == 7'b0100011 && funct3 == 3'b010)                          | // SW
                (opcode == 7'b1100011 && (funct3 == 3'b000 || funct3 == 3'b100))    | // BEQ, BLT
                (opcode == 7'b1101111 && (JAL_LINK != 0 || rd_addr == 5'd0));         // JAL
            assign illegal = ~legal;
        end else begin : g_no_check
            assign illegal = 1'b0;   // the firmware is trusted to use only the nine
        end
    endgenerate

    // ---------------- instruction blocks ----------------
    wire [31:0] u_rd, i_rd, r_rd, j_rd;
    wire [31:0] i_imm, s_imm, s_wdata;
    wire [31:0] sum;
    wire        b_taken;
    wire [PC_W-1:0] b_offset, j_offset;

    u_type_block u_blk (.insn(insn), .rd_data(u_rd));

    i_type_block i_blk (.insn(insn), .rs1_data(rs1_data), .sum(sum), .load_data(load_data),
                        .imm(i_imm), .rd_data(i_rd));

    r_type_block r_blk (.rs1_data(rs1_data), .rs2_data(rs2_data), .rd_data(r_rd));

    s_type_block s_blk (.insn(insn), .rs2_data(rs2_data), .imm(s_imm), .wdata(s_wdata));

    b_type_block #(.PC_W(PC_W)) b_blk (.insn(insn), .rs1_data(rs1_data), .rs2_data(rs2_data),
                                       .diff(sum), .taken(b_taken), .offset(b_offset));

    j_type_block #(.PC_W(PC_W), .JAL_LINK(JAL_LINK)) j_blk (.insn(insn), .pc(pc),
                                                           .offset(j_offset), .rd_data(j_rd));

    // ---------------- shared adder ----------------
    // rs1 + imm_i (ADDI, LW), rs1 + imm_s (SW), rs1 + ~rs2 + 1 (BEQ, BLT).
    // insn[6] marks a branch among the adder users, insn[5] a store.
    wire [31:0] add_b = insn[6] ? ~rs2_data : insn[5] ? s_imm : i_imm;
    alu_adder adder (.op_a(rs1_data), .op_b(add_b), .cin(insn[6]), .sum(sum));

    // ---------------- result mux ----------------
    assign rd_data = is_op  ? r_rd :
                     is_lui ? u_rd :
                     is_jal ? j_rd : i_rd;           // i_rd covers ADDI, ANDI, LW
    assign rd_wen  = is_lui | is_op_imm | is_op | is_load | (JAL_LINK != 0 && is_jal);

    assign pc_jump   = (is_branch & b_taken) | is_jal;
    assign pc_offset = is_jal ? j_offset : b_offset;

    assign mem_read  = is_load  & ~illegal;
    assign mem_write = is_store & ~illegal;
    assign mem_addr  = sum;
    assign mem_wdata = s_wdata;
endmodule
