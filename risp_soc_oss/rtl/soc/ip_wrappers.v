`timescale 1ns / 1ps
// Thin wrappers that put each accelerator under an instance called `inst`,
// the same hierarchy Vivado's IP packager generates (design_1_<ip>_0_N.v).
// They exist so testbench probes such as
//   dut.design_1_i.aes_axi_slave_0.inst.aes_inst.aes_done_latched
// resolve unchanged. Parameter values are copied from the Vivado .xci files
// of RISSP_SoC/design_1.

module ip_aes_axil (
    input  wire        S_AXI_ACLK, S_AXI_ARESETN,
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID, output wire S_AXI_AWREADY,
    input  wire [31:0] S_AXI_WDATA,
    input  wire [3:0]  S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,  output wire S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,   output wire S_AXI_BVALID, input wire S_AXI_BREADY,
    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID, output wire S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,   output wire S_AXI_RVALID, input wire S_AXI_RREADY
);
    aes_axi_slave #(.C_S_AXI_DATA_WIDTH(32), .C_S_AXI_ADDR_WIDTH(32)) inst (
        .S_AXI_ACLK(S_AXI_ACLK), .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID), .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA), .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID), .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP), .S_AXI_BVALID(S_AXI_BVALID), .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID), .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA), .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID), .S_AXI_RREADY(S_AXI_RREADY)
    );
endmodule

module ip_sha3_axil (
    input  wire        s01_axi_aclk, s01_axi_aresetn,
    input  wire [7:0]  s01_axi_awaddr,
    input  wire [2:0]  s01_axi_awprot,
    input  wire        s01_axi_awvalid, output wire s01_axi_awready,
    input  wire [31:0] s01_axi_wdata,
    input  wire [3:0]  s01_axi_wstrb,
    input  wire        s01_axi_wvalid,  output wire s01_axi_wready,
    output wire [1:0]  s01_axi_bresp,   output wire s01_axi_bvalid, input wire s01_axi_bready,
    input  wire [7:0]  s01_axi_araddr,
    input  wire [2:0]  s01_axi_arprot,
    input  wire        s01_axi_arvalid, output wire s01_axi_arready,
    output wire [31:0] s01_axi_rdata,
    output wire [1:0]  s01_axi_rresp,   output wire s01_axi_rvalid, input wire s01_axi_rready
);
    SHA3_hardware_new #(.C_S01_AXI_DATA_WIDTH(32), .C_S01_AXI_ADDR_WIDTH(8)) inst (
        .s01_axi_aclk(s01_axi_aclk), .s01_axi_aresetn(s01_axi_aresetn),
        .s01_axi_awaddr(s01_axi_awaddr), .s01_axi_awprot(s01_axi_awprot),
        .s01_axi_awvalid(s01_axi_awvalid), .s01_axi_awready(s01_axi_awready),
        .s01_axi_wdata(s01_axi_wdata), .s01_axi_wstrb(s01_axi_wstrb),
        .s01_axi_wvalid(s01_axi_wvalid), .s01_axi_wready(s01_axi_wready),
        .s01_axi_bresp(s01_axi_bresp), .s01_axi_bvalid(s01_axi_bvalid), .s01_axi_bready(s01_axi_bready),
        .s01_axi_araddr(s01_axi_araddr), .s01_axi_arprot(s01_axi_arprot),
        .s01_axi_arvalid(s01_axi_arvalid), .s01_axi_arready(s01_axi_arready),
        .s01_axi_rdata(s01_axi_rdata), .s01_axi_rresp(s01_axi_rresp),
        .s01_axi_rvalid(s01_axi_rvalid), .s01_axi_rready(s01_axi_rready)
    );
endmodule

module ip_rsa_axil (
    input  wire        s00_axi_aclk, s00_axi_aresetn,
    input  wire [11:0] s00_axi_awaddr,
    input  wire [2:0]  s00_axi_awprot,
    input  wire        s00_axi_awvalid, output wire s00_axi_awready,
    input  wire [31:0] s00_axi_wdata,
    input  wire [3:0]  s00_axi_wstrb,
    input  wire        s00_axi_wvalid,  output wire s00_axi_wready,
    output wire [1:0]  s00_axi_bresp,   output wire s00_axi_bvalid, input wire s00_axi_bready,
    input  wire [11:0] s00_axi_araddr,
    input  wire [2:0]  s00_axi_arprot,
    input  wire        s00_axi_arvalid, output wire s00_axi_arready,
    output wire [31:0] s00_axi_rdata,
    output wire [1:0]  s00_axi_rresp,   output wire s00_axi_rvalid, input wire s00_axi_rready
);
    RSA_mark03 #(
        .C_S00_AXI_DATA_WIDTH(32), .C_S00_AXI_ADDR_WIDTH(12),
        .RSA_WIDTH(2048), .RSA_E_SCAN(17), .RSA_CONST_TIME(1)
    ) inst (
        .s00_axi_aclk(s00_axi_aclk), .s00_axi_aresetn(s00_axi_aresetn),
        .s00_axi_awaddr(s00_axi_awaddr), .s00_axi_awprot(s00_axi_awprot),
        .s00_axi_awvalid(s00_axi_awvalid), .s00_axi_awready(s00_axi_awready),
        .s00_axi_wdata(s00_axi_wdata), .s00_axi_wstrb(s00_axi_wstrb),
        .s00_axi_wvalid(s00_axi_wvalid), .s00_axi_wready(s00_axi_wready),
        .s00_axi_bresp(s00_axi_bresp), .s00_axi_bvalid(s00_axi_bvalid), .s00_axi_bready(s00_axi_bready),
        .s00_axi_araddr(s00_axi_araddr), .s00_axi_arprot(s00_axi_arprot),
        .s00_axi_arvalid(s00_axi_arvalid), .s00_axi_arready(s00_axi_arready),
        .s00_axi_rdata(s00_axi_rdata), .s00_axi_rresp(s00_axi_rresp),
        .s00_axi_rvalid(s00_axi_rvalid), .s00_axi_rready(s00_axi_rready)
    );
endmodule
