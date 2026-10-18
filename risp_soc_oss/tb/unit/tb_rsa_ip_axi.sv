`timescale 1ns / 1ps
// RSA IP (RSA_mark03 -> RSA_mark03_slave_lite_v1_0_S00_AXI -> rsa) tested alone
// through its AXI4-Lite port at RSA_WIDTH = 2048, RSA_E_SCAN = 17 (as in the
// SoC). Vectors: tools/gen_rsa_ip_vectors.py (expected values from Python pow).
// The AXI master randomizes channel order (AW/W together, AW first, W first)
// and BREADY/RREADY delays. Checks per case: RESULT, STATUS.done, STATUS.busy,
// and the special sequences (CTRL without start, start queued while busy,
// E rewritten while busy).
module tb_rsa_ip_axi;
    localparam int W = 2048, S = W / 32;

    reg clk = 0;
    always #5 clk = ~clk;
    reg aresetn = 0;

    reg  [11:0] awaddr = 0, araddr = 0;
    reg         awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    reg  [31:0] wdata = 0;
    wire        awready, wready, bvalid, arready, rvalid;
    wire [1:0]  bresp, rresp;
    wire [31:0] rdata;

    RSA_mark03 #(.RSA_WIDTH(W), .RSA_E_SCAN(17), .RSA_CONST_TIME(1)) dut (
        .s00_axi_aclk(clk), .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'b000), .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata), .s00_axi_wstrb(4'hF), .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
        .s00_axi_araddr(araddr), .s00_axi_arprot(3'b000), .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata(rdata), .s00_axi_rresp(rresp), .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready)
    );

    integer nfail = 0, guard;

    task automatic fail(input string msg);
        nfail++; $display("FAIL %s", msg);
    endtask

    // ---------------- AXI4-Lite master ----------------
    task automatic axi_write(input [11:0] a, input [31:0] d);
        int order, dly;
        bit aw_done, w_done;
        order = $urandom_range(0, 2);     // 0 together, 1 AW first, 2 W first
        dly   = $urandom_range(0, 2);
        @(negedge clk);
        awaddr = a; wdata = d;
        awvalid = (order != 2); wvalid = (order != 1);
        aw_done = 0; w_done = 0;
        guard = 0;
        while (!(aw_done && w_done)) begin
            @(posedge clk);
            if (awvalid && awready) aw_done = 1;
            if (wvalid && wready)   w_done  = 1;
            @(negedge clk);
            if (aw_done) awvalid = 0;
            if (w_done)  wvalid  = 0;
            if (aw_done && !w_done) wvalid  = 1;
            if (w_done && !aw_done) awvalid = 1;
            guard = guard + 1; if (guard > 100) begin fail("AXI write handshake timeout"); $finish; end
        end
        repeat (dly) @(negedge clk);
        bready = 1;
        guard = 0;
        @(posedge clk);
        while (!bvalid) begin
            @(posedge clk);
            guard = guard + 1; if (guard > 100) begin fail("AXI B timeout"); $finish; end
        end
        if (bresp != 2'b00) fail("BRESP != OKAY");
        @(negedge clk); bready = 0;
    endtask

    task automatic axi_read(input [11:0] a, output [31:0] d);
        int dly;
        dly = $urandom_range(0, 2);
        @(negedge clk);
        araddr = a; arvalid = 1;
        guard = 0;
        @(posedge clk);
        while (!arready) begin
            @(posedge clk);
            guard = guard + 1; if (guard > 100) begin fail("AXI AR timeout"); $finish; end
        end
        @(negedge clk); arvalid = 0;
        repeat (dly) @(negedge clk);
        rready = 1;
        guard = 0;
        @(posedge clk);
        while (!rvalid) begin
            @(posedge clk);
            guard = guard + 1; if (guard > 100) begin fail("AXI R timeout"); $finish; end
        end
        d = rdata;
        if (rresp != 2'b00) fail("RRESP != OKAY");
        @(negedge clk); rready = 0;
    endtask

    // ---------------- register-level helpers ----------------
    task automatic write_wide(input [11:0] base, input [W-1:0] v);
        for (int i = 0; i < S; i++) axi_write(base + 12'(4 * i), v[32*i +: 32]);
    endtask

    task automatic read_status(output bit done_b, output bit busy_b);
        reg [31:0] st;
        axi_read(12'h30C, st);
        done_b = st[0]; busy_b = st[1];
    endtask

    task automatic wait_done(input string tag, output integer polls);
        bit d, b;
        polls = 0;
        d = 0;
        while (!d) begin
            read_status(d, b);
            polls++;
            if (polls > 200000) begin fail({tag, ": done never set"}); $finish; end
            if (!d && !b) begin fail({tag, ": STATUS shows neither done nor busy"}); return; end
        end
        if (b) fail({tag, ": done=1 while busy=1"});
    endtask

    task automatic check_result(input string tag, input [W-1:0] exp);
        reg [31:0] r;
        integer bad = 0;
        for (int i = 0; i < S; i++) begin
            axi_read(12'h400 + 12'(4 * i), r);
            if (r !== exp[32*i +: 32]) bad++;
        end
        if (bad) fail($sformatf("%s: %0d of %0d RESULT words wrong", tag, bad, S));
    endtask

    // ---------------- vectors ----------------
    reg [W-1:0] vec [0:8*64];
    integer ncase, c, polls;
    reg [W-1:0] kc, e, ninv, m, n, r2, m2, exp_v;
    bit d, b;
    string tag;

    initial begin
        string vf;
        if (!$value$plusargs("VEC=%s", vf)) vf = "build/unit/rsa_ip_vec.hex";
        $readmemh(vf, vec);
        ncase = vec[0];
        repeat (5) @(negedge clk);
        aresetn = 1;
        repeat (3) @(negedge clk);

        read_status(d, b);
        if (d || b) fail("STATUS after reset is not 0");

        for (c = 0; c < ncase; c++) begin
            {kc, e, ninv, m, n, r2, m2, exp_v} = {vec[1+8*c], vec[2+8*c], vec[3+8*c], vec[4+8*c],
                                                  vec[5+8*c], vec[6+8*c], vec[7+8*c], vec[8+8*c]};
            tag = $sformatf("case %0d kind %0d CTRL=0x%0h E=%h", c, kc[11:8], kc[3:0], e[31:0]);
            write_wide(12'h000, m);
            write_wide(12'h100, n);
            write_wide(12'h200, r2);
            axi_write(12'h300, e[31:0]);
            axi_write(12'h304, ninv[31:0]);
            case (kc[11:8])
            1: begin                                        // CTRL without start
                axi_write(12'h308, kc[31:0]);
                repeat (20) @(negedge clk);
                read_status(d, b);
                if (!d || b) fail({tag, ": CTRL=0x2 changed STATUS"});
            end
            2: begin                                        // queued second start
                axi_write(12'h308, kc[31:0]);
                read_status(d, b);
                if (!b || d) fail({tag, ": first op not busy"});
                write_wide(12'h000, m2);                     // new M while busy
                axi_write(12'h308, kc[31:0]);                // queued
                wait_done(tag, polls);
            end
            3: begin                                        // E rewrite while busy
                axi_write(12'h308, kc[31:0]);
                read_status(d, b);
                if (!b) fail({tag, ": not busy after start"});
                axi_write(12'h300, m2[31:0]);
                wait_done(tag, polls);
            end
            default: begin
                axi_write(12'h308, kc[31:0]);
                read_status(d, b);
                if (d) fail({tag, ": done still 1 right after start"});
                wait_done(tag, polls);
            end
            endcase
            check_result(tag, exp_v);
            $display("%s  polls %0d  failures so far %0d", tag, polls, nfail);
        end

        if (nfail == 0)
            $display("==> [PASS] tb_rsa_ip_axi: %0d cases, RESULT/STATUS all correct", ncase);
        else
            $display("==> [FAIL] tb_rsa_ip_axi: %0d failures", nfail);
        $finish;
    end
endmodule
