`timescale 1ns / 1ps
// RISSP v2b [t-027]: RISSP v2 rebuilt as one hardware instruction block per
// instruction type, as in the paper's Fig. 1 (fetch, register file, U/I/R/S/B/J blocks,
// modular_ex mux, AXI4-Lite master). It decodes the same nine RV32I instructions as
// rtl/cores/rissp_v2/rissp_top_v2.v (LUI ADDI ANDI XOR LW SW BEQ BLT JAL) and has the
// same bus timing, so every program built from them takes the same cycles.
// Option over v2: ILLEGAL_HALT=1 makes any other instruction halt the core (default 0).
//
// Same module name and ports as RISP/ip_repo/cpu_rissp/src/rissp_top.v, so
// design_1.sv and the testbenches do not change.
module rissp_top #(
    parameter PC_W         = 13, // instruction ROM word-address bits (imem_addr[14:2] in design_1)
    parameter JAL_LINK     = 0,  // 1: JAL writes pc+4 to rd; 0: only jal x0 is legal
    parameter ILLEGAL_HALT = 0   // 1: an instruction outside the nine stops the core (+16 LUT)
) (
    input clk, rst_n,
    output [31:0] imem_addr, input [31:0] imem_rdata,
    output [31:0] m_axi_awaddr, output [2:0] m_axi_awprot, output m_axi_awvalid, input m_axi_awready,
    output [31:0] m_axi_wdata, output [3:0] m_axi_wstrb, output m_axi_wvalid, input m_axi_wready,
    input [1:0] m_axi_bresp, input m_axi_bvalid, output m_axi_bready,
    output [31:0] m_axi_araddr, output [2:0] m_axi_arprot, output m_axi_arvalid, input m_axi_arready,
    input [31:0] m_axi_rdata, input [1:0] m_axi_rresp, input m_axi_rvalid, output m_axi_rready
);
    wire [31:0]     insn = imem_rdata;   // the ROM output is the current instruction
    wire [PC_W-1:0] pc, pc_offset;
    wire            pc_jump;
    wire [4:0]      rs1_addr, rs2_addr, rd_addr;
    wire [31:0]     rs1_data, rs2_data, rd_data, load_data;
    wire            rd_wen, illegal;
    wire [31:0]     mem_addr, mem_wdata;
    wire            mem_read, mem_write, bus_stall;

    // The core holds (PC, register file, bus requests) while in reset, while the bus
    // has not finished the current load/store, and on an illegal instruction. An
    // illegal instruction keeps the same PC, so the ROM keeps returning it and the
    // core stays halted until reset.
    wire hold = ~rst_n | bus_stall | illegal;

    fetch_stage #(.PC_W(PC_W)) fetch (
        .clk(clk), .rst_n(rst_n), .hold(hold),
        .jump(pc_jump), .offset(pc_offset),
        .pc(pc), .imem_addr(imem_addr)
    );

    register_file rf (
        .clk(clk),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .wen(rd_wen & ~hold), .rd_addr(rd_addr), .rd_data(rd_data)
    );

    modular_ex #(.PC_W(PC_W), .JAL_LINK(JAL_LINK), .ILLEGAL_HALT(ILLEGAL_HALT)) mex (
        .pc(pc), .insn(insn),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .load_data(load_data),
        .rd_addr(rd_addr), .rd_data(rd_data), .rd_wen(rd_wen),
        .pc_jump(pc_jump), .pc_offset(pc_offset),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .illegal(illegal)
    );

    axi_rissp_master bus (
        .clk(clk), .rst_n(rst_n),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .load_data(load_data), .stall(bus_stall),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr), .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
    );

`ifdef RISSP_V2_TRACE
    always @(posedge clk) if (rst_n)
        $display("[v2b] t=%0t pc=%0h insn=%08h hold=%b ill=%b ld=%b st=%b aw=%b/%b w=%b/%b b=%b ar=%b/%b r=%b wen=%b rd=%0d wd=%08h addr=%08h",
                 $time, {pc, 2'b00}, insn, hold, illegal, mem_read, mem_write,
                 m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready, m_axi_bvalid,
                 m_axi_arvalid, m_axi_arready, m_axi_rvalid, rd_wen & ~hold, rd_addr, rd_data, mem_addr);
`endif
endmodule
