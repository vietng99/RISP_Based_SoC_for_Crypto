`timescale 1ns / 1ps
// [core_soc block design] cpu_core: the RV32I (rv32i_ultra) CPU behind one common port list, so the
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

    // rv32i_ultra starts its AXI master on m00_axi_init_axi_txn = 1 (xlconstant_0 in the
    // owner's RV32I block design).
    rv32i_ultra #(
        .C_M00_AXI_ADDR_WIDTH(32), .C_M00_AXI_DATA_WIDTH(32), .C_M00_AXI_TRANSACTIONS_NUM(4)
    ) core (
        .m00_axi_init_axi_txn(1'b1), .m00_axi_error(), .m00_axi_txn_done(),
        .m00_axi_aclk(clk), .m00_axi_aresetn(rst_n),
        .inst_addr(imem_addr), .inst_data(imem_rdata),
        .m00_axi_awaddr(m_axi_awaddr), .m00_axi_awprot(m_axi_awprot),
        .m00_axi_awvalid(m_axi_awvalid), .m00_axi_awready(m_axi_awready),
        .m00_axi_wdata(m_axi_wdata), .m00_axi_wstrb(m_axi_wstrb),
        .m00_axi_wvalid(m_axi_wvalid), .m00_axi_wready(m_axi_wready),
        .m00_axi_bresp(m_axi_bresp), .m00_axi_bvalid(m_axi_bvalid), .m00_axi_bready(m_axi_bready),
        .m00_axi_araddr(m_axi_araddr), .m00_axi_arprot(m_axi_arprot),
        .m00_axi_arvalid(m_axi_arvalid), .m00_axi_arready(m_axi_arready),
        .m00_axi_rdata(m_axi_rdata), .m00_axi_rresp(m_axi_rresp),
        .m00_axi_rvalid(m_axi_rvalid), .m00_axi_rready(m_axi_rready)
    );
endmodule
