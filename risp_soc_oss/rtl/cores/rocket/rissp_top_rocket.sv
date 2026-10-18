// rissp_top (Rocket build): small RV32 Rocket from chipyard behind the RISSP CPU ports.
//
// design_1.sv instantiates `rissp_top rissp_top_0`; flist/rocket_soc.f compiles
// this file instead of ip_repo/cpu_rissp, so the rest of the SoC is the RISSP
// SoC unchanged (risp_soc_oss/CORE_SWAP_DESIGN.md).
//
//   RispRocketTop (gen/, from chipyard/generators/chipyard/src/main/scala/risp/RispRocket.scala)
//     mem  AXI4 port (0x0000_0000 - 0x0000_7FFF, I$ refills) -> axi_rom_bridge -> imem_addr/imem_rdata
//     mmio AXI4 port (0x4000_0000 - 0xCFFF_FFFF, uncached)   -> axi4_to_axil   -> m_axi_* (AXI4-Lite)
// Reset vector 0x0. Rocket reset is active high and synchronous.
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
  localparam int unsigned IW = 4;

  // mem port
  wire [IW-1:0] mem_aw_id, mem_ar_id, mem_b_id, mem_r_id;
  wire [14:0]   mem_aw_addr15, mem_ar_addr15;   // the mem port only spans 0x0000 - 0x7FFF
  wire [31:0]   mem_aw_addr, mem_ar_addr, mem_w_data, mem_r_data;
  wire [7:0]    mem_aw_len, mem_ar_len;
  wire [2:0]    mem_aw_size, mem_ar_size, mem_aw_prot, mem_ar_prot;
  wire [1:0]    mem_aw_burst, mem_ar_burst, mem_b_resp, mem_r_resp;
  wire [3:0]    mem_w_strb;
  wire mem_aw_valid, mem_aw_ready, mem_w_valid, mem_w_ready, mem_w_last, mem_b_valid, mem_b_ready;
  wire mem_ar_valid, mem_ar_ready, mem_r_valid, mem_r_ready, mem_r_last;
  // mmio port
  wire [IW-1:0] io_aw_id, io_ar_id, io_b_id, io_r_id;
  wire [31:0]   io_aw_addr, io_ar_addr, io_w_data, io_r_data;
  wire [7:0]    io_aw_len, io_ar_len;
  wire [2:0]    io_aw_size, io_ar_size, io_aw_prot, io_ar_prot;
  wire [1:0]    io_aw_burst, io_ar_burst, io_b_resp, io_r_resp;
  wire [3:0]    io_w_strb;
  wire io_aw_valid, io_aw_ready, io_w_valid, io_w_ready, io_w_last, io_b_valid, io_b_ready;
  wire io_ar_valid, io_ar_ready, io_r_valid, io_r_ready, io_r_last;

  RispRocketTop i_rocket (
      .clock(clk), .reset(~rst_n), .reset_vector(32'h0000_0000),
      .mem_aw_ready(mem_aw_ready), .mem_aw_valid(mem_aw_valid), .mem_aw_bits_id(mem_aw_id),
      .mem_aw_bits_addr(mem_aw_addr15), .mem_aw_bits_len(mem_aw_len), .mem_aw_bits_size(mem_aw_size),
      .mem_aw_bits_burst(mem_aw_burst), .mem_aw_bits_lock(), .mem_aw_bits_cache(),
      .mem_aw_bits_prot(mem_aw_prot), .mem_aw_bits_qos(),
      .mem_w_ready(mem_w_ready), .mem_w_valid(mem_w_valid), .mem_w_bits_data(mem_w_data),
      .mem_w_bits_strb(mem_w_strb), .mem_w_bits_last(mem_w_last),
      .mem_b_ready(mem_b_ready), .mem_b_valid(mem_b_valid), .mem_b_bits_id(mem_b_id),
      .mem_b_bits_resp(mem_b_resp),
      .mem_ar_ready(mem_ar_ready), .mem_ar_valid(mem_ar_valid), .mem_ar_bits_id(mem_ar_id),
      .mem_ar_bits_addr(mem_ar_addr15), .mem_ar_bits_len(mem_ar_len), .mem_ar_bits_size(mem_ar_size),
      .mem_ar_bits_burst(mem_ar_burst), .mem_ar_bits_lock(), .mem_ar_bits_cache(),
      .mem_ar_bits_prot(mem_ar_prot), .mem_ar_bits_qos(),
      .mem_r_ready(mem_r_ready), .mem_r_valid(mem_r_valid), .mem_r_bits_id(mem_r_id),
      .mem_r_bits_data(mem_r_data), .mem_r_bits_resp(mem_r_resp), .mem_r_bits_last(mem_r_last),
      .mmio_aw_ready(io_aw_ready), .mmio_aw_valid(io_aw_valid), .mmio_aw_bits_id(io_aw_id),
      .mmio_aw_bits_addr(io_aw_addr), .mmio_aw_bits_len(io_aw_len), .mmio_aw_bits_size(io_aw_size),
      .mmio_aw_bits_burst(io_aw_burst), .mmio_aw_bits_lock(), .mmio_aw_bits_cache(),
      .mmio_aw_bits_prot(io_aw_prot), .mmio_aw_bits_qos(),
      .mmio_w_ready(io_w_ready), .mmio_w_valid(io_w_valid), .mmio_w_bits_data(io_w_data),
      .mmio_w_bits_strb(io_w_strb), .mmio_w_bits_last(io_w_last),
      .mmio_b_ready(io_b_ready), .mmio_b_valid(io_b_valid), .mmio_b_bits_id(io_b_id),
      .mmio_b_bits_resp(io_b_resp),
      .mmio_ar_ready(io_ar_ready), .mmio_ar_valid(io_ar_valid), .mmio_ar_bits_id(io_ar_id),
      .mmio_ar_bits_addr(io_ar_addr), .mmio_ar_bits_len(io_ar_len), .mmio_ar_bits_size(io_ar_size),
      .mmio_ar_bits_burst(io_ar_burst), .mmio_ar_bits_lock(), .mmio_ar_bits_cache(),
      .mmio_ar_bits_prot(io_ar_prot), .mmio_ar_bits_qos(),
      .mmio_r_ready(io_r_ready), .mmio_r_valid(io_r_valid), .mmio_r_bits_id(io_r_id),
      .mmio_r_bits_data(io_r_data), .mmio_r_bits_resp(io_r_resp), .mmio_r_bits_last(io_r_last)
  );

  assign mem_aw_addr = {17'b0, mem_aw_addr15};
  assign mem_ar_addr = {17'b0, mem_ar_addr15};

  axi_rom_bridge #(.IW(IW), .DW(32)) i_rom (
      .clk(clk), .rst_n(rst_n),
      .imem_addr(imem_addr), .imem_rdata(imem_rdata),
      .ar_id(mem_ar_id), .ar_addr(mem_ar_addr), .ar_len(mem_ar_len), .ar_size(mem_ar_size),
      .ar_burst(mem_ar_burst), .ar_valid(mem_ar_valid), .ar_ready(mem_ar_ready),
      .r_id(mem_r_id), .r_data(mem_r_data), .r_resp(mem_r_resp), .r_last(mem_r_last),
      .r_valid(mem_r_valid), .r_ready(mem_r_ready),
      .aw_id(mem_aw_id), .aw_valid(mem_aw_valid), .aw_ready(mem_aw_ready),
      .w_last(mem_w_last), .w_valid(mem_w_valid), .w_ready(mem_w_ready),
      .b_id(mem_b_id), .b_resp(mem_b_resp), .b_valid(mem_b_valid), .b_ready(mem_b_ready)
  );

  axi4_to_axil #(.IW(IW), .DW(32)) i_mmio (
      .clk(clk), .rst_n(rst_n),
      .aw_id(io_aw_id), .aw_addr(io_aw_addr), .aw_len(io_aw_len), .aw_prot(io_aw_prot),
      .aw_valid(io_aw_valid), .aw_ready(io_aw_ready),
      .w_data(io_w_data), .w_strb(io_w_strb), .w_valid(io_w_valid), .w_ready(io_w_ready),
      .b_id(io_b_id), .b_resp(io_b_resp), .b_valid(io_b_valid), .b_ready(io_b_ready),
      .ar_id(io_ar_id), .ar_addr(io_ar_addr), .ar_len(io_ar_len), .ar_prot(io_ar_prot),
      .ar_valid(io_ar_valid), .ar_ready(io_ar_ready),
      .r_id(io_r_id), .r_data(io_r_data), .r_resp(io_r_resp), .r_last(io_r_last),
      .r_valid(io_r_valid), .r_ready(io_r_ready),
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
endmodule
