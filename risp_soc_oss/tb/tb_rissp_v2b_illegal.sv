// [t-027] Directed test of the RISSP v2b illegal-instruction halt. Build with +define+SECOND=<insn>, see RISSP_V2_DESIGN.md section 6.
`timescale 1ns/1ps
module tb_rissp_v2b_illegal;
  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  reg [31:0] rom [0:7];
  wire [31:0] imem_addr; reg [31:0] imem_rdata;
  always @(posedge clk) imem_rdata <= rom[imem_addr[4:2]];
  wire awvalid, wvalid, arvalid; reg bvalid = 0;
  always @(posedge clk) bvalid <= awvalid & wvalid;
  rissp_top #(.ILLEGAL_HALT(1)) dut (.clk(clk), .rst_n(rst_n), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
    .m_axi_awaddr(), .m_axi_awprot(), .m_axi_awvalid(awvalid), .m_axi_awready(1'b1),
    .m_axi_wdata(), .m_axi_wstrb(), .m_axi_wvalid(wvalid), .m_axi_wready(1'b1),
    .m_axi_bresp(2'b00), .m_axi_bvalid(bvalid), .m_axi_bready(),
    .m_axi_araddr(), .m_axi_arprot(), .m_axi_arvalid(arvalid), .m_axi_arready(1'b1),
    .m_axi_rdata(32'h0), .m_axi_rresp(2'b00), .m_axi_rvalid(1'b0), .m_axi_rready());
  integer aw_seen = 0, cyc;
  always @(posedge clk) if (awvalid) aw_seen = aw_seen + 1;
  initial begin
    rom[0] = 32'h00500093;          // addi x1, x0, 5
    rom[1] = `SECOND;               // add x2,x1,x1 (illegal) or xor x2,x1,x1 (legal)
    rom[2] = 32'h00102023;          // sw x1, 0(x0)
    rom[3] = 32'h0000006f;          // j .
    rom[4] = 0; rom[5] = 0; rom[6] = 0; rom[7] = 0;
    repeat (3) @(posedge clk); rst_n = 1;
    repeat (40) @(posedge clk);
    $display("RESULT second=%08h pc_word=%0d illegal=%b x1=%0d x2=%0d aw_cycles=%0d",
             `SECOND, dut.pc, dut.illegal, dut.rf.regs[1], dut.rf.regs[2], aw_seen);
    $finish;
  end
endmodule
