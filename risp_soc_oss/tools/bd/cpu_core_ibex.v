`timescale 1ns / 1ps
// [core_soc block design] cpu_core: the Ibex (ibex_axi_top, RV32M=0) CPU behind one common port list, so the
// block design (design_1, paper Fig. 6) is the same for every SoC and only this block
// changes. Plain Verilog so Vivado can add it as a module reference.
module cpu_core (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi, ASSOCIATED_RESET rst_n" *)
    input  wire        clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
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

    // Ibex fetches its first instruction at BootAddr + 0x80. The owner's Ibex block design
    // subtracts 32 words from the ROM word address (addsub_bootoffset_0); the same
    // subtraction is done here so the ROM still starts at word 0.
    wire [31:0] core_imem_addr;
    assign imem_addr = core_imem_addr - 32'h80;

    ibex_axi_top #(
        .RV32M(0), .RV32B(0), .RV32ZC(3), .RV32E(1'b0), .ICache(1'b0),
        .PMPEnable(1'b0), .MHPMCounterNum(0), .BootAddr(32'h0), .HartId(32'h0)
    ) core (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(core_imem_addr), .imem_rdata(imem_rdata),
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
endmodule
