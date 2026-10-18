// PATCHED COPY of RISP/ip_repo/acc_rsa/hdl/RSA_mark03_slave_lite_v1_0_S00_AXI.v.
// [PA1] CTRL bit1 = fast_pub (public-exponent flow in RSA_core.v, not constant
// time). Writing CTRL = 0x1 runs the original flow; 0x3 runs the fast flow.
// [PA1-R] STATUS bit1 = busy (an operation runs or waits to start). A start
// written while busy is queued (one deep) and runs when the current one ends;
// its operands are taken when it actually starts. STATUS.done is cleared by
// the CTRL start write and set only by the operation that write asked for.
// See patches/RSA_mark03_slave_lite_v1_0_S00_AXI.v.diff.
`timescale 1ns / 1ps
//============================================================================
//  RSA (Montgomery) AXI4-Lite slave  --  ban RONG, ho tro toan hang tuy y
//  (mac dinh RSA-2048).  Thay cho ban cu chi co 5 thanh ghi 32-bit.
//
//  VI SAO PHAI VIET LAI: ban cu dung `reg [31:0] r_m, r_n, r_r2;` - moi toan
//  hang DUNG MOT thanh ghi 32-bit, nen du loi `rsa` ho tro 2048-bit thi
//  wrapper van khoa he thong o 32-bit. Ban nay gom S=WIDTH/32 lan ghi thanh
//  1 thanh ghi rong.
//
//  BAN DO THANH GHI (C_S_AXI_ADDR_WIDTH = 12 -> vung 4 KB):
//    0x000 - 0x0FC   W   M [0..S-1]     tu thap truoc (little-endian theo tu)
//    0x100 - 0x1FC   W   N [0..S-1]
//    0x200 - 0x2FC   W   R2[0..S-1]
//    0x300           W   E              so mu cong khai (65537)
//    0x304           W   N_INV          -N^-1 mod 2^32 (1 tu)
//    0x308           W   CTRL           bit0 = start (xung 1 chu ky)
//                                       bit1 = fast_pub [PA1] (giu toi lan ghi CTRL sau)
//    0x30C           R   STATUS         bit0 = done, bit1 = busy [PA1-R]
//    0x400 - 0x4FC   R   RESULT[0..S-1] C = M^E mod N
//
//  Voi S=64 (2048-bit) thi 0x000-0x0FC la dung 64 tu. Voi WIDTH nho hon,
//  chi cac tu dau duoc dung, phan con lai bo qua - ban do KHONG doi.
//
//  !! LUU Y KHI UPGRADE IP TRONG BLOCK DESIGN:
//     C_S_AXI_ADDR_WIDTH doi 8 -> 12 nen vung dia chi cua IP doi tu 256B
//     thanh 4KB. Sau khi Upgrade IP, MO ADDRESS EDITOR KIEM TRA base van la
//     0x48000000. Neu Vivado tu gan lai base thi firmware se sai het.
//     (Range doi tu 64K xuong 4K la binh thuong, base moi la thu phai giu.)
//
//  !! E_SCAN: so bit cua so mu ma loi quet. Mac dinh 17 cho e=65537.
//     NEU DUNG SO MU KHAC co bit >= 17 thi PHAI tang E_SCAN, neu khong ket
//     qua SAI AM THAM (cac bit cao bi bo qua). Dat E_SCAN=32 la luon dung.
//============================================================================
module RSA_mark03_slave_lite_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12,
    parameter integer RSA_WIDTH          = 2048,   // do rong toan hang
    parameter integer RSA_E_SCAN         = 17,     // 65537 -> 17 bit
    parameter integer RSA_CONST_TIME     = 1
)(
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    input  wire [2 : 0]                        S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [1 : 0]                        S_AXI_BRESP,
    output reg                                 S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    input  wire [2 : 0]                        S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
    output wire [1 : 0]                        S_AXI_RRESP,
    output reg                                 S_AXI_RVALID,
    input  wire                                S_AXI_RREADY
);
    localparam integer S = RSA_WIDTH / 32;      // so tu 32-bit

    //--------------------------------------------------------------
    // AXI handshake
    //--------------------------------------------------------------
    reg aw_received, w_received, ar_received;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg, araddr_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;

    assign S_AXI_AWREADY = ~aw_received;
    assign S_AXI_WREADY  = ~w_received;
    assign S_AXI_ARREADY = ~ar_received;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_RRESP   = 2'b00;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) aw_received <= 1'b0;
        else if (S_AXI_AWVALID && S_AXI_AWREADY) begin aw_received<=1'b1; awaddr_reg<=S_AXI_AWADDR; end
        else if (S_AXI_BVALID && S_AXI_BREADY)   aw_received<=1'b0;
    end
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) w_received <= 1'b0;
        else if (S_AXI_WVALID && S_AXI_WREADY) begin w_received<=1'b1; wdata_reg<=S_AXI_WDATA; end
        else if (S_AXI_BVALID && S_AXI_BREADY) w_received<=1'b0;
    end
    reg write_pulse;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin S_AXI_BVALID<=1'b0; write_pulse<=1'b0; end
        else if (aw_received && w_received && !S_AXI_BVALID) begin S_AXI_BVALID<=1'b1; write_pulse<=1'b1; end
        else begin write_pulse<=1'b0; if (S_AXI_BVALID && S_AXI_BREADY) S_AXI_BVALID<=1'b0; end
    end
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) ar_received <= 1'b0;
        else if (S_AXI_ARVALID && S_AXI_ARREADY) begin ar_received<=1'b1; araddr_reg<=S_AXI_ARADDR; end
        else if (S_AXI_RVALID && S_AXI_RREADY)   ar_received<=1'b0;
    end
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) S_AXI_RVALID <= 1'b0;
        else if (ar_received && !S_AXI_RVALID) S_AXI_RVALID<=1'b1;
        else if (S_AXI_RVALID && S_AXI_RREADY)  S_AXI_RVALID<=1'b0;
    end

    //--------------------------------------------------------------
    // Mang thanh ghi toan hang
    //--------------------------------------------------------------
    reg [31:0] m_arr [0:S-1];
    reg [31:0] n_arr [0:S-1];
    reg [31:0] r2_arr[0:S-1];
    reg [31:0] r_e, r_ninv;
    reg        core_start, core_rst;
    reg        core_fast;            // [PA1] CTRL bit1
    reg        start_pending;        // [PA1-R] start written while busy
    wire       core_busy;
    wire       core_active = core_busy | core_start;

    localparam [3:0] PG_M = 4'h0, PG_N = 4'h1, PG_R2 = 4'h2,
                     PG_CTL = 4'h3, PG_RES = 4'h4;
    localparam [7:0] OFF_E = 8'h00, OFF_NINV = 8'h04,
                     OFF_CTRL = 8'h08, OFF_STATUS = 8'h0C;

    wire [3:0] wpage = awaddr_reg[11:8];
    wire [5:0] widx  = awaddr_reg[7:2];

    integer q;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            r_e<=32'h0; r_ninv<=32'h0;
            core_start<=1'b0; core_rst<=1'b1; core_fast<=1'b0;
            start_pending<=1'b0;
            for (q=0; q<S; q=q+1) begin
                m_arr[q]<=32'h0; n_arr[q]<=32'h0; r2_arr[q]<=32'h0;
            end
        end else begin
            core_start <= 1'b0;      // start la xung 1 chu ky
            core_rst   <= 1'b0;
            // [PA1-R] launch a queued start once the core is idle
            if (start_pending && !core_active) begin
                core_start    <= 1'b1;
                start_pending <= 1'b0;
            end
            if (write_pulse) begin
                case (wpage)
                    PG_M:  if (widx < S) m_arr [widx] <= wdata_reg;
                    PG_N:  if (widx < S) n_arr [widx] <= wdata_reg;
                    PG_R2: if (widx < S) r2_arr[widx] <= wdata_reg;
                    PG_CTL: case (awaddr_reg[7:0])
                                OFF_E:    r_e    <= wdata_reg;
                                OFF_NINV: r_ninv <= wdata_reg;
                                OFF_CTRL: begin
                                    core_fast  <= wdata_reg[1];   // [PA1]
                                    // [PA1-R] start now if idle, else queue it
                                    if (wdata_reg[0]) begin
                                        if (core_active || start_pending)
                                            start_pending <= 1'b1;
                                        else
                                            core_start    <= 1'b1;
                                    end
                                end
                                default:  ;
                            endcase
                    default: ;
                endcase
            end
        end
    end

    //--------------------------------------------------------------
    // Gom mang -> bus rong cho loi
    //--------------------------------------------------------------
    wire [RSA_WIDTH-1:0] m_bus, n_bus, r2_bus;
    genvar g;
    generate
        for (g = 0; g < S; g = g + 1) begin : pack
            assign m_bus [g*32 +: 32] = m_arr [g];
            assign n_bus [g*32 +: 32] = n_arr [g];
            assign r2_bus[g*32 +: 32] = r2_arr[g];
        end
    endgenerate

    wire [RSA_WIDTH-1:0] core_c;
    wire                 core_done;

    rsa #(.WIDTH(RSA_WIDTH), .E_BITS(32),
          .CONST_TIME(RSA_CONST_TIME), .E_SCAN(RSA_E_SCAN)) u_rsa (
        .clk(S_AXI_ACLK), .rst(core_rst), .start(core_start), .fast_pub(core_fast),
        .M(m_bus), .E(r_e), .N(n_bus),
        .N_INV({{(RSA_WIDTH-32){1'b0}}, r_ninv}), .R2_MOD_N(r2_bus),
        .C(core_c), .done(core_done), .busy(core_busy)
    );

    // [PA1-R] busy covers the cycle of core_done too: done_latch is set one
    // cycle after core_done, and STATUS must never read done=0, busy=0 mid-op.
    wire status_busy = core_active | start_pending | core_done;

    // done latch: giu done=1 cho toi khi start moi
    reg done_latch;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) done_latch<=1'b0;
        // [PA1-R] clear on the CTRL start write; ignore the done of an
        // operation that was already running when a new start was queued
        else if (write_pulse && wpage == PG_CTL && awaddr_reg[7:0] == OFF_CTRL
                 && wdata_reg[0])          done_latch<=1'b0;
        else if (core_done && !start_pending) done_latch<=1'b1;
    end

    //--------------------------------------------------------------
    // Doc: STATUS + RESULT theo tung tu
    //--------------------------------------------------------------
    wire [3:0]  rpage = araddr_reg[11:8];
    wire [5:0]  ridx  = araddr_reg[7:2];
    wire [11:0] rbase = {ridx, 5'b00000};        // ridx * 32

    reg [31:0] axi_rdata;
    assign S_AXI_RDATA = axi_rdata;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) axi_rdata <= 32'h0;
        else if (ar_received) begin
            case (rpage)
                PG_CTL: axi_rdata <= (araddr_reg[7:0] == OFF_STATUS)
                                     ? {30'b0, status_busy, done_latch}
                                     : 32'h0;
                PG_RES: axi_rdata <= (ridx < S) ? core_c[rbase +: 32] : 32'h0;
                default: axi_rdata <= 32'h0;
            endcase
        end
    end
endmodule