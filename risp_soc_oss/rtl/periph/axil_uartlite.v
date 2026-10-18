`timescale 1ns / 1ps
// Minimal AXI4-Lite UART with the Xilinx AXI UART Lite register map (PG142),
// 8N1, one-entry TX and RX buffers instead of 16-deep FIFOs.
//   0x0 RX  (RO)  received byte, pops the RX buffer
//   0x4 TX  (WO)  byte to send
//   0x8 STAT(RO)  [0] rx valid  [1] rx full  [2] tx empty  [3] tx full  [5] rx overrun
//   0xC CTRL(WO)  [0] reset tx  [1] reset rx
// Replaces Vivado axi_uartlite_0 (C_BAUDRATE 9600, ACLK 40 MHz). None of the
// RISSP crypto firmwares touch the UART; it is here so the address map and
// the top-level ports match design_1.
module axil_uartlite #(
    parameter integer CLK_HZ = 40000000,
    parameter integer BAUD   = 9600
) (
    input  wire        clk, rst_n,
    input  wire [3:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [3:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,
    input  wire        rx,
    output wire        tx
);
    localparam integer DIV = CLK_HZ / BAUD;

    wire idle  = !s_axi_bvalid && !s_axi_rvalid;
    wire do_wr = idle && s_axi_awvalid && s_axi_wvalid;
    wire do_rd = idle && !do_wr && s_axi_arvalid;

    assign s_axi_awready = do_wr;
    assign s_axi_wready  = do_wr;
    assign s_axi_arready = do_rd;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_rresp   = 2'b00;

    // ---------------- TX ----------------
    reg [7:0]  tx_buf;   reg tx_full;
    reg [9:0]  tx_sh;    reg [3:0] tx_bits;  reg [31:0] tx_cnt;
    assign tx = (tx_bits == 0) ? 1'b1 : tx_sh[0];

    // ---------------- RX ----------------
    reg [1:0]  rx_sync;
    reg [7:0]  rx_sh;    reg [3:0] rx_bits;  reg [31:0] rx_cnt;
    reg [7:0]  rx_buf;   reg rx_valid;  reg rx_ovr;

    wire wr_tx   = do_wr && s_axi_awaddr[3:2] == 2'd1 && s_axi_wstrb[0];
    wire wr_ctrl = do_wr && s_axi_awaddr[3:2] == 2'd3 && s_axi_wstrb[0];
    wire rd_rx   = do_rd && s_axi_araddr[3:2] == 2'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0; s_axi_rvalid <= 1'b0; s_axi_rdata <= 32'h0;
            tx_buf <= 8'h0; tx_full <= 1'b0; tx_sh <= 10'h3FF; tx_bits <= 4'd0; tx_cnt <= 0;
            rx_sync <= 2'b11; rx_sh <= 8'h0; rx_bits <= 4'd0; rx_cnt <= 0;
            rx_buf <= 8'h0; rx_valid <= 1'b0; rx_ovr <= 1'b0;
        end else begin
            // AXI responses
            if (do_wr) s_axi_bvalid <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
            if (do_rd) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr[3:2])
                    2'd0:    s_axi_rdata <= {24'h0, rx_buf};
                    2'd2:    s_axi_rdata <= {26'h0, rx_ovr, 1'b0, tx_full,
                                             !tx_full && tx_bits == 0, rx_valid, rx_valid};
                    default: s_axi_rdata <= 32'h0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;

            // TX buffer and shifter
            if (wr_tx && !tx_full) begin
                tx_buf <= s_axi_wdata[7:0]; tx_full <= 1'b1;
`ifndef SYNTHESIS
                $write("%c", s_axi_wdata[7:0]);
`endif
            end
            if (tx_bits == 0) begin
                if (tx_full) begin
                    tx_sh <= {1'b1, tx_buf, 1'b0}; tx_bits <= 4'd10; tx_cnt <= DIV - 1;
                    tx_full <= 1'b0;
                end
            end else if (tx_cnt == 0) begin
                tx_sh <= {1'b1, tx_sh[9:1]}; tx_bits <= tx_bits - 1'b1; tx_cnt <= DIV - 1;
            end else tx_cnt <= tx_cnt - 1;

            // RX: sample mid-bit after the start edge
            rx_sync <= {rx_sync[0], rx};
            if (rx_bits == 0) begin
                if (!rx_sync[1]) begin rx_bits <= 4'd10; rx_cnt <= DIV / 2; end
            end else if (rx_cnt == 0) begin
                rx_cnt <= DIV - 1; rx_bits <= rx_bits - 1'b1;
                if (rx_bits == 4'd10 && rx_sync[1]) rx_bits <= 4'd0;     // false start
                else if (rx_bits > 4'd1) rx_sh <= {rx_sync[1], rx_sh[7:1]};
                else begin                                               // stop bit
                    if (rx_valid) rx_ovr <= 1'b1;
                    rx_buf <= rx_sh; rx_valid <= 1'b1;
                end
            end else rx_cnt <= rx_cnt - 1;

            if (rd_rx) rx_valid <= 1'b0;
            if (wr_ctrl && s_axi_wdata[0]) tx_full <= 1'b0;
            if (wr_ctrl && s_axi_wdata[1]) begin rx_valid <= 1'b0; rx_ovr <= 1'b0; end
        end
    end
endmodule
