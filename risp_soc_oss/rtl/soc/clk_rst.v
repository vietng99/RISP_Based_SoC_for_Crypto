`timescale 1ns / 1ps
// Clock and reset blocks standing in for Vivado clk_wiz_0 and proc_sys_reset_0.

// clk_passthru: no PLL. clk_out1 = clk_in1, locked rises one cycle after
// reset drops. On the FPGA board the 100 MHz -> 40 MHz MMCM did this job; in
// simulation the Vivado testbenches force clk_out1 to 40 MHz and locked to 1,
// and in an ASIC flow the clock comes from outside.
module clk_passthru (
    input  wire clk_in1,
    input  wire reset,          // active high
    output wire clk_out1,
    output reg  locked
);
    assign clk_out1 = clk_in1;
    always @(posedge clk_in1 or posedge reset)
        if (reset) locked <= 1'b0;
        else       locked <= 1'b1;
endmodule

// sys_reset: active-high external reset plus PLL lock in, active-low
// peripheral reset out. Assertion is synchronous after a 2-flop synchronizer;
// release waits HOLD cycles after both inputs are clean (proc_sys_reset
// also holds its outputs for a few cycles, so the exact count differs and
// only shifts every testbench cycle stamp by a constant).
module sys_reset #(
    parameter integer HOLD = 16
) (
    input  wire slowest_sync_clk,
    input  wire ext_reset_in,   // active high
    input  wire dcm_locked,
    output reg  peripheral_aresetn
);
    reg [1:0] sync;
    reg [7:0] cnt;
    wire req = ext_reset_in || !dcm_locked;

    always @(posedge slowest_sync_clk) begin
        sync <= {sync[0], req};
        if (sync[1]) begin
            cnt <= 8'd0;
            peripheral_aresetn <= 1'b0;
        end else if (cnt != HOLD[7:0]) begin
            cnt <= cnt + 8'd1;
            peripheral_aresetn <= 1'b0;
        end else begin
            peripheral_aresetn <= 1'b1;
        end
    end

    initial begin
        sync = 2'b11; cnt = 8'd0; peripheral_aresetn = 1'b0;
    end
endmodule
