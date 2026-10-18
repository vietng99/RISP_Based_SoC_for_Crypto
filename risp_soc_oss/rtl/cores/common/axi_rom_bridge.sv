// axi_rom_bridge: read-only AXI4 slave on top of the RISSP instruction ROM port.
//
// Cached cores (Rocket, CVA6) fetch code by I-cache line refills over AXI4.
// This bridge serves those reads from the same rom_sync that RISSP fetches
// from (imem_addr out, imem_rdata in, read latency 1), one 32-bit word per
// clock: a DW=32 beat takes 1 cycle, a DW=64 beat takes 2.
// One burst at a time. INCR, FIXED and WRAP bursts. Writes get SLVERR.
module axi_rom_bridge #(
  parameter int unsigned IW = 4,   // AXI ID width
  parameter int unsigned DW = 32   // AXI data width, 32 or 64
) (
  input  logic          clk,
  input  logic          rst_n,
  // ROM port (same as the RISSP CPU imem port)
  output logic [31:0]   imem_addr,
  input  logic [31:0]   imem_rdata,
  // AXI4 slave, read
  input  logic [IW-1:0] ar_id,
  input  logic [31:0]   ar_addr,
  input  logic [7:0]    ar_len,
  input  logic [2:0]    ar_size,
  input  logic [1:0]    ar_burst,
  input  logic          ar_valid,
  output logic          ar_ready,
  output logic [IW-1:0] r_id,
  output logic [DW-1:0] r_data,
  output logic [1:0]    r_resp,
  output logic          r_last,
  output logic          r_valid,
  input  logic          r_ready,
  // AXI4 slave, write (refused)
  input  logic [IW-1:0] aw_id,
  input  logic          aw_valid,
  output logic          aw_ready,
  input  logic          w_last,
  input  logic          w_valid,
  output logic          w_ready,
  output logic [IW-1:0] b_id,
  output logic [1:0]    b_resp,
  output logic          b_valid,
  input  logic          b_ready
);
  localparam int unsigned WPB = DW / 32;          // ROM words per beat
  localparam int unsigned BB  = DW / 8;           // bytes per beat

  // ---------------- read ----------------
  // The ROM returns the word presented on imem_addr one cycle later and keeps
  // returning it while the address is held. rd_word is the beat word that is
  // on imem_rdata this cycle (valid when have = 1). A beat is valid while its
  // last word is on imem_rdata, so DW=32 runs one beat per cycle after the
  // first, DW=64 one beat per two cycles.
  logic          busy;          // a burst is in progress
  logic          have;          // imem_rdata holds word rd_word of the current beat
  logic [31:0]   beat_addr;     // address of the current beat
  logic [7:0]    beats_left;    // beats after the current one
  logic [1:0]    burst;
  logic [7:0]    len;
  logic [IW-1:0] id;
  logic [$clog2(WPB+1)-1:0] rd_word;
  logic [DW-1:0] acc;           // lower words of a wide beat

  wire ar_fire  = ar_valid && ar_ready;
  wire last_wd  = have && (rd_word == WPB - 1);
  assign r_valid = busy && last_wd;
  wire r_fire   = r_valid && r_ready;

  // next beat address (INCR / WRAP / FIXED)
  logic [31:0] next_addr, wrap_mask;
  always_comb begin
    wrap_mask = ((32'(len) + 32'd1) * BB) - 32'd1;
    case (burst)
      2'b00:   next_addr = beat_addr;
      2'b10:   next_addr = (beat_addr & ~wrap_mask) | ((beat_addr + BB) & wrap_mask);
      default: next_addr = beat_addr + BB;
    endcase
  end

  wire [31:0] beat_base = beat_addr & ~(BB - 1);
  always_comb begin
    if (ar_fire)
      imem_addr = ar_addr & ~(BB - 1);
    else if (r_fire && beats_left != 0)
      imem_addr = next_addr & ~(BB - 1);
    else if (have && !last_wd)
      imem_addr = beat_base + (32'(rd_word) + 32'd1) * 4;
    else
      imem_addr = beat_base + 32'(rd_word) * 4;   // hold
  end

  generate if (WPB == 1) begin : g_w32
    assign r_data = imem_rdata;
  end else begin : g_wide
    assign r_data = {imem_rdata, acc[DW-33:0]};
  end endgenerate

  assign ar_ready = !busy;
  assign r_id     = id;
  assign r_resp   = 2'b00;
  assign r_last   = (beats_left == 0);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0; have <= 1'b0; beat_addr <= '0; beats_left <= '0;
      burst <= 2'b01; len <= '0; id <= '0; rd_word <= '0; acc <= '0;
    end else if (ar_fire) begin
      busy <= 1'b1; have <= 1'b1; rd_word <= '0;
      beat_addr <= ar_addr; beats_left <= ar_len; burst <= ar_burst; len <= ar_len; id <= ar_id;
    end else if (r_fire) begin
      rd_word <= '0;
      if (beats_left == 0) begin
        busy <= 1'b0; have <= 1'b0;
      end else begin
        beat_addr <= next_addr; beats_left <= beats_left - 8'd1;
      end
    end else if (have && !last_wd) begin
      acc[32'(rd_word) * 32 +: 32] <= imem_rdata;
      rd_word <= rd_word + 1'b1;
    end
  end

  // ---------------- write: accept and answer SLVERR ----------------
  logic          aw_got, w_got;
  logic [IW-1:0] wid;
  assign aw_ready = !aw_got && !b_valid;
  assign w_ready  = !w_got && !b_valid;
  assign b_id     = wid;
  assign b_resp   = 2'b10;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_got <= 1'b0; w_got <= 1'b0; wid <= '0; b_valid <= 1'b0;
    end else begin
      if (aw_valid && aw_ready) begin aw_got <= 1'b1; wid <= aw_id; end
      if (w_valid && w_ready && w_last) w_got <= 1'b1;
      if (aw_got && w_got && !b_valid) begin b_valid <= 1'b1; aw_got <= 1'b0; w_got <= 1'b0; end
      if (b_valid && b_ready) b_valid <= 1'b0;
    end
  end
endmodule
