// Directed test for axil_xbar_flat with the RISSP SoC address map.
// Each master port drives a one-register AXI4-Lite slave that stores the last write
// and answers reads with {port index, stored low 24 bits}. Checks routing of every
// region, end-exclusive bounds and DECERR on unmapped addresses.
`timescale 1ns/1ps
module tb_axil_xbar_flat;
  localparam int NM = 5;
  localparam logic [NM*32-1:0] BASE = {32'h4060_0000, 32'hC000_0000, 32'h4800_0000, 32'h4400_0000, 32'h4000_0000};
  localparam logic [NM*32-1:0] ENDA = {32'h4061_0000, 32'hC000_2000, 32'h4801_0000, 32'h4401_0000, 32'h4000_4000};

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic [31:0] awaddr, wdata, araddr, rdata;
  logic [3:0]  wstrb;
  logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;
  logic [1:0]  bresp, rresp;

  logic [NM*32-1:0] m_awaddr, m_wdata, m_araddr, m_rdata;
  logic [NM*4-1:0]  m_wstrb;
  logic [NM*3-1:0]  m_awprot, m_arprot;
  logic [NM*2-1:0]  m_bresp, m_rresp;
  logic [NM-1:0] m_awvalid, m_awready, m_wvalid, m_wready, m_bvalid, m_bready;
  logic [NM-1:0] m_arvalid, m_arready, m_rvalid, m_rready;

  axil_xbar_flat #(.NUM_S(1), .NUM_M(NM), .M_BASE(BASE), .M_END(ENDA)) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awprot(3'b0), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arprot(3'b0), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
    .m_axil_awaddr(m_awaddr), .m_axil_awprot(m_awprot), .m_axil_awvalid(m_awvalid), .m_axil_awready(m_awready),
    .m_axil_wdata(m_wdata), .m_axil_wstrb(m_wstrb), .m_axil_wvalid(m_wvalid), .m_axil_wready(m_wready),
    .m_axil_bresp(m_bresp), .m_axil_bvalid(m_bvalid), .m_axil_bready(m_bready),
    .m_axil_araddr(m_araddr), .m_axil_arprot(m_arprot), .m_axil_arvalid(m_arvalid), .m_axil_arready(m_arready),
    .m_axil_rdata(m_rdata), .m_axil_rresp(m_rresp), .m_axil_rvalid(m_rvalid), .m_axil_rready(m_rready)
  );

  // one-register slaves: accept AW and W together, answer one cycle later
  for (genvar i = 0; i < NM; i++) begin : gen_slv
    logic [31:0] reg_q;
    logic b_q, r_q;
    assign m_awready[i] = m_awvalid[i] && m_wvalid[i] && !b_q;
    assign m_wready[i]  = m_awready[i];
    assign m_bvalid[i]  = b_q;
    assign m_bresp[i*2 +: 2] = 2'b00;
    assign m_arready[i] = m_arvalid[i] && !r_q;
    assign m_rvalid[i]  = r_q;
    assign m_rresp[i*2 +: 2] = 2'b00;
    assign m_rdata[i*32 +: 32] = {8'(i), reg_q[23:0]};
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        reg_q <= '0; b_q <= 1'b0; r_q <= 1'b0;
      end else begin
        if (m_awready[i]) begin reg_q <= m_wdata[i*32 +: 32]; b_q <= 1'b1; end
        else if (b_q && m_bready[i]) b_q <= 1'b0;
        if (m_arready[i]) r_q <= 1'b1;
        else if (r_q && m_rready[i]) r_q <= 1'b0;
      end
    end
  end

  int errs = 0;

  // Drive inputs 1 ns after the clock edge so DUT flops never race the testbench.
  task automatic axi_write(input logic [31:0] a, input logic [31:0] d, output logic [1:0] resp);
    bit aw_done = 0, w_done = 0;
    #1 awaddr = a; wdata = d; wstrb = 4'hF; awvalid = 1; wvalid = 1; bready = 1;
    while (!(aw_done && w_done)) begin
      @(posedge clk);
      if (awvalid && awready) aw_done = 1;
      if (wvalid && wready)   w_done  = 1;
      #1 if (aw_done) awvalid = 0;
      if (w_done) wvalid = 0;
    end
    while (!bvalid) @(posedge clk);
    resp = bresp;
    @(posedge clk); #1 bready = 0;
  endtask

  task automatic axi_read(input logic [31:0] a, output logic [31:0] d, output logic [1:0] resp);
    #1 araddr = a; arvalid = 1; rready = 1;
    do @(posedge clk); while (!arready);
    #1 arvalid = 0;
    while (!rvalid) @(posedge clk);
    d = rdata; resp = rresp;
    @(posedge clk); #1 rready = 0;
  endtask

  task automatic check(input string what, input logic [31:0] got, input logic [31:0] exp);
    if (got !== exp) begin
      $display("FAIL %s: got %08x expected %08x", what, got, exp);
      errs++;
    end else $display("ok   %s = %08x", what, got);
  endtask

  initial begin
    logic [1:0] resp;
    logic [31:0] d;
    awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
    awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
    repeat (3) @(posedge clk);
    rst_n = 1;
    for (int i = 0; i < NM; i++) begin
      logic [31:0] lo, hi;
      lo = BASE[i*32 +: 32];
      hi = ENDA[i*32 +: 32] - 4;
      axi_write(lo, 32'h00A0_0000 | i, resp);
      check($sformatf("port %0d write bresp", i), {30'b0, resp}, 0);
      axi_read(hi, d, resp);  // last word of the region must hit the same port
      check($sformatf("port %0d read @%08x", i, hi), d, {8'(i), 24'hA0_0000 | 24'(i)});
      check($sformatf("port %0d read rresp", i), {30'b0, resp}, 0);
    end
    // end address is exclusive, and gaps decode to the error slave
    axi_read(32'h4000_4000, d, resp);
    check("unmapped 0x40004000 rresp (DECERR)", {30'b0, resp}, 3);
    axi_write(32'h0000_0000, 32'h1234, resp);
    check("unmapped 0x00000000 bresp (DECERR)", {30'b0, resp}, 3);
    axi_read(32'hC000_2000, d, resp);
    check("unmapped 0xC0002000 rresp (DECERR)", {30'b0, resp}, 3);
    if (errs == 0) $display("==> [PASS] tb_axil_xbar_flat");
    else           $display("==> [FAIL] tb_axil_xbar_flat: %0d errors", errs);
    $finish;
  end

  initial begin
    #100000 $display("==> [FAIL] timeout"); $finish;
  end
endmodule
