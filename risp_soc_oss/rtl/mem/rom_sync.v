`timescale 1ns / 1ps
// Single-port synchronous ROM, read latency 1, always enabled.
// Replaces Vivado blk_mem_gen_0 (Single_Port_ROM, Write_Depth_A 8192,
// no output register, Fill_Remaining_Memory_Locations = 0).
//
// Contents: INIT_FILE (hex, one 32-bit word per line) at elaboration.
// In simulation the plusarg +FIRMWARE=<file.hex> overrides it, so one
// simulator binary runs every firmware.
module rom_sync #(
    parameter integer DEPTH     = 8192,
    parameter integer AW        = 13,
    parameter         INIT_FILE = ""
) (
    input  wire          clka,
    input  wire [AW-1:0] addra,
    output reg  [31:0]   douta
);
    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0;
        douta = 32'h0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
`ifndef SYNTHESIS
        begin : plusarg_load
            reg [8*512-1:0] fw;
            if ($value$plusargs("FIRMWARE=%s", fw)) begin
                for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0;
                $readmemh(fw, mem);
                $display("[rom_sync] %m loaded %0s", fw);
            end
        end
`endif
    end

    always @(posedge clka) douta <= mem[addra];
endmodule
