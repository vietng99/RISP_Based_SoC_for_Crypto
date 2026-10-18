`timescale 1ns / 1ps
// Ibex SoC, open-source rebuild of Vivado block design
// RISP/hardware/projects/Ibex_SoC/Ibex_SoC.srcs/sources_1/bd/design_1.
// Generated from rtl/soc/design_1.sv (RISSP): only the CPU block and the
// boot-offset subtractor differ; peripherals, address map and IP parameters
// are the same in both .bd files.
//
// Module, instance and net names follow the Vivado-generated design_1.v on
// purpose: the original testbenches in RISP/hardware/testbench/ibex probe
// dut.design_1_i.<instance>.<port> and dut.design_1_i.<net>, and they run
// here unmodified.
//
// Vivado IP                      -> replacement
//   ibex_core_0  (user IP)       -> same RTL (ip_repo/cpu_ibex/ip_repo/src,
//                                   ibex_axi_top, xci: RV32M=0 RV32B=0
//                                   RV32ZC=3 ICache=0 PMPEnable=0 BootAddr=0)
//   addsub_bootoffset_0          -> A - 13'b0000000100000 (c_addsub, Subtract,
//                                   constant B, latency 0): Ibex boots at 0x80
//   aes / SHA3 / RSA (user IP)   -> same RTL (ip_repo/acc_*), ip_wrappers.v
//   axi_interconnect_0           -> axil_xbar_flat (pulp-platform/axi)
//   axi_bram_ctrl_0              -> axil_bram_ctrl
//   blk_mem_gen_0 (imem ROM)     -> rom_sync (+FIRMWARE=<hex> in simulation)
//   blk_mem_gen_1 (data RAM)     -> ram_sp_be
//   axi_uartlite_0               -> axil_uartlite
//   clk_wiz_0                    -> clk_passthru (no PLL)
//   proc_sys_reset_0             -> sys_reset
//   xlslice_0 (imem_addr[14:2])  -> wire slice
//
// Address map (end exclusive), from design_1.bd:
//   M00 AES   0x4000_0000 16K   M01 SHA3 0x4400_0000 64K
//   M02 RSA   0x4800_0000 64K   M03 BRAM 0xC000_0000  8K
//   M04 UART  0x4060_0000 64K
module design_1 #(
    parameter IMEM_INIT = "",
    // axi_pkg::xbar_latency_e of the crossbar (0 = NO_LATENCY)
    parameter bit [9:0] XBAR_LATENCY = 10'b0
) (
    input  wire UART_0_rxd,
    output wire UART_0_txd,
    input  wire clk_in1_0,
    input  wire reset_0
);
    // ---------------- clock / reset ----------------
    wire clk_wiz_0_clk_out1;
    wire clk_wiz_0_locked;
    wire proc_sys_reset_0_peripheral_aresetn;

    clk_passthru clk_wiz_0 (
        .clk_in1(clk_in1_0), .reset(reset_0),
        .clk_out1(clk_wiz_0_clk_out1), .locked(clk_wiz_0_locked)
    );

    sys_reset proc_sys_reset_0 (
        .slowest_sync_clk(clk_wiz_0_clk_out1),
        .ext_reset_in(reset_0), .dcm_locked(clk_wiz_0_locked),
        .peripheral_aresetn(proc_sys_reset_0_peripheral_aresetn)
    );

    wire clk    = clk_wiz_0_clk_out1;
    wire rst_n  = proc_sys_reset_0_peripheral_aresetn;

    // ---------------- CPU + instruction ROM ----------------
    wire [31:0] ibex_core_0_imem_addr;
    wire [12:0] xlslice_0_Dout = ibex_core_0_imem_addr[14:2];
    wire [12:0] addsub_bootoffset_0_S = xlslice_0_Dout - 13'b0000000100000;
    wire [31:0] blk_mem_gen_0_douta;

    wire [31:0] ibex_core_0_m_axi_AWADDR, ibex_core_0_m_axi_WDATA;
    wire [31:0] ibex_core_0_m_axi_ARADDR, ibex_core_0_m_axi_RDATA;
    wire [2:0]  ibex_core_0_m_axi_AWPROT, ibex_core_0_m_axi_ARPROT;
    wire [3:0]  ibex_core_0_m_axi_WSTRB;
    wire [1:0]  ibex_core_0_m_axi_BRESP,  ibex_core_0_m_axi_RRESP;
    wire        ibex_core_0_m_axi_AWVALID, ibex_core_0_m_axi_AWREADY;
    wire        ibex_core_0_m_axi_WVALID,  ibex_core_0_m_axi_WREADY;
    wire        ibex_core_0_m_axi_BVALID,  ibex_core_0_m_axi_BREADY;
    wire        ibex_core_0_m_axi_ARVALID, ibex_core_0_m_axi_ARREADY;
    wire        ibex_core_0_m_axi_RVALID,  ibex_core_0_m_axi_RREADY;

    ibex_axi_top #(
        .RV32M(0), .RV32B(0), .RV32ZC(3), .RV32E(1'b0), .ICache(1'b0),
        .PMPEnable(1'b0), .MHPMCounterNum(0), .BootAddr(32'h0), .HartId(32'h0)
    ) ibex_core_0 (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(ibex_core_0_imem_addr), .imem_rdata(blk_mem_gen_0_douta),
        .m_axi_awaddr(ibex_core_0_m_axi_AWADDR), .m_axi_awprot(ibex_core_0_m_axi_AWPROT),
        .m_axi_awvalid(ibex_core_0_m_axi_AWVALID), .m_axi_awready(ibex_core_0_m_axi_AWREADY),
        .m_axi_wdata(ibex_core_0_m_axi_WDATA), .m_axi_wstrb(ibex_core_0_m_axi_WSTRB),
        .m_axi_wvalid(ibex_core_0_m_axi_WVALID), .m_axi_wready(ibex_core_0_m_axi_WREADY),
        .m_axi_bresp(ibex_core_0_m_axi_BRESP), .m_axi_bvalid(ibex_core_0_m_axi_BVALID),
        .m_axi_bready(ibex_core_0_m_axi_BREADY),
        .m_axi_araddr(ibex_core_0_m_axi_ARADDR), .m_axi_arprot(ibex_core_0_m_axi_ARPROT),
        .m_axi_arvalid(ibex_core_0_m_axi_ARVALID), .m_axi_arready(ibex_core_0_m_axi_ARREADY),
        .m_axi_rdata(ibex_core_0_m_axi_RDATA), .m_axi_rresp(ibex_core_0_m_axi_RRESP),
        .m_axi_rvalid(ibex_core_0_m_axi_RVALID), .m_axi_rready(ibex_core_0_m_axi_RREADY)
    );

    rom_sync #(.DEPTH(8192), .AW(13), .INIT_FILE(IMEM_INIT)) blk_mem_gen_0 (
        .clka(clk), .addra(addsub_bootoffset_0_S), .douta(blk_mem_gen_0_douta)
    );

    // ---------------- interconnect: 1 master, 5 slaves ----------------
    localparam int NM = 5;
    wire [NM*32-1:0] m_awaddr, m_wdata, m_araddr, m_rdata;
    wire [NM*3-1:0]  m_awprot, m_arprot;
    wire [NM*4-1:0]  m_wstrb;
    wire [NM*2-1:0]  m_bresp, m_rresp;
    wire [NM-1:0]    m_awvalid, m_awready, m_wvalid, m_wready, m_bvalid, m_bready;
    wire [NM-1:0]    m_arvalid, m_arready, m_rvalid, m_rready;

    axil_xbar_flat #(
        .NUM_S(1), .NUM_M(NM), .ADDR_WIDTH(32), .DATA_WIDTH(32),
        .M_BASE({32'h4060_0000, 32'hC000_0000, 32'h4800_0000, 32'h4400_0000, 32'h4000_0000}),
        .M_END ({32'h4061_0000, 32'hC000_2000, 32'h4801_0000, 32'h4401_0000, 32'h4000_4000}),
        .LATENCY_MODE(XBAR_LATENCY), .MAX_TRANS(1)
    ) axi_interconnect_0 (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axil_awaddr(ibex_core_0_m_axi_AWADDR), .s_axil_awprot(ibex_core_0_m_axi_AWPROT),
        .s_axil_awvalid(ibex_core_0_m_axi_AWVALID), .s_axil_awready(ibex_core_0_m_axi_AWREADY),
        .s_axil_wdata(ibex_core_0_m_axi_WDATA), .s_axil_wstrb(ibex_core_0_m_axi_WSTRB),
        .s_axil_wvalid(ibex_core_0_m_axi_WVALID), .s_axil_wready(ibex_core_0_m_axi_WREADY),
        .s_axil_bresp(ibex_core_0_m_axi_BRESP), .s_axil_bvalid(ibex_core_0_m_axi_BVALID),
        .s_axil_bready(ibex_core_0_m_axi_BREADY),
        .s_axil_araddr(ibex_core_0_m_axi_ARADDR), .s_axil_arprot(ibex_core_0_m_axi_ARPROT),
        .s_axil_arvalid(ibex_core_0_m_axi_ARVALID), .s_axil_arready(ibex_core_0_m_axi_ARREADY),
        .s_axil_rdata(ibex_core_0_m_axi_RDATA), .s_axil_rresp(ibex_core_0_m_axi_RRESP),
        .s_axil_rvalid(ibex_core_0_m_axi_RVALID), .s_axil_rready(ibex_core_0_m_axi_RREADY),
        .m_axil_awaddr(m_awaddr), .m_axil_awprot(m_awprot),
        .m_axil_awvalid(m_awvalid), .m_axil_awready(m_awready),
        .m_axil_wdata(m_wdata), .m_axil_wstrb(m_wstrb),
        .m_axil_wvalid(m_wvalid), .m_axil_wready(m_wready),
        .m_axil_bresp(m_bresp), .m_axil_bvalid(m_bvalid), .m_axil_bready(m_bready),
        .m_axil_araddr(m_araddr), .m_axil_arprot(m_arprot),
        .m_axil_arvalid(m_arvalid), .m_axil_arready(m_arready),
        .m_axil_rdata(m_rdata), .m_axil_rresp(m_rresp),
        .m_axil_rvalid(m_rvalid), .m_axil_rready(m_rready)
    );

    // ---------------- M00: AES ----------------
    ip_aes_axil aes_axi_slave_0 (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(m_awaddr[0*32 +: 32]), .S_AXI_AWVALID(m_awvalid[0]), .S_AXI_AWREADY(m_awready[0]),
        .S_AXI_WDATA(m_wdata[0*32 +: 32]), .S_AXI_WSTRB(m_wstrb[0*4 +: 4]),
        .S_AXI_WVALID(m_wvalid[0]), .S_AXI_WREADY(m_wready[0]),
        .S_AXI_BRESP(m_bresp[0*2 +: 2]), .S_AXI_BVALID(m_bvalid[0]), .S_AXI_BREADY(m_bready[0]),
        .S_AXI_ARADDR(m_araddr[0*32 +: 32]), .S_AXI_ARVALID(m_arvalid[0]), .S_AXI_ARREADY(m_arready[0]),
        .S_AXI_RDATA(m_rdata[0*32 +: 32]), .S_AXI_RRESP(m_rresp[0*2 +: 2]),
        .S_AXI_RVALID(m_rvalid[0]), .S_AXI_RREADY(m_rready[0])
    );

    // ---------------- M01: SHA3 ----------------
    ip_sha3_axil SHA3_hardware_new_0 (
        .s01_axi_aclk(clk), .s01_axi_aresetn(rst_n),
        .s01_axi_awaddr(m_awaddr[1*32 +: 8]), .s01_axi_awprot(m_awprot[1*3 +: 3]),
        .s01_axi_awvalid(m_awvalid[1]), .s01_axi_awready(m_awready[1]),
        .s01_axi_wdata(m_wdata[1*32 +: 32]), .s01_axi_wstrb(m_wstrb[1*4 +: 4]),
        .s01_axi_wvalid(m_wvalid[1]), .s01_axi_wready(m_wready[1]),
        .s01_axi_bresp(m_bresp[1*2 +: 2]), .s01_axi_bvalid(m_bvalid[1]), .s01_axi_bready(m_bready[1]),
        .s01_axi_araddr(m_araddr[1*32 +: 8]), .s01_axi_arprot(m_arprot[1*3 +: 3]),
        .s01_axi_arvalid(m_arvalid[1]), .s01_axi_arready(m_arready[1]),
        .s01_axi_rdata(m_rdata[1*32 +: 32]), .s01_axi_rresp(m_rresp[1*2 +: 2]),
        .s01_axi_rvalid(m_rvalid[1]), .s01_axi_rready(m_rready[1])
    );

    // ---------------- M02: RSA ----------------
    ip_rsa_axil RSA_mark03_0 (
        .s00_axi_aclk(clk), .s00_axi_aresetn(rst_n),
        .s00_axi_awaddr(m_awaddr[2*32 +: 12]), .s00_axi_awprot(m_awprot[2*3 +: 3]),
        .s00_axi_awvalid(m_awvalid[2]), .s00_axi_awready(m_awready[2]),
        .s00_axi_wdata(m_wdata[2*32 +: 32]), .s00_axi_wstrb(m_wstrb[2*4 +: 4]),
        .s00_axi_wvalid(m_wvalid[2]), .s00_axi_wready(m_wready[2]),
        .s00_axi_bresp(m_bresp[2*2 +: 2]), .s00_axi_bvalid(m_bvalid[2]), .s00_axi_bready(m_bready[2]),
        .s00_axi_araddr(m_araddr[2*32 +: 12]), .s00_axi_arprot(m_arprot[2*3 +: 3]),
        .s00_axi_arvalid(m_arvalid[2]), .s00_axi_arready(m_arready[2]),
        .s00_axi_rdata(m_rdata[2*32 +: 32]), .s00_axi_rresp(m_rresp[2*2 +: 2]),
        .s00_axi_rvalid(m_rvalid[2]), .s00_axi_rready(m_rready[2])
    );

    // ---------------- M03: data BRAM (8 KB) ----------------
    wire        axi_bram_ctrl_0_BRAM_PORTA_CLK;
    wire        axi_bram_ctrl_0_BRAM_PORTA_RST;
    wire        axi_bram_ctrl_0_BRAM_PORTA_EN;
    wire [3:0]  axi_bram_ctrl_0_BRAM_PORTA_WE;
    wire [12:0] axi_bram_ctrl_0_BRAM_PORTA_ADDR;
    wire [31:0] axi_bram_ctrl_0_BRAM_PORTA_DIN;
    wire [31:0] axi_bram_ctrl_0_BRAM_PORTA_DOUT;

    axil_bram_ctrl #(.BRAM_AW(13)) axi_bram_ctrl_0 (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(m_awaddr[3*32 +: 32]), .s_axi_awvalid(m_awvalid[3]), .s_axi_awready(m_awready[3]),
        .s_axi_wdata(m_wdata[3*32 +: 32]), .s_axi_wstrb(m_wstrb[3*4 +: 4]),
        .s_axi_wvalid(m_wvalid[3]), .s_axi_wready(m_wready[3]),
        .s_axi_bresp(m_bresp[3*2 +: 2]), .s_axi_bvalid(m_bvalid[3]), .s_axi_bready(m_bready[3]),
        .s_axi_araddr(m_araddr[3*32 +: 32]), .s_axi_arvalid(m_arvalid[3]), .s_axi_arready(m_arready[3]),
        .s_axi_rdata(m_rdata[3*32 +: 32]), .s_axi_rresp(m_rresp[3*2 +: 2]),
        .s_axi_rvalid(m_rvalid[3]), .s_axi_rready(m_rready[3]),
        .bram_clk(axi_bram_ctrl_0_BRAM_PORTA_CLK), .bram_rst(axi_bram_ctrl_0_BRAM_PORTA_RST),
        .bram_en(axi_bram_ctrl_0_BRAM_PORTA_EN), .bram_we(axi_bram_ctrl_0_BRAM_PORTA_WE),
        .bram_addr(axi_bram_ctrl_0_BRAM_PORTA_ADDR), .bram_wrdata(axi_bram_ctrl_0_BRAM_PORTA_DIN),
        .bram_rddata(axi_bram_ctrl_0_BRAM_PORTA_DOUT)
    );

    ram_sp_be #(.DEPTH(2048), .AW(11)) blk_mem_gen_1 (
        .clka(axi_bram_ctrl_0_BRAM_PORTA_CLK), .ena(axi_bram_ctrl_0_BRAM_PORTA_EN),
        .wea(axi_bram_ctrl_0_BRAM_PORTA_WE), .addra(axi_bram_ctrl_0_BRAM_PORTA_ADDR[12:2]),
        .dina(axi_bram_ctrl_0_BRAM_PORTA_DIN), .douta(axi_bram_ctrl_0_BRAM_PORTA_DOUT)
    );

    // ---------------- M04: UART ----------------
    axil_uartlite #(.CLK_HZ(40000000), .BAUD(9600)) axi_uartlite_0 (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(m_awaddr[4*32 +: 4]), .s_axi_awvalid(m_awvalid[4]), .s_axi_awready(m_awready[4]),
        .s_axi_wdata(m_wdata[4*32 +: 32]), .s_axi_wstrb(m_wstrb[4*4 +: 4]),
        .s_axi_wvalid(m_wvalid[4]), .s_axi_wready(m_wready[4]),
        .s_axi_bresp(m_bresp[4*2 +: 2]), .s_axi_bvalid(m_bvalid[4]), .s_axi_bready(m_bready[4]),
        .s_axi_araddr(m_araddr[4*32 +: 4]), .s_axi_arvalid(m_arvalid[4]), .s_axi_arready(m_arready[4]),
        .s_axi_rdata(m_rdata[4*32 +: 32]), .s_axi_rresp(m_rresp[4*2 +: 2]),
        .s_axi_rvalid(m_rvalid[4]), .s_axi_rready(m_rready[4]),
        .rx(UART_0_rxd), .tx(UART_0_txd)
    );
endmodule

// Same ports and instance name as the Vivado-generated design_1_wrapper.v.
module design_1_wrapper #(
    parameter IMEM_INIT = "",
    parameter bit [9:0] XBAR_LATENCY = 10'b0
) (
    input  wire UART_0_rxd,
    output wire UART_0_txd,
    input  wire clk_in1_0,
    input  wire reset_0
);
    design_1 #(.IMEM_INIT(IMEM_INIT), .XBAR_LATENCY(XBAR_LATENCY)) design_1_i (
        .UART_0_rxd(UART_0_rxd), .UART_0_txd(UART_0_txd),
        .clk_in1_0(clk_in1_0), .reset_0(reset_0)
    );
endmodule
