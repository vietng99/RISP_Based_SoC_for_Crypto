`timescale 1ns / 1ps
// RISSP v2: the RISSP CPU cut down to the nine RV32I instructions the
// AES / SHA3 / RSA firmware contains (LUI ADDI ANDI XOR LW SW BEQ BLT JAL).
// Design notes and measurements: risp_soc_oss/RISSP_V2_DESIGN.md.
//
// Same module name and ports as RISP/ip_repo/cpu_rissp/src/rissp_top.v, so
// design_1.sv and the testbenches do not change.
//
// What differs from cpu_rissp:
//  - Decode reads only the opcode bits that tell the nine instructions apart.
//    Any other instruction is undefined.
//  - One 32-bit adder serves ADDI, LUI (0 + imm), the LW/SW address and the
//    BEQ/BLT compare (A + ~B + 1). No shifter, no unsigned compare.
//  - PC is PC_W bits of word address (the 32 KiB ROM is 8192 words).
//  - x0 is never written and the register file starts at zero (FPGA init),
//    so the read ports have no x0 mux.
//  - The AXI4-Lite request leaves in the cycle the instruction is decoded, from
//    the decode signals themselves; no address/data registers. A store retires
//    as soon as AW and W are accepted; its B response is waited for only by the
//    next load or store. A load retires in the cycle RVALID arrives.
module rissp_top #(
    parameter PC_W     = 13,  // instruction ROM word-address bits (imem_addr[14:2] in design_1)
    parameter JAL_LINK = 0    // 1: JAL writes pc+4 to rd; 0: rd is ignored (the firmware only uses jal x0)
) (
    input clk, rst_n,
    output [31:0] imem_addr, input [31:0] imem_rdata,
    output [31:0] m_axi_awaddr, output [2:0] m_axi_awprot, output m_axi_awvalid, input m_axi_awready,
    output [31:0] m_axi_wdata, output [3:0] m_axi_wstrb, output m_axi_wvalid, input m_axi_wready,
    input [1:0] m_axi_bresp, input m_axi_bvalid, output m_axi_bready,
    output [31:0] m_axi_araddr, output [2:0] m_axi_arprot, output m_axi_arvalid, input m_axi_arready,
    input [31:0] m_axi_rdata, input [1:0] m_axi_rresp, input m_axi_rvalid, output m_axi_rready
);
    wire [31:0] insn = imem_rdata;

    // ---------------- decode ----------------
    // insn[6:2]: LUI 01101, OP-IMM 00100, OP 01100, LOAD 00000, STORE 01000,
    //            BRANCH 11000, JAL 11011.
    // insn[6]=1: BEQ/BLT/JAL (insn[2] picks JAL). insn[4]=1: LUI/ADDI/ANDI/XOR.
    // insn[4]=0, insn[6]=0: LW (insn[5]=0) / SW (insn[5]=1).
    wire op_ctl = insn[6];
    wire op_jal = insn[6] & insn[2];
    wire op_ld  = ~insn[6] & ~insn[4] & ~insn[5];
    wire op_st  = ~insn[6] & ~insn[4] &  insn[5];
    // Inside the insn[4]=1 group: XOR (insn[5]) and ANDI (funct3 111, insn[12])
    // take the logic result; LUI (insn[2]) and ADDI take the adder.
    wire op_logic = ~insn[2] & (insn[5] | insn[12]);

    wire [4:0] rs1 = insn[19:15];
    wire [4:0] rs2 = insn[24:20];
    wire [4:0] rd  = insn[11:7];

    wire [31:0] imm_i = {{20{insn[31]}}, insn[31:20]};
    wire [31:0] imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    wire [31:0] imm_u = {insn[31:12], 12'b0};
    wire [31:0] imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
    wire [31:0] imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};

    // ---------------- register file ----------------
    // 32 x 32 LUTRAM, two async read ports, one write port. Writes to x0 are
    // dropped and the array starts at zero, so x0 always reads 0.
    (* ram_style = "distributed" *) reg [31:0] regs [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'h0;

    wire [31:0] a = regs[rs1];
    wire [31:0] b = regs[rs2];

    // ---------------- execute ----------------
    // Adder: LUI 0 + imm_u, ADDI/LW a + imm_i, SW a + imm_s, BEQ/BLT a + ~b + 1.
    wire [31:0] add_a = insn[2] ? 32'h0 : a;          // insn[2] = LUI here (JAL does not use the adder)
    wire [31:0] add_b = insn[6] ? ~b : insn[2] ? imm_u : insn[5] ? imm_s : imm_i;
    wire [32:0] add_w = {add_a, 1'b1} + {add_b, insn[6]};
    wire [31:0] sum   = add_w[32:1];

    wire [31:0] x     = a ^ b;
    wire        eq    = ~|x;
    wire        lt    = (a[31] ^ b[31]) ? a[31] : sum[31];    // signed a < b from a - b
    wire        taken = op_ctl & (insn[2] | (insn[14] ? lt : eq)); // JAL, BLT (funct3 100), BEQ (000)

    wire [31:0] logic_r = insn[5] ? x : (a & imm_i);

    // ---------------- PC ----------------
    reg  [PC_W-1:0] pc;
    wire [PC_W-1:0] off     = insn[2] ? imm_j[PC_W+1:2] : imm_b[PC_W+1:2];
    wire [PC_W-1:0] pc_next = pc + (taken ? off : {{(PC_W-1){1'b0}}, 1'b1});

    // ---------------- AXI4-Lite master ----------------
    reg aw_done, w_done, ar_done, b_pend;
    wire b_busy  = b_pend & ~m_axi_bvalid;   // previous store's B not back yet
    wire go      = rst_n & ~b_busy;

    assign m_axi_awvalid = op_st & go & ~aw_done;
    assign m_axi_wvalid  = op_st & go & ~w_done;
    assign m_axi_arvalid = op_ld & go & ~ar_done;

    wire aw_ok    = aw_done | (m_axi_awvalid & m_axi_awready);
    wire w_ok     = w_done  | (m_axi_wvalid  & m_axi_wready);
    wire st_fin   = op_st & go & aw_ok & w_ok;
    wire stall_st = op_st & ~st_fin;
    wire stall_ld = op_ld & ~m_axi_rvalid;
    wire hold     = stall_st | stall_ld | ~rst_n;

    assign m_axi_awaddr = sum;
    assign m_axi_araddr = sum;
    assign m_axi_wdata  = b;
    assign m_axi_wstrb  = 4'hF;
    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;
    assign m_axi_bready = 1'b1;
    assign m_axi_rready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done <= 1'b0; w_done <= 1'b0; ar_done <= 1'b0; b_pend <= 1'b0;
        end else begin
            aw_done <= stall_st & aw_ok;
            w_done  <= stall_st & w_ok;
            ar_done <= stall_ld & (ar_done | (m_axi_arvalid & m_axi_arready));
            b_pend  <= b_busy | st_fin;
        end
    end

    // ---------------- write-back ----------------
    wire [31:0] link;
    generate
        if (JAL_LINK) begin : g_link
            wire [PC_W-1:0] pc_inc = pc + 1'b1;
            assign link = {{(30-PC_W){1'b0}}, pc_inc, 2'b00};
        end else begin : g_nolink
            assign link = 32'h0;
        end
    endgenerate

    wire        jal_wr = (JAL_LINK != 0) & op_jal;
    wire        wr     = insn[4] | op_ld | jal_wr;
    wire        wen    = wr & ~hold & (|rd);
    wire [31:0] wdata  = insn[4] ? (op_logic ? logic_r : sum) : (jal_wr ? link : m_axi_rdata);

    always @(posedge clk) if (wen) regs[rd] <= wdata;

    // ---------------- fetch ----------------
    // The ROM has one cycle of read latency: imem_addr is the PC of the next
    // cycle's instruction. While held, the ROM re-reads the current PC.
    wire [PC_W-1:0] fetch_pc = hold ? pc : pc_next;
    assign imem_addr = {{(30-PC_W){1'b0}}, fetch_pc, 2'b00};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= {PC_W{1'b0}};
        else        pc <= fetch_pc;
    end

`ifdef RISSP_V2_TRACE
    always @(posedge clk) if (rst_n)
        $display("[v2] t=%0t pc=%0h insn=%08h hold=%b st=%b ld=%b aw=%b/%b w=%b/%b b=%b/%b ar=%b/%b r=%b wen=%b rd=%0d wd=%08h addr=%08h",
                 $time, {pc, 2'b00}, insn, hold, op_st, op_ld, m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready,
                 b_pend, m_axi_bvalid, m_axi_arvalid, m_axi_arready, m_axi_rvalid, wen, rd, wdata, sum);
`endif
endmodule
