// axil_xbar_flat: flat-port wrapper around pulp-platform/axi `axi_lite_xbar`.
//
// Exposes plain AXI4-Lite ports (no structs, no interfaces) so the crossbar can be
// instantiated from Verilog-2001 tops, Vivado block designs and sv2v/Yosys flows.
// Master-side ports are packed vectors: slave i of the crossbar uses bits
// [i*W +: W] of each m_axil_* bus (lowest index in the lowest bits).
//
// Address map: master port i decodes [M_BASE[i], M_END[i]) (end exclusive).
// Unmapped accesses get DECERR from the crossbar's internal error slave.
// AWPROT/ARPROT are forwarded unchanged.

`include "axi/typedef.svh"

module axil_xbar_flat #(
  parameter int unsigned NUM_S       = 1,
  parameter int unsigned NUM_M       = 5,
  parameter int unsigned ADDR_WIDTH  = 32,
  parameter int unsigned DATA_WIDTH  = 32,
  // packed start / end (exclusive) addresses, entry i at [i*ADDR_WIDTH +: ADDR_WIDTH]
  parameter logic [NUM_M*ADDR_WIDTH-1:0] M_BASE = '0,
  parameter logic [NUM_M*ADDR_WIDTH-1:0] M_END  = '0,
  // axi_pkg::xbar_latency_e; NO_LATENCY = pure combinational routing,
  // CUT_ALL_PORTS = spill register on every channel of every port
  parameter bit [9:0]    LATENCY_MODE = axi_pkg::NO_LATENCY,
  parameter int unsigned MAX_TRANS    = 1,
  localparam int unsigned STRB_WIDTH  = DATA_WIDTH / 8
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,

  // slave ports (connect to bus masters, e.g. the CPU)
  input  logic [NUM_S*ADDR_WIDTH-1:0]   s_axil_awaddr,
  input  logic [NUM_S*3-1:0]            s_axil_awprot,
  input  logic [NUM_S-1:0]              s_axil_awvalid,
  output logic [NUM_S-1:0]              s_axil_awready,
  input  logic [NUM_S*DATA_WIDTH-1:0]   s_axil_wdata,
  input  logic [NUM_S*STRB_WIDTH-1:0]   s_axil_wstrb,
  input  logic [NUM_S-1:0]              s_axil_wvalid,
  output logic [NUM_S-1:0]              s_axil_wready,
  output logic [NUM_S*2-1:0]            s_axil_bresp,
  output logic [NUM_S-1:0]              s_axil_bvalid,
  input  logic [NUM_S-1:0]              s_axil_bready,
  input  logic [NUM_S*ADDR_WIDTH-1:0]   s_axil_araddr,
  input  logic [NUM_S*3-1:0]            s_axil_arprot,
  input  logic [NUM_S-1:0]              s_axil_arvalid,
  output logic [NUM_S-1:0]              s_axil_arready,
  output logic [NUM_S*DATA_WIDTH-1:0]   s_axil_rdata,
  output logic [NUM_S*2-1:0]            s_axil_rresp,
  output logic [NUM_S-1:0]              s_axil_rvalid,
  input  logic [NUM_S-1:0]              s_axil_rready,

  // master ports (connect to bus slaves, e.g. accelerators and memories)
  output logic [NUM_M*ADDR_WIDTH-1:0]   m_axil_awaddr,
  output logic [NUM_M*3-1:0]            m_axil_awprot,
  output logic [NUM_M-1:0]              m_axil_awvalid,
  input  logic [NUM_M-1:0]              m_axil_awready,
  output logic [NUM_M*DATA_WIDTH-1:0]   m_axil_wdata,
  output logic [NUM_M*STRB_WIDTH-1:0]   m_axil_wstrb,
  output logic [NUM_M-1:0]              m_axil_wvalid,
  input  logic [NUM_M-1:0]              m_axil_wready,
  input  logic [NUM_M*2-1:0]            m_axil_bresp,
  input  logic [NUM_M-1:0]              m_axil_bvalid,
  output logic [NUM_M-1:0]              m_axil_bready,
  output logic [NUM_M*ADDR_WIDTH-1:0]   m_axil_araddr,
  output logic [NUM_M*3-1:0]            m_axil_arprot,
  output logic [NUM_M-1:0]              m_axil_arvalid,
  input  logic [NUM_M-1:0]              m_axil_arready,
  input  logic [NUM_M*DATA_WIDTH-1:0]   m_axil_rdata,
  input  logic [NUM_M*2-1:0]            m_axil_rresp,
  input  logic [NUM_M-1:0]              m_axil_rvalid,
  output logic [NUM_M-1:0]              m_axil_rready
);

  typedef logic [ADDR_WIDTH-1:0] addr_t;
  typedef logic [DATA_WIDTH-1:0] data_t;
  typedef logic [STRB_WIDTH-1:0] strb_t;

  `AXI_LITE_TYPEDEF_ALL(axil, addr_t, data_t, strb_t)

  typedef struct packed {
    int unsigned idx;
    addr_t       start_addr;
    addr_t       end_addr;
  } rule_t;

  // Lint: the casted int fields of this packed-struct pattern as unsized.
  /* verilator lint_off WIDTHCONCAT */
  localparam axi_pkg::xbar_cfg_t Cfg = '{
    NoSlvPorts:         32'(NUM_S),
    NoMstPorts:         32'(NUM_M),
    MaxMstTrans:        32'(MAX_TRANS),
    MaxSlvTrans:        32'(MAX_TRANS),
    FallThrough:        1'b0,
    LatencyMode:        LATENCY_MODE,
    PipelineStages:     32'd0,
    AxiIdWidthSlvPorts: 32'd0,
    AxiIdUsedSlvPorts:  32'd0,
    UniqueIds:          1'b0,
    AxiAddrWidth:       32'(ADDR_WIDTH),
    AxiDataWidth:       32'(DATA_WIDTH),
    NoAddrRules:        32'(NUM_M)
  };
  /* verilator lint_on WIDTHCONCAT */

  rule_t [NUM_M-1:0] addr_map;
  for (genvar i = 0; i < NUM_M; i++) begin : gen_map
    assign addr_map[i].idx        = 32'(i);
    assign addr_map[i].start_addr = M_BASE[i*ADDR_WIDTH +: ADDR_WIDTH];
    assign addr_map[i].end_addr   = M_END [i*ADDR_WIDTH +: ADDR_WIDTH];
  end

  axil_req_t  [NUM_S-1:0] slv_req;
  axil_resp_t [NUM_S-1:0] slv_resp;
  axil_req_t  [NUM_M-1:0] mst_req;
  axil_resp_t [NUM_M-1:0] mst_resp;

  for (genvar i = 0; i < NUM_S; i++) begin : gen_slv
    assign slv_req[i].aw.addr  = s_axil_awaddr [i*ADDR_WIDTH +: ADDR_WIDTH];
    assign slv_req[i].aw.prot  = s_axil_awprot [i*3 +: 3];
    assign slv_req[i].aw_valid = s_axil_awvalid[i];
    assign slv_req[i].w.data   = s_axil_wdata  [i*DATA_WIDTH +: DATA_WIDTH];
    assign slv_req[i].w.strb   = s_axil_wstrb  [i*STRB_WIDTH +: STRB_WIDTH];
    assign slv_req[i].w_valid  = s_axil_wvalid [i];
    assign slv_req[i].b_ready  = s_axil_bready [i];
    assign slv_req[i].ar.addr  = s_axil_araddr [i*ADDR_WIDTH +: ADDR_WIDTH];
    assign slv_req[i].ar.prot  = s_axil_arprot [i*3 +: 3];
    assign slv_req[i].ar_valid = s_axil_arvalid[i];
    assign slv_req[i].r_ready  = s_axil_rready [i];

    assign s_axil_awready[i]                         = slv_resp[i].aw_ready;
    assign s_axil_wready [i]                         = slv_resp[i].w_ready;
    assign s_axil_bresp  [i*2 +: 2]                  = slv_resp[i].b.resp;
    assign s_axil_bvalid [i]                         = slv_resp[i].b_valid;
    assign s_axil_arready[i]                         = slv_resp[i].ar_ready;
    assign s_axil_rdata  [i*DATA_WIDTH +: DATA_WIDTH] = slv_resp[i].r.data;
    assign s_axil_rresp  [i*2 +: 2]                  = slv_resp[i].r.resp;
    assign s_axil_rvalid [i]                         = slv_resp[i].r_valid;
  end

  for (genvar i = 0; i < NUM_M; i++) begin : gen_mst
    assign m_axil_awaddr [i*ADDR_WIDTH +: ADDR_WIDTH] = mst_req[i].aw.addr;
    assign m_axil_awprot [i*3 +: 3]                  = mst_req[i].aw.prot;
    assign m_axil_awvalid[i]                         = mst_req[i].aw_valid;
    assign m_axil_wdata  [i*DATA_WIDTH +: DATA_WIDTH] = mst_req[i].w.data;
    assign m_axil_wstrb  [i*STRB_WIDTH +: STRB_WIDTH] = mst_req[i].w.strb;
    assign m_axil_wvalid [i]                         = mst_req[i].w_valid;
    assign m_axil_bready [i]                         = mst_req[i].b_ready;
    assign m_axil_araddr [i*ADDR_WIDTH +: ADDR_WIDTH] = mst_req[i].ar.addr;
    assign m_axil_arprot [i*3 +: 3]                  = mst_req[i].ar.prot;
    assign m_axil_arvalid[i]                         = mst_req[i].ar_valid;
    assign m_axil_rready [i]                         = mst_req[i].r_ready;

    assign mst_resp[i].aw_ready = m_axil_awready[i];
    assign mst_resp[i].w_ready  = m_axil_wready [i];
    assign mst_resp[i].b.resp   = m_axil_bresp  [i*2 +: 2];
    assign mst_resp[i].b_valid  = m_axil_bvalid [i];
    assign mst_resp[i].ar_ready = m_axil_arready[i];
    assign mst_resp[i].r.data   = m_axil_rdata  [i*DATA_WIDTH +: DATA_WIDTH];
    assign mst_resp[i].r.resp   = m_axil_rresp  [i*2 +: 2];
    assign mst_resp[i].r_valid  = m_axil_rvalid [i];
  end

  axi_lite_xbar #(
    .Cfg        ( Cfg              ),
    .aw_chan_t  ( axil_aw_chan_t   ),
    .w_chan_t   ( axil_w_chan_t    ),
    .b_chan_t   ( axil_b_chan_t    ),
    .ar_chan_t  ( axil_ar_chan_t   ),
    .r_chan_t   ( axil_r_chan_t    ),
    .axi_req_t  ( axil_req_t       ),
    .axi_resp_t ( axil_resp_t      ),
    .rule_t     ( rule_t           )
  ) i_xbar (
    .clk_i,
    .rst_ni,
    .test_i                ( 1'b0     ),
    .slv_ports_req_i       ( slv_req  ),
    .slv_ports_resp_o      ( slv_resp ),
    .mst_ports_req_o       ( mst_req  ),
    .mst_ports_resp_i      ( mst_resp ),
    .addr_map_i            ( addr_map ),
    .en_default_mst_port_i ( '0       ),
    .default_mst_port_i    ( '0       )
  );

endmodule
