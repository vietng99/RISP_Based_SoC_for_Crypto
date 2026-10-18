// PATCHED COPY of RISP/ip_repo/acc_rsa/src/RSA_core.v.
// Changes are marked [risp_soc_oss patch] / [PA1]; see patches/RSA_core.v.diff.
//   [risp_soc_oss patch] whole-array clear of t[] (Verilator 5.022).
//   [PA1] fast_pub input: public-exponent flow, 18 MonMul for e = 65537
//         (design: risp_soc_oss/RSA_PA1_DESIGN.md). fast_pub = 0 runs the
//         original flow cycle for cycle.
`timescale 1ns / 1ps
//============================================================================
//  RSA Montgomery core (module `rsa`)
//  Instantiated by the AXI wrapper RSA_mark03_slave_lite_v1_0_S00_AXI.v
//  (RSA_mark03_1_0/hdl/), base address 0x48000000 in the SoC.
//
//  Word-serial Montgomery multiplication (CIOS, Koc et al. 1996). A single
//  WORD x WORD multiply-accumulate unit is reused, so the number of DSPs does
//  not grow with WIDTH; only the operand storage grows linearly.
//
//  CIOS, one Montgomery multiplication:
//     for i in 0..S-1:
//        C=0; for j in 0..S-1: (C,St)=t[j]+a[j]*b[i]+C ; t[j]=St
//        (C,St)=t[S]+C ; t[S]=St ; t[S+1]=C
//        m = t[0]*N_INV mod 2^WORD
//        (C,St)=t[0]+m*n[0]                    // low word is 0 by construction
//        for j in 1..S-1: (C,St)=t[j]+m*n[j]+C ; t[j-1]=St
//        (C,St)=t[S]+C ; t[S-1]=St ; t[S]=t[S+1]+C
//     then subtract N if t >= N.
//
//  Cost ~ 2*S^2 + 6*S + 8 cycles per Montgomery multiplication (S = WIDTH/WORD)
//  Multiplications per exponentiation:
//     CONST_TIME=1 : 2*E_SCAN + 3      (E_SCAN=17 -> 37)
//     CONST_TIME=0 : E_SCAN + popcount(E) + 3
//
//  [PA1] fast_pub=1 (and E != 0), any E, NOT constant time - public
//  exponents only:  A = MonMul(M,R2) = M*R ; res = A
//     for i = L-1 downto 1: res = MonMul(res,res); if E[i]: res = MonMul(res,A)
//     res = MonMul(res,res); C = E[0] ? MonMul(res,M) : MonMul(res,1)
//  L = index of the top set bit of E. MonMul count: 2 + L + popcount(E[L-1:1])
//  (2 when E = 1)
//  (e = 65537 -> 18). The last multiply uses plain M, so the factor R
//  cancels and no separate conversion out of Montgomery form is needed
//  (same as OpenTitan sigverify mod_exp_ibex.c). E = 0 runs the original flow.
//
//  [PA1-R] E is latched at start (e_r), so writing E while an operation
//  runs no longer changes that operation. busy = 1 from the cycle after
//  start until done.
//
//  CONST_TIME=1 always performs the multiplication and only commits the
//  result conditionally, so the run time does not depend on the exponent.
//  E_SCAN is the number of exponent bits scanned (17 for e = 65537).
//
//  Parameter conventions:
//     N_INV    = -N^-1 mod 2^WORD   (only the low WORD bits are used)
//     R2_MOD_N = 2^(2*WIDTH) mod N
//     Both are precomputed offline (Python); firmware writes them as constants.
//
//  WIDTH must be a multiple of WORD (32). For WIDTH > 32 the AXI wrapper
//  assembles WIDTH/32 register writes into each wide port (M/N/R2_MOD_N).
//============================================================================
module rsa #(
    parameter WIDTH      = 32,          // do rong toan hang (bit), chia het WORD
    parameter E_BITS     = 32,          // do rong cong E (giu 32 cho drop-in)
    parameter CONST_TIME = 1,           // 1 = thoi gian bat bien theo so mu
    parameter WORD       = 32,          // do rong duong du lieu MAC
    parameter E_SCAN     = E_BITS,      // so bit cua E thuc su quet (65537 -> 17)
    parameter S          = WIDTH / WORD // so tu - KHONG truyen khi instantiate
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    input  wire              fast_pub,  // [PA1] 1 = public-exponent flow (not constant time)
    input  wire [WIDTH-1:0]  M,
    input  wire [E_BITS-1:0] E,
    input  wire [WIDTH-1:0]  N,
    input  wire [WIDTH-1:0]  N_INV,     // chi N_INV[WORD-1:0] duoc dung
    input  wire [WIDTH-1:0]  R2_MOD_N,
    output reg  [WIDTH-1:0]  C,
    output reg               done,
    output wire              busy       // [PA1-R] 1 while an operation runs
);
    //------------------------------------------------------------------
    // Bo nho toan hang (cat tu cong rong luc start)
    //------------------------------------------------------------------
    reg [WORD-1:0] m_in [0:S-1];
    reg [WORD-1:0] nw   [0:S-1];
    reg [WORD-1:0] r2   [0:S-1];
    reg [WORD-1:0] mbar [0:S-1];
    reg [WORD-1:0] res  [0:S-1];
    reg [WORD-1:0] tmpv [0:S-1];
    reg [WORD-1:0] t    [0:S+1];
    reg [WORD-1:0] sb   [0:S-1];

    integer k;

    //------------------------------------------------------------------
    // Chon nguon toan hang: 0=res 1=mbar 2=tmpv 3=hang so 1 4=m_in 5=r2
    //------------------------------------------------------------------
    localparam AW = (S <= 2) ? 1 : $clog2(S);
    reg [2:0]  sel_a, sel_b;
    reg [AW:0] jj, ii;

    function [WORD-1:0] rd_src;
        input [2:0]  s_;
        input [AW:0] idx;
        begin
            case (s_)
                3'd0: rd_src = res [idx[AW-1:0]];
                3'd1: rd_src = mbar[idx[AW-1:0]];
                3'd2: rd_src = tmpv[idx[AW-1:0]];
                3'd3: rd_src = (idx == 0) ? {{(WORD-1){1'b0}}, 1'b1} : {WORD{1'b0}};
                3'd4: rd_src = m_in[idx[AW-1:0]];
                3'd5: rd_src = r2  [idx[AW-1:0]];
                default: rd_src = {WORD{1'b0}};
            endcase
        end
    endfunction

    //------------------------------------------------------------------
    // MAC dung chung: {carry,sum} = x + y*z + carry
    //   (2^W-1)^2 + 2*(2^W-1) = 2^2W - 1 -> vua khit 2W bit, khong tran.
    //------------------------------------------------------------------
    reg  [WORD-1:0]   mac_y, mac_z, mac_x, carry;
    wire [2*WORD-1:0] mac = mac_y * mac_z + {{WORD{1'b0}}, mac_x}
                                          + {{WORD{1'b0}}, carry};

    reg [WORD-1:0] mword, b_i, n0inv_r;
    reg            borrow, t_ge_n;

    //------------------------------------------------------------------
    localparam ST_IDLE  = 4'd0,  ST_CLR   = 4'd1,  ST_L1    = 4'd2,
               ST_L1E   = 4'd3,  ST_M     = 4'd4,  ST_L2F   = 4'd5,
               ST_L2    = 4'd6,  ST_L2E   = 4'd7,  ST_NEXT  = 4'd8,
               ST_SUB   = 4'd9,  ST_CMP   = 4'd10, ST_WR    = 4'd11,
               ST_CPY   = 4'd12, ST_EXP_A = 4'd13, ST_EXP_B = 4'd14,
               ST_MSB   = 4'd15;                   // [PA1] find top set bit of E

    reg [3:0] st;
    reg [5:0] ebit_idx;
    reg       ebit;
    reg [2:0] phase;    // 0=convM 1=convR 2=square 3=mult 4=final
    reg       fast_r;   // [PA1] latched fast_pub && E != 0
    reg [E_BITS-1:0] e_r;   // [PA1-R] E latched at start

    assign busy = (st != ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            st <= ST_IDLE; done <= 1'b0; C <= {WIDTH{1'b0}};
            carry <= 0; ii <= 0; jj <= 0; phase <= 0;
            ebit_idx <= 0; borrow <= 0; ebit <= 0; fast_r <= 1'b0;
        end else begin
            done <= 1'b0;

            case (st)
            //---------------------------------------------------------
            ST_IDLE: if (start) begin
                for (k = 0; k < S; k = k + 1) begin
                    m_in[k] <= M       [k*WORD +: WORD];
                    nw  [k] <= N       [k*WORD +: WORD];
                    r2  [k] <= R2_MOD_N[k*WORD +: WORD];
                end
                n0inv_r  <= N_INV[WORD-1:0];
                phase    <= 3'd0;
                sel_a    <= 3'd4;  sel_b <= 3'd5;      // MonMul(M, R2)
                // [PA1] fast flow scans E from bit E_BITS-1 down in ST_MSB
                fast_r   <= fast_pub && (E != {E_BITS{1'b0}});
                e_r      <= E;                         // [PA1-R]
                if (fast_pub && (E != {E_BITS{1'b0}})) begin
                    ebit_idx <= E_BITS[5:0] - 6'd1;
                    st       <= ST_MSB;
                end else begin
                    ebit_idx <= E_SCAN[5:0] - 6'd1;
                    st       <= ST_CLR;
                end
            end

            // [PA1] stop at the top set bit (E != 0 here, so this ends)
            ST_MSB: begin
                if (e_r[ebit_idx]) st <= ST_CLR;
                else             ebit_idx <= ebit_idx - 6'd1;
            end

            //------------------- CIOS -------------------------------
            ST_CLR: begin
                // [risp_soc_oss patch] whole-array clear; same effect as the original
                // for-loop of NBAs, which Verilator 5.022 rejects (BLKLOOPINIT).
                for (k = 0; k <= S+1; k = k + 1) t[k] <= {WORD{1'b0}};  // synth copy: original loop
                ii <= 0; jj <= 0; carry <= 0;
                b_i   <= rd_src(sel_b, 0);
                mac_y <= rd_src(sel_a, 0);
                mac_z <= rd_src(sel_b, 0);
                mac_x <= {WORD{1'b0}};
                st    <= ST_L1;
            end

            ST_L1: begin                       // t[j] = t[j] + a[j]*b_i + C
                t[jj] <= mac[WORD-1:0];
                carry <= mac[2*WORD-1:WORD];
                if (jj == S-1) begin
                    jj    <= 0;
                    mac_y <= {WORD{1'b0}};
                    mac_z <= {WORD{1'b0}};
                    mac_x <= t[S];
                    st    <= ST_L1E;
                end else begin
                    jj    <= jj + 1;
                    mac_y <= rd_src(sel_a, jj + 1);
                    mac_z <= b_i;
                    mac_x <= t[jj + 1];
                end
            end

            ST_L1E: begin
                t[S]   <= mac[WORD-1:0];
                t[S+1] <= mac[2*WORD-1:WORD];
                carry  <= {WORD{1'b0}};
                mac_y  <= t[0];                // t[0] da cap nhat trong ST_L1
                mac_z  <= n0inv_r;
                mac_x  <= {WORD{1'b0}};
                st     <= ST_M;
            end

            ST_M: begin                        // m = t[0]*N_INV mod 2^WORD
                mword <= mac[WORD-1:0];
                mac_y <= mac[WORD-1:0];
                mac_z <= nw[0];
                mac_x <= t[0];
                carry <= {WORD{1'b0}};
                st    <= ST_L2F;
            end

            ST_L2F: begin                      // j=0: chi giu carry
                carry <= mac[2*WORD-1:WORD];
                jj    <= 1;
                mac_y <= mword;
                mac_z <= (S > 1) ? nw[1] : {WORD{1'b0}};
                mac_x <= (S > 1) ? t [1] : t[S];
                st    <= (S == 1) ? ST_L2E : ST_L2;
            end

            ST_L2: begin                       // t[j-1] = t[j] + m*n[j] + C
                t[jj-1] <= mac[WORD-1:0];
                carry   <= mac[2*WORD-1:WORD];
                if (jj == S-1) begin
                    mac_y <= {WORD{1'b0}};
                    mac_z <= {WORD{1'b0}};
                    mac_x <= t[S];
                    st    <= ST_L2E;
                end else begin
                    jj    <= jj + 1;
                    mac_y <= mword;
                    mac_z <= nw[jj+1];
                    mac_x <= t [jj+1];
                end
            end

            ST_L2E: begin
                t[S-1] <= mac[WORD-1:0];
                t[S]   <= t[S+1] + mac[2*WORD-1:WORD];
                carry  <= {WORD{1'b0}};
                st     <= ST_NEXT;
            end

            ST_NEXT: begin
                if (ii == S-1) begin
                    jj <= 0; borrow <= 1'b0; st <= ST_SUB;
                end else begin
                    ii    <= ii + 1;
                    jj    <= 0;
                    carry <= {WORD{1'b0}};
                    b_i   <= rd_src(sel_b, ii + 1);
                    mac_y <= rd_src(sel_a, 0);
                    mac_z <= rd_src(sel_b, ii + 1);
                    mac_x <= t[0];
                    st    <= ST_L1;
                end
            end

            ST_SUB: begin                      // sb = t - N (tu thap len)
                {borrow, sb[jj]} <= {1'b0, t[jj]} - {1'b0, nw[jj]}
                                                 - {{WORD{1'b0}}, borrow};
                if (jj == S-1) begin jj <= 0; st <= ST_CMP; end
                else jj <= jj + 1;
            end

            ST_CMP: begin                      // t >= N ?
                t_ge_n <= (t[S] != {WORD{1'b0}}) || !borrow;
                jj <= 0;
                st <= ST_WR;
            end

            ST_WR: begin
                tmpv[jj] <= t_ge_n ? sb[jj] : t[jj];
                if (jj == S-1) begin jj <= 0; st <= ST_CPY; end
                else jj <= jj + 1;
            end

            //--------------- copy tmpv -> dich ----------------------
            ST_CPY: begin
                case (phase)
                    3'd0: begin                                  // M_bar
                        mbar[jj] <= tmpv[jj];
                        if (fast_r) res[jj] <= tmpv[jj];         // [PA1] res = M*R
                    end
                    3'd1: res [jj] <= tmpv[jj];                  // res = R mod N
                    3'd2: res [jj] <= tmpv[jj];                  // binh phuong
                    3'd3: res [jj] <= ebit ? tmpv[jj] : res[jj]; // nhan (co dk)
                    default: res[jj] <= tmpv[jj];                // ra khoi Montgomery
                endcase
                if (jj == S-1) begin jj <= 0; st <= ST_EXP_A; end
                else jj <= jj + 1;
            end

            //--------------- dieu khien luy thua --------------------
            ST_EXP_A: if (fast_r) begin
                // [PA1] public-exponent flow; ebit_idx = bit handled by this square
                case (phase)
                3'd0: begin                                  // res = M*R, ebit_idx = L
                    if (ebit_idx == 0) begin                 // E = 1
                        phase <= 3'd4;
                        sel_a <= 3'd0; sel_b <= 3'd3;        // MonMul(res, 1)
                    end else begin
                        ebit_idx <= ebit_idx - 6'd1;
                        ebit     <= e_r[ebit_idx - 6'd1];
                        phase    <= 3'd2;
                        sel_a <= 3'd0; sel_b <= 3'd0;        // MonMul(res,res)
                    end
                    st <= ST_CLR;
                end
                3'd2: begin                                  // squared for bit ebit_idx
                    if (ebit_idx == 0) begin
                        phase <= 3'd4;
                        sel_a <= 3'd0;
                        sel_b <= ebit ? 3'd4 : 3'd3;         // MonMul(res, M) / MonMul(res, 1)
                        st    <= ST_CLR;
                    end else if (ebit) begin
                        phase <= 3'd3;
                        sel_a <= 3'd0; sel_b <= 3'd1;        // MonMul(res,M_bar)
                        st    <= ST_CLR;
                    end else st <= ST_EXP_B;
                end
                3'd3: st <= ST_EXP_B;
                default: begin                               // phase 4: done
                    for (k = 0; k < S; k = k + 1)
                        C[k*WORD +: WORD] <= res[k];
                    done <= 1'b1;
                    st   <= ST_IDLE;
                end
                endcase
            end else begin
                case (phase)
                3'd0: begin                                  // xong conv M
                    phase <= 3'd1;
                    sel_a <= 3'd3; sel_b <= 3'd5;            // MonMul(1, R2)
                    st    <= ST_CLR;
                end
                3'd1: begin                                  // xong conv R
                    phase <= 3'd2;
                    ebit  <= e_r[ebit_idx];
                    sel_a <= 3'd0; sel_b <= 3'd0;            // MonMul(res,res)
                    st    <= ST_CLR;
                end
                3'd2: begin                                  // xong binh phuong
                    if (CONST_TIME != 0 || ebit) begin
                        phase <= 3'd3;
                        sel_a <= 3'd0; sel_b <= 3'd1;        // MonMul(res,M_bar)
                        st    <= ST_CLR;
                    end else st <= ST_EXP_B;
                end
                3'd3: st <= ST_EXP_B;
                default: begin                               // xong tat ca
                    for (k = 0; k < S; k = k + 1)
                        C[k*WORD +: WORD] <= res[k];
                    done <= 1'b1;
                    st   <= ST_IDLE;
                end
                endcase
            end

            ST_EXP_B: begin
                // [PA1] fast flow never gets here with ebit_idx == 0 (bit 0 ends in ST_EXP_A)
                if (ebit_idx == 0) begin
                    phase <= 3'd4;
                    sel_a <= 3'd0; sel_b <= 3'd3;            // MonMul(res, 1)
                    st    <= ST_CLR;
                end else begin
                    ebit_idx <= ebit_idx - 6'd1;
                    ebit     <= e_r[ebit_idx - 6'd1];
                    phase    <= 3'd2;
                    sel_a <= 3'd0; sel_b <= 3'd0;
                    st    <= ST_CLR;
                end
            end

            default: st <= ST_IDLE;
            endcase
        end
    end
endmodule
