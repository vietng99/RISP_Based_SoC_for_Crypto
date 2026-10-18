`timescale 1ns / 1ps
// RV32I SoC, open-source rebuild of Vivado block design
// RISP/hardware/projects/RV32I_SoC/RV32I_soc_ULTRA.srcs/sources_1/bd/design_1.
// Copy of rtl/soc/design_1.sv (RISSP) with the CPU block swapped; the rest
// of the block design is the same (checked against the Vivado design_1.v and
// design_1.bd: same IP list, clocks, memory depths, address map except the
// AES segment, which is 64K here instead of 16K).
//
// Build this file instead of design_1.sv (both define design_1 and
// design_1_wrapper): flist/rv32i_soc.f, mk/rv32i.mk.
//
// Module, instance and net names follow the Vivado-generated design_1.v on
// purpose: the original testbenches in RISP/hardware/testbench/rv32i probe
// dut.design_1_i.<instance>.<port> and dut.design_1_i.<net>, and they run
// here unmodified.
//
// Vivado IP                      -> replacement
//   rv32i_fixed_0 (user IP)      -> same RTL (ip_repo/cpu_rv32i/ip_repo/rv32i_fixed_1_0,
//                                   top module rv32i_ultra, as in the Vivado
//                                   wrapper design_1_rv32i_fixed_0_0.v)
//   xlconstant_0 (CONST_VAL = 1) -> 1'b1 on m00_axi_init_axi_txn
//   aes / SHA3 / RSA (user IP)   -> same RTL (ip_repo/acc_*), ip_wrappers.v
//   axi_interconnect_0           -> axil_xbar_flat (pulp-platform/axi)
//   axi_bram_ctrl_0              -> axil_bram_ctrl
//   blk_mem_gen_0 (imem ROM)     -> rom_sync (+FIRMWARE=<hex> in simulation)
//   blk_mem_gen_1 (data RAM)     -> ram_sp_be
//   axi_uartlite_0               -> axil_uartlite
//   clk_wiz_0                    -> clk_passthru (no PLL)
//   proc_sys_reset_0             -> sys_reset
//   xlslice_0 (inst_addr[14:2])  -> wire slice
//
// Address map (end exclusive), from design_1.bd:
//   M00 AES   0x4000_0000 64K   M01 SHA3 0x4400_0000 64K
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
    wire [31:0] rv32i_fixed_0_inst_addr;
    wire [12:0] xlslice_0_Dout = rv32i_fixed_0_inst_addr[14:2];
    wire [31:0] blk_mem_gen_0_douta;
    wire [0:0]  xlconstant_0_dout = 1'b1;

    wire [31:0] rv32i_fixed_0_M00_AXI_AWADDR, rv32i_fixed_0_M00_AXI_WDATA;
    wire [31:0] rv32i_fixed_0_M00_AXI_ARADDR, rv32i_fixed_0_M00_AXI_RDATA;
    wire [2:0]  rv32i_fixed_0_M00_AXI_AWPROT, rv32i_fixed_0_M00_AXI_ARPROT;
    wire [3:0]  rv32i_fixed_0_M00_AXI_WSTRB;
    wire [1:0]  rv32i_fixed_0_M00_AXI_BRESP,  rv32i_fixed_0_M00_AXI_RRESP;
    wire        rv32i_fixed_0_M00_AXI_AWVALID, rv32i_fixed_0_M00_AXI_AWREADY;
    wire        rv32i_fixed_0_M00_AXI_WVALID,  rv32i_fixed_0_M00_AXI_WREADY;
    wire        rv32i_fixed_0_M00_AXI_BVALID,  rv32i_fixed_0_M00_AXI_BREADY;
    wire        rv32i_fixed_0_M00_AXI_ARVALID, rv32i_fixed_0_M00_AXI_ARREADY;
    wire        rv32i_fixed_0_M00_AXI_RVALID,  rv32i_fixed_0_M00_AXI_RREADY;

    rv32i_ultra #(
        .C_M00_AXI_ADDR_WIDTH(32), .C_M00_AXI_DATA_WIDTH(32), .C_M00_AXI_TRANSACTIONS_NUM(4)
    ) rv32i_fixed_0 (
        .m00_axi_init_axi_txn(xlconstant_0_dout), .m00_axi_error(), .m00_axi_txn_done(),
        .m00_axi_aclk(clk), .m00_axi_aresetn(rst_n),
        .inst_addr(rv32i_fixed_0_inst_addr), .inst_data(blk_mem_gen_0_douta),
        .m00_axi_awaddr(rv32i_fixed_0_M00_AXI_AWADDR), .m00_axi_awprot(rv32i_fixed_0_M00_AXI_AWPROT),
        .m00_axi_awvalid(rv32i_fixed_0_M00_AXI_AWVALID), .m00_axi_awready(rv32i_fixed_0_M00_AXI_AWREADY),
        .m00_axi_wdata(rv32i_fixed_0_M00_AXI_WDATA), .m00_axi_wstrb(rv32i_fixed_0_M00_AXI_WSTRB),
        .m00_axi_wvalid(rv32i_fixed_0_M00_AXI_WVALID), .m00_axi_wready(rv32i_fixed_0_M00_AXI_WREADY),
        .m00_axi_bresp(rv32i_fixed_0_M00_AXI_BRESP), .m00_axi_bvalid(rv32i_fixed_0_M00_AXI_BVALID),
        .m00_axi_bready(rv32i_fixed_0_M00_AXI_BREADY),
        .m00_axi_araddr(rv32i_fixed_0_M00_AXI_ARADDR), .m00_axi_arprot(rv32i_fixed_0_M00_AXI_ARPROT),
        .m00_axi_arvalid(rv32i_fixed_0_M00_AXI_ARVALID), .m00_axi_arready(rv32i_fixed_0_M00_AXI_ARREADY),
        .m00_axi_rdata(rv32i_fixed_0_M00_AXI_RDATA), .m00_axi_rresp(rv32i_fixed_0_M00_AXI_RRESP),
        .m00_axi_rvalid(rv32i_fixed_0_M00_AXI_RVALID), .m00_axi_rready(rv32i_fixed_0_M00_AXI_RREADY)
    );

    rom_sync #(.DEPTH(8192), .AW(13), .INIT_FILE(IMEM_INIT)) blk_mem_gen_0 (
        .clka(clk), .addra(xlslice_0_Dout), .douta(blk_mem_gen_0_douta)
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
        .M_END ({32'h4061_0000, 32'hC000_2000, 32'h4801_0000, 32'h4401_0000, 32'h4001_0000}),
        .LATENCY_MODE(XBAR_LATENCY), .MAX_TRANS(1)
    ) axi_interconnect_0 (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axil_awaddr(rv32i_fixed_0_M00_AXI_AWADDR), .s_axil_awprot(rv32i_fixed_0_M00_AXI_AWPROT),
        .s_axil_awvalid(rv32i_fixed_0_M00_AXI_AWVALID), .s_axil_awready(rv32i_fixed_0_M00_AXI_AWREADY),
        .s_axil_wdata(rv32i_fixed_0_M00_AXI_WDATA), .s_axil_wstrb(rv32i_fixed_0_M00_AXI_WSTRB),
        .s_axil_wvalid(rv32i_fixed_0_M00_AXI_WVALID), .s_axil_wready(rv32i_fixed_0_M00_AXI_WREADY),
        .s_axil_bresp(rv32i_fixed_0_M00_AXI_BRESP), .s_axil_bvalid(rv32i_fixed_0_M00_AXI_BVALID),
        .s_axil_bready(rv32i_fixed_0_M00_AXI_BREADY),
        .s_axil_araddr(rv32i_fixed_0_M00_AXI_ARADDR), .s_axil_arprot(rv32i_fixed_0_M00_AXI_ARPROT),
        .s_axil_arvalid(rv32i_fixed_0_M00_AXI_ARVALID), .s_axil_arready(rv32i_fixed_0_M00_AXI_ARREADY),
        .s_axil_rdata(rv32i_fixed_0_M00_AXI_RDATA), .s_axil_rresp(rv32i_fixed_0_M00_AXI_RRESP),
        .s_axil_rvalid(rv32i_fixed_0_M00_AXI_RVALID), .s_axil_rready(rv32i_fixed_0_M00_AXI_RREADY),
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
