`timescale 1ns / 1ps
// AXI4-Lite master for one load or store at a time.
// - The request leaves in the cycle the instruction is decoded: AWVALID/WVALID/ARVALID
//   come from mem_write/mem_read, the address and data come straight from the
//   execute stage. No address or data registers.
// - A store retires once AW and W are both accepted (in any order). Its B response
//   is waited for only by the next load or store, which keeps the order of accesses.
// - A load retires in the cycle RVALID arrives; RDATA goes straight to the register file.
// - AXI rules kept: a VALID never depends on the READY of its own channel; once raised
//   it stays high with stable address/data until its handshake (the core is held and
//   the ROM re-reads the same instruction); all VALIDs are low in reset.
module axi_rissp_master (
    input         clk, rst_n,
    input         mem_read, mem_write,
    input  [31:0] mem_addr, mem_wdata,
    output [31:0] load_data,
    output        stall,
    output [31:0] m_axi_awaddr, output [2:0] m_axi_awprot, output m_axi_awvalid, input m_axi_awready,
    output [31:0] m_axi_wdata, output [3:0] m_axi_wstrb, output m_axi_wvalid, input m_axi_wready,
    input  [1:0]  m_axi_bresp, input m_axi_bvalid, output m_axi_bready,
    output [31:0] m_axi_araddr, output [2:0] m_axi_arprot, output m_axi_arvalid, input m_axi_arready,
    input  [31:0] m_axi_rdata, input [1:0] m_axi_rresp, input m_axi_rvalid, output m_axi_rready
);
    reg aw_done, w_done, ar_done;  // this access: channel already handshaken
    reg b_pend;                    // a store's B response is still outstanding

    wire b_busy = b_pend & ~m_axi_bvalid;
    wire go     = rst_n & ~b_busy;

    assign m_axi_awvalid = mem_write & go & ~aw_done;
    assign m_axi_wvalid  = mem_write & go & ~w_done;
    assign m_axi_arvalid = mem_read  & go & ~ar_done;

    wire aw_ok      = aw_done | (m_axi_awvalid & m_axi_awready);
    wire w_ok       = w_done  | (m_axi_wvalid  & m_axi_wready);
    wire store_done = mem_write & go & aw_ok & w_ok;
    wire store_wait = mem_write & ~store_done;
    wire load_wait  = mem_read  & ~m_axi_rvalid;

    assign stall     = store_wait | load_wait;
    assign load_data = m_axi_rdata;

    assign m_axi_awaddr = mem_addr;
    assign m_axi_araddr = mem_addr;
    assign m_axi_wdata  = mem_wdata;
    assign m_axi_wstrb  = 4'hF;      // only word stores (SW)
    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;
    assign m_axi_bready = 1'b1;
    assign m_axi_rready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done <= 1'b0;
            w_done  <= 1'b0;
            ar_done <= 1'b0;
            b_pend  <= 1'b0;
        end else begin
            aw_done <= store_wait & aw_ok;
            w_done  <= store_wait & w_ok;
            ar_done <= load_wait & (ar_done | (m_axi_arvalid & m_axi_arready));
            b_pend  <= b_busy | store_done;
        end
    end
endmodule
