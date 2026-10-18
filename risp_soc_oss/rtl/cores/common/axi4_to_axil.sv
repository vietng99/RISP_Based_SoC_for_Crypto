// axi4_to_axil: AXI4 (single-beat, uncached MMIO) to the RISSP AXI4-Lite port.
//
// The cores mark the peripheral range uncached, so every load/store there is
// one AXI4 beat of at most 4 bytes. This bridge passes those straight through
// to AXI4-Lite with no added cycle: it only remembers the AXI ID and, for a
// 64-bit core bus, picks the 32-bit lane from address bit 2.
// One read and one write in flight. Bursts are a protocol error here
// (reported in simulation).
//
// After a handshake the address outputs keep the accepted address until the
// response, as the RISSP master does. AXI leaves the address undefined while
// VALID is low, so this changes no timing; the RISSP testbenches read the
// slave's ARADDR at RVALID to stamp their milestones and need it.
module axi4_to_axil #(
  parameter int unsigned IW = 4,   // AXI ID width
  parameter int unsigned DW = 32   // core-side data width, 32 or 64
) (
  input  logic            clk,
  input  logic            rst_n,
  // AXI4 slave (from the core)
  input  logic [IW-1:0]   aw_id,
  input  logic [31:0]     aw_addr,
  input  logic [7:0]      aw_len,
  input  logic [2:0]      aw_prot,
  input  logic            aw_valid,
  output logic            aw_ready,
  input  logic [DW-1:0]   w_data,
  input  logic [DW/8-1:0] w_strb,
  input  logic            w_valid,
  output logic            w_ready,
  output logic [IW-1:0]   b_id,
  output logic [1:0]      b_resp,
  output logic            b_valid,
  input  logic            b_ready,
  input  logic [IW-1:0]   ar_id,
  input  logic [31:0]     ar_addr,
  input  logic [7:0]      ar_len,
  input  logic [2:0]      ar_prot,
  input  logic            ar_valid,
  output logic            ar_ready,
  output logic [IW-1:0]   r_id,
  output logic [DW-1:0]   r_data,
  output logic [1:0]      r_resp,
  output logic            r_last,
  output logic            r_valid,
  input  logic            r_ready,
  // AXI4-Lite master (RISSP CPU port)
  output logic [31:0]     m_axi_awaddr,
  output logic [2:0]      m_axi_awprot,
  output logic            m_axi_awvalid,
  input  logic            m_axi_awready,
  output logic [31:0]     m_axi_wdata,
  output logic [3:0]      m_axi_wstrb,
  output logic            m_axi_wvalid,
  input  logic            m_axi_wready,
  input  logic [1:0]      m_axi_bresp,
  input  logic            m_axi_bvalid,
  output logic            m_axi_bready,
  output logic [31:0]     m_axi_araddr,
  output logic [2:0]      m_axi_arprot,
  output logic            m_axi_arvalid,
  input  logic            m_axi_arready,
  input  logic [31:0]     m_axi_rdata,
  input  logic [1:0]      m_axi_rresp,
  input  logic            m_axi_rvalid,
  output logic            m_axi_rready
);
  // ---------------- write ----------------
  logic          aw_sent, w_sent, wlane;
  logic [IW-1:0] wid;
  logic [31:0]   awaddr_q, araddr_q;
  wire           lane_now = (DW == 64) ? (aw_sent ? wlane : aw_addr[2]) : 1'b0;

  assign m_axi_awaddr  = aw_sent ? awaddr_q : aw_addr;
  assign m_axi_awprot  = aw_prot;
  assign m_axi_awvalid = aw_valid && !aw_sent;
  assign aw_ready      = m_axi_awready && !aw_sent;
  // W follows its AW (same cycle or later), so the lane is known
  assign m_axi_wvalid  = w_valid && !w_sent && (aw_sent || aw_valid);
  assign w_ready       = m_axi_wready && !w_sent && (aw_sent || aw_valid);
  generate if (DW == 64) begin : g_w64
    assign m_axi_wdata = lane_now ? w_data[63:32] : w_data[31:0];
    assign m_axi_wstrb = lane_now ? w_strb[7:4]   : w_strb[3:0];
  end else begin : g_w32
    assign m_axi_wdata = w_data;
    assign m_axi_wstrb = w_strb;
  end endgenerate
  assign b_id         = wid;
  assign b_resp       = m_axi_bresp;
  assign b_valid      = m_axi_bvalid;
  assign m_axi_bready = b_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_sent <= 1'b0; w_sent <= 1'b0; wlane <= 1'b0; wid <= '0; awaddr_q <= '0;
    end else begin
      if (aw_valid && aw_ready) begin aw_sent <= 1'b1; wid <= aw_id; wlane <= aw_addr[2]; awaddr_q <= aw_addr; end
      if (w_valid && w_ready) w_sent <= 1'b1;
      if (b_valid && b_ready) begin aw_sent <= 1'b0; w_sent <= 1'b0; end
    end
  end

  // ---------------- read ----------------
  logic          rbusy;
  logic [IW-1:0] rid;
  assign m_axi_araddr  = rbusy ? araddr_q : ar_addr;
  assign m_axi_arprot  = ar_prot;
  assign m_axi_arvalid = ar_valid && !rbusy;
  assign ar_ready      = m_axi_arready && !rbusy;
  assign r_id          = rid;
  assign r_data        = (DW == 64) ? {(DW/32){m_axi_rdata}} : DW'(m_axi_rdata);
  assign r_resp        = m_axi_rresp;
  assign r_last        = 1'b1;
  assign r_valid       = m_axi_rvalid;
  assign m_axi_rready  = r_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rbusy <= 1'b0; rid <= '0; araddr_q <= '0;
    end else begin
      if (ar_valid && ar_ready) begin rbusy <= 1'b1; rid <= ar_id; araddr_q <= ar_addr; end
      if (r_valid && r_ready) rbusy <= 1'b0;
    end
  end

`ifndef SYNTHESIS
  always @(posedge clk) begin
    if (rst_n && aw_valid && aw_ready && aw_len != 0)
      $display("[axi4_to_axil] %m ERROR: write burst len=%0d at 0x%08x", aw_len, aw_addr);
    if (rst_n && ar_valid && ar_ready && ar_len != 0)
      $display("[axi4_to_axil] %m ERROR: read burst len=%0d at 0x%08x", ar_len, ar_addr);
  end
`endif
endmodule
