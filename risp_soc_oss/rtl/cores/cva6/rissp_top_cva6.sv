// rissp_top (CVA6 build): CVA6 cv32a6_imac_sv0 behind the RISSP CPU ports.
//
// design_1.sv instantiates `rissp_top rissp_top_0`; flist/cva6_soc.f compiles
// this file instead of ip_repo/cpu_rissp, so the rest of the SoC is the RISSP
// SoC unchanged (risp_soc_oss/CORE_SWAP_DESIGN.md).
//
//   CVA6 AXI4 (64-bit) -> axi_demux (no spill registers, no added cycle)
//     port 0: 0x0000_0000 - 0x0000_7FFF -> axi_rom_bridge -> imem_addr/imem_rdata
//     port 1: everything else            -> axi4_to_axil   -> m_axi_* (AXI4-Lite)
// Boot address 0x0, hart 0, no interrupts, no debug request.
`include "axi/typedef.svh"

module rissp_top (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awprot,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arprot,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready
);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  localparam int unsigned AW = CVA6Cfg.AxiAddrWidth;
  localparam int unsigned DW = CVA6Cfg.AxiDataWidth;
  localparam int unsigned IW = CVA6Cfg.AxiIdWidth;
  localparam int unsigned UW = CVA6Cfg.AxiUserWidth;

  typedef logic [AW-1:0]   addr_t;
  typedef logic [DW-1:0]   data_t;
  typedef logic [DW/8-1:0] strb_t;
  typedef logic [IW-1:0]   id_t;
  typedef logic [UW-1:0]   user_t;
  // same field order as the CVA6 default noc_req_t / noc_resp_t
  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)

  axi_req_t  core_req;
  axi_resp_t core_resp;
  axi_req_t  [1:0] port_req;
  axi_resp_t [1:0] port_resp;

  cva6 #(
      .CVA6Cfg      (CVA6Cfg),
      .axi_ar_chan_t(axi_ar_chan_t),
      .axi_aw_chan_t(axi_aw_chan_t),
      .axi_w_chan_t (axi_w_chan_t),
      .b_chan_t     (axi_b_chan_t),
      .r_chan_t     (axi_r_chan_t),
      .noc_req_t    (axi_req_t),
      .noc_resp_t   (axi_resp_t)
  ) i_cva6 (
      .clk_i        (clk),
      .rst_ni       (rst_n),
      .boot_addr_i  ('0),
      .hart_id_i    ('0),
      .irq_i        (2'b00),
      .ipi_i        (1'b0),
      .time_irq_i   (1'b0),
      .debug_req_i  (1'b0),
      .rvfi_probes_o(),
      .cvxif_req_o  (),
      .cvxif_resp_i ('0),
      .noc_req_o    (core_req),
      .noc_resp_i   (core_resp)
  );

  // ROM range -> port 0, everything else -> port 1
  wire aw_sel = (core_req.aw.addr[31:0] >= 32'h0000_8000);
  wire ar_sel = (core_req.ar.addr[31:0] >= 32'h0000_8000);

  axi_demux #(
      .AxiIdWidth (IW),
      .AtopSupport(1'b0),
      .aw_chan_t  (axi_aw_chan_t),
      .w_chan_t   (axi_w_chan_t),
      .b_chan_t   (axi_b_chan_t),
      .ar_chan_t  (axi_ar_chan_t),
      .r_chan_t   (axi_r_chan_t),
      .axi_req_t  (axi_req_t),
      .axi_resp_t (axi_resp_t),
      .NoMstPorts (2),
      .MaxTrans   (4),
      .AxiLookBits(IW),
      .UniqueIds  (1'b0),
      .SpillAw    (1'b0),
      .SpillW     (1'b0),
      .SpillB     (1'b0),
      .SpillAr    (1'b0),
      .SpillR     (1'b0)
  ) i_demux (
      .clk_i          (clk),
      .rst_ni         (rst_n),
      .test_i         (1'b0),
      .slv_req_i      (core_req),
      .slv_aw_select_i(aw_sel),
      .slv_ar_select_i(ar_sel),
      .slv_resp_o     (core_resp),
      .mst_reqs_o     (port_req),
      .mst_resps_i    (port_resp)
  );

  // ---------------- port 0: instruction ROM ----------------
  axi_rom_bridge #(.IW(IW), .DW(DW)) i_rom (
      .clk(clk), .rst_n(rst_n),
      .imem_addr(imem_addr), .imem_rdata(imem_rdata),
      .ar_id(port_req[0].ar.id), .ar_addr(port_req[0].ar.addr[31:0]), .ar_len(port_req[0].ar.len),
      .ar_size(port_req[0].ar.size), .ar_burst(port_req[0].ar.burst),
      .ar_valid(port_req[0].ar_valid), .ar_ready(port_resp[0].ar_ready),
      .r_id(port_resp[0].r.id), .r_data(port_resp[0].r.data), .r_resp(port_resp[0].r.resp),
      .r_last(port_resp[0].r.last), .r_valid(port_resp[0].r_valid), .r_ready(port_req[0].r_ready),
      .aw_id(port_req[0].aw.id), .aw_valid(port_req[0].aw_valid), .aw_ready(port_resp[0].aw_ready),
      .w_last(port_req[0].w.last), .w_valid(port_req[0].w_valid), .w_ready(port_resp[0].w_ready),
      .b_id(port_resp[0].b.id), .b_resp(port_resp[0].b.resp), .b_valid(port_resp[0].b_valid),
      .b_ready(port_req[0].b_ready)
  );
  assign port_resp[0].r.user = '0;
  assign port_resp[0].b.user = '0;

  // ---------------- port 1: AXI4-Lite to the SoC crossbar ----------------
  axi4_to_axil #(.IW(IW), .DW(DW)) i_mmio (
      .clk(clk), .rst_n(rst_n),
      .aw_id(port_req[1].aw.id), .aw_addr(port_req[1].aw.addr[31:0]), .aw_len(port_req[1].aw.len),
      .aw_prot(port_req[1].aw.prot), .aw_valid(port_req[1].aw_valid), .aw_ready(port_resp[1].aw_ready),
      .w_data(port_req[1].w.data), .w_strb(port_req[1].w.strb), .w_valid(port_req[1].w_valid),
      .w_ready(port_resp[1].w_ready),
      .b_id(port_resp[1].b.id), .b_resp(port_resp[1].b.resp), .b_valid(port_resp[1].b_valid),
      .b_ready(port_req[1].b_ready),
      .ar_id(port_req[1].ar.id), .ar_addr(port_req[1].ar.addr[31:0]), .ar_len(port_req[1].ar.len),
      .ar_prot(port_req[1].ar.prot), .ar_valid(port_req[1].ar_valid), .ar_ready(port_resp[1].ar_ready),
      .r_id(port_resp[1].r.id), .r_data(port_resp[1].r.data), .r_resp(port_resp[1].r.resp),
      .r_last(port_resp[1].r.last), .r_valid(port_resp[1].r_valid), .r_ready(port_req[1].r_ready),
      .m_axi_awaddr(m_axi_awaddr), .m_axi_awprot(m_axi_awprot), .m_axi_awvalid(m_axi_awvalid),
      .m_axi_awready(m_axi_awready),
      .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wvalid(m_axi_wvalid),
      .m_axi_wready(m_axi_wready),
      .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
      .m_axi_araddr(m_axi_araddr), .m_axi_arprot(m_axi_arprot), .m_axi_arvalid(m_axi_arvalid),
      .m_axi_arready(m_axi_arready),
      .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp), .m_axi_rvalid(m_axi_rvalid),
      .m_axi_rready(m_axi_rready)
  );
  assign port_resp[1].r.user = '0;
  assign port_resp[1].b.user = '0;
endmodule
