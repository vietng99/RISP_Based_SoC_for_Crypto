`timescale 1ns / 1ps
// PA1 unit test of module `rsa` (rtl/patched/RSA_core.v) at a small WIDTH.
// Every vector from tools/gen_rsa_vectors.py runs twice: fast_pub = 0 (the
// original constant-time flow, E_SCAN = 32 so every E is scanned) and
// fast_pub = 1 (PA1). Both must equal pow(M, E, N). The number of
// Montgomery multiplications is counted exactly (entries into ST_CLR) and
// checked: 67 for the original flow (2*E_SCAN + 3); for PA1 2 when E = 1,
// otherwise 2 + L + popcount(E[L-1:1]) with L = top set bit of E (18 for
// e = 65537); E = 0 must run the original flow.
module tb_rsa_core_pa1 #(parameter int W = 256);
    localparam int MAXV = 6 * 1024;

    reg clk = 0;
    always #5 clk = ~clk;

    reg          rst = 1, start = 0, fast = 0;
    reg  [W-1:0] M, N, R2, NINV, E;
    wire [W-1:0] C;
    wire         done, busy;

    rsa #(.WIDTH(W), .E_BITS(32), .CONST_TIME(1), .E_SCAN(32)) dut (
        .clk(clk), .rst(rst), .start(start), .fast_pub(fast),
        .M(M), .E(E[31:0]), .N(N), .N_INV(NINV), .R2_MOD_N(R2),
        .C(C), .done(done), .busy(busy)
    );

    reg [W-1:0] vec [0:MAXV];             // vec[0] = number of cases
    integer i, nfail = 0, npass = 0, ncase = 0, ntotal;

    // MonMul counter: each Montgomery multiplication starts in ST_CLR (4'd1)
    integer n_clr = 0;
    always @(posedge clk) if (!rst && dut.st == 4'd1) n_clr <= n_clr + 1;

    // one run: returns cycles from start to done
    task automatic run(input bit f, output integer cycles, output integer mm);
        integer c0;
        @(negedge clk);
        c0 = n_clr;
        if (busy) begin nfail++; $display("FAIL busy=1 before start, case %0d", ncase); end
        fast = f; start = 1;
        @(negedge clk);
        start = 0;
        if (!busy) begin nfail++; $display("FAIL busy=0 after start, case %0d", ncase); end
        cycles = 1;
        while (!done) begin
            @(posedge clk); #1;
            cycles = cycles + 1;
            if (cycles > 2_000_000) begin
                $display("TIMEOUT case %0d fast=%0d", ncase, f);
                $finish;
            end
        end
        @(negedge clk);
        mm = n_clr - c0;
        if (busy) begin nfail++; $display("FAIL busy=1 after done, case %0d", ncase); end
    endtask

    function automatic integer popcount(input [31:0] x);
        integer b; popcount = 0;
        for (b = 0; b < 32; b++) popcount += x[b];
    endfunction

    function automatic integer topbit(input [31:0] x);
        integer b; topbit = -1;
        for (b = 0; b < 32; b++) if (x[b]) topbit = b;
    endfunction

    integer c_slow, c_fast, m_slow, m_fast, exp_mm, L;

    initial begin
        begin
            string vf;
            if (!$value$plusargs("VEC=%s", vf)) vf = "build/unit/rsa_vec.hex";
            $readmemh(vf, vec);
        end
        ntotal = vec[0];
        repeat (3) @(negedge clk);
        rst = 0;

        for (i = 1; ncase < ntotal; i += 6) begin
            M = vec[i]; N = vec[i+1]; R2 = vec[i+2]; NINV = vec[i+3]; E = vec[i+4];

            run(0, c_slow, m_slow);
            if (C !== vec[i+5]) begin
                nfail++; $display("FAIL case %0d fast=0 E=%h", ncase, E[31:0]);
            end else npass++;

            run(1, c_fast, m_fast);
            if (C !== vec[i+5]) begin
                nfail++; $display("FAIL case %0d fast=1 E=%h", ncase, E[31:0]);
            end else npass++;

            L = topbit(E[31:0]);
            if (E[31:0] == 0)  exp_mm = 67;
            else if (L == 0)   exp_mm = 2;
            else               exp_mm = 2 + L + popcount(E[31:0] & ((32'h1 << L) - 2));
            if (m_slow != 67) begin
                nfail++; $display("FAIL count case %0d fast=0: %0d MonMul, expected 67", ncase, m_slow);
            end
            if (m_fast != exp_mm) begin
                nfail++; $display("FAIL count case %0d E=%h fast=1: %0d MonMul, expected %0d",
                                  ncase, E[31:0], m_fast, exp_mm);
            end
            if (ncase < 12)
                $display("case %0d E=%h  original %0d MonMul %0d cyc | fast %0d MonMul %0d cyc",
                         ncase, E[31:0], m_slow, c_slow, m_fast, c_fast);
            ncase++;
        end

        if (ncase > 0 && nfail == 0)
            $display("==> [PASS] tb_rsa_core_pa1 W=%0d: %0d cases x 2 flows, %0d results OK", W, ncase, npass);
        else
            $display("==> [FAIL] tb_rsa_core_pa1 W=%0d: %0d cases, %0d failures", W, ncase, nfail);
        $finish;
    end
endmodule
