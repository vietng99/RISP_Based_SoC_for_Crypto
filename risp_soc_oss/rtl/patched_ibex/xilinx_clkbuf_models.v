`timescale 1ns / 1ps
// Simulation stand-ins for the two Xilinx clock buffers that the Ibex IP's
// prim_clock_gating (ip_repo/cpu_ibex/ip_repo/src/ibex_axi_top_combined.sv,
// FPGA flavour) instantiates. Vivado takes them from unisim; Verilator has no
// unisim library. The Ibex RTL itself is not modified.
//
// O follows I directly (no gating). A gated copy of the clock (I & latched CE)
// is a derived clock in Verilator: flops on it sample signals that flops on I
// already updated in the same time step, so the core sees bus responses one
// cycle early and the Ibex SoC hangs. The only gate in this SoC is ibex_top's
// core_clock_gate_i (CE = core_busy | irq | debug), which turns the clock off
// only while the core sleeps (WFI). The monitor below counts rising edges of I
// with CE = 0 after reset; if that count is not 0 at the end of a simulation,
// the pass-through differs from the hardware and the run says so.
module BUFGCE #(
    parameter SIM_DEVICE = "7SERIES",
    parameter CE_TYPE = "SYNC",
    parameter [0:0] IS_CE_INVERTED = 1'b0,
    parameter [0:0] IS_I_INVERTED = 1'b0
) (
    input  wire I,
    input  wire CE,
    output wire O
);
    assign O = I;
`ifndef SYNTHESIS
    integer gated_edges = 0;
    integer seen_ce = 0;
    always @(posedge I) begin
        if (CE) seen_ce = 1;
        else if (seen_ce != 0) gated_edges = gated_edges + 1;
    end
    final begin
        if (gated_edges != 0)
            $display("[BUFGCE model] %m: %0d clock edges with CE=0 after the core started (hardware would gate them)", gated_edges);
        else
            $display("[BUFGCE model] %m: CE stayed 1 after the core started (pass-through = hardware)");
    end
`endif
endmodule

module BUFHCE #(
    parameter CE_TYPE = "SYNC",
    parameter [0:0] INIT_OUT = 1'b0
) (
    input  wire I,
    input  wire CE,
    output wire O
);
    assign O = I;
endmodule
