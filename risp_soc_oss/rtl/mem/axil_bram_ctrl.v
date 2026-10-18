`timescale 1ns / 1ps
// AXI4-Lite to single-port BRAM controller, one transaction at a time.
// Replaces Vivado axi_bram_ctrl_0 (+ the AXI4-Lite -> AXI4 auto_pc in front
// of it). The BRAM port has the same shape as Xilinx BRAM_PORTA: byte address
// (low 2 bits zero), 4 byte write enables, 1-cycle read latency.
//
// Write: AW and W are accepted together in one cycle, the BRAM write happens
//        in that cycle, BVALID rises on the next one.
// Read:  AR is accepted, the BRAM read is issued in that cycle, RVALID rises
//        on the next one with the BRAM output (held while EN is low).
// A write wins when a write and a read arrive in the same cycle.
module axil_bram_ctrl #(
    parameter integer BRAM_AW = 13      // byte address bits (8 KB)
) (
    input  wire               clk, rst_n,
    input  wire [31:0]        s_axi_awaddr,
    input  wire               s_axi_awvalid,
    output wire               s_axi_awready,
    input  wire [31:0]        s_axi_wdata,
    input  wire [3:0]         s_axi_wstrb,
    input  wire               s_axi_wvalid,
    output wire               s_axi_wready,
    output wire [1:0]         s_axi_bresp,
    output reg                s_axi_bvalid,
    input  wire               s_axi_bready,
    input  wire [31:0]        s_axi_araddr,
    input  wire               s_axi_arvalid,
    output wire               s_axi_arready,
    output wire [31:0]        s_axi_rdata,
    output wire [1:0]         s_axi_rresp,
    output reg                s_axi_rvalid,
    input  wire               s_axi_rready,

    output wire               bram_clk,
    output wire               bram_rst,
    output wire               bram_en,
    output wire [3:0]         bram_we,
    output wire [BRAM_AW-1:0] bram_addr,
    output wire [31:0]        bram_wrdata,
    input  wire [31:0]        bram_rddata
);
    wire idle   = !s_axi_bvalid && !s_axi_rvalid;
    wire do_wr  = idle && s_axi_awvalid && s_axi_wvalid;
    wire do_rd  = idle && !do_wr && s_axi_arvalid;

    assign s_axi_awready = do_wr;
    assign s_axi_wready  = do_wr;
    assign s_axi_arready = do_rd;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rdata   = bram_rddata;

    assign bram_clk    = clk;
    assign bram_rst    = !rst_n;
    assign bram_en     = do_wr || do_rd;
    assign bram_we     = do_wr ? s_axi_wstrb : 4'h0;
    assign bram_addr   = do_wr ? {s_axi_awaddr[BRAM_AW-1:2], 2'b00}
                               : {s_axi_araddr[BRAM_AW-1:2], 2'b00};
    assign bram_wrdata = s_axi_wdata;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (do_wr)                           s_axi_bvalid <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
            if (do_rd)                           s_axi_rvalid <= 1'b1;
            else if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
        end
    end
endmodule
