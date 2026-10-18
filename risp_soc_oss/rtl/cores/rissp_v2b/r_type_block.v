`timescale 1ns / 1ps
// R-type block: XOR. rd = rs1 ^ rs2.
module r_type_block (
    input  [31:0] rs1_data, rs2_data,
    output [31:0] rd_data
);
    assign rd_data = rs1_data ^ rs2_data;
endmodule
