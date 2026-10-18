# RISSP SoC, open-source flow (no Vivado IP).
RISP_OSS  := $(abspath .)
VERILATOR ?= verilator
export RISP_OSS

VFLAGS := --binary --timing -j 8 -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT

.PHONY: fw-check lint-xbar test-xbar lint-soc soc-tbs run-all clean test-rsa-pa1 test-rsa-ip

# Vivado RISSP sources (read-only) and the open-source SoC on top of them.
RISP_ROOT ?= $(abspath ..)
RISP_IP   := $(RISP_ROOT)/ip_repo
VIV_TB    := $(RISP_ROOT)/hardware/testbench/rissp
FW_DIR    := $(RISP_ROOT)/hardware/firmware
export RISP_IP

# Every RISSP testbench; tb_<name> runs firmware <name>.hex.
TBS := tb_aes_ecb tb_aes_cbc tb_aes_cfb tb_aes_ctr tb_sha3 tb_sha3_4 tb_sha3_16 tb_rsa tb_rsa2048
SOC_VFLAGS := --binary --timing -j 8 -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
              --timescale 1ns/1ps

lint-xbar:
	$(VERILATOR) --lint-only -Wall -Wno-fatal --top-module axil_xbar_flat -f flist/axil_xbar.f \
	  -GM_BASE="160'h40600000_C0000000_48000000_44000000_40000000" \
	  -GM_END="160'h40610000_C0002000_48010000_44010000_40004000"

test-xbar:
	mkdir -p build/unit
	$(VERILATOR) $(VFLAGS) --top-module tb_axil_xbar_flat -f flist/axil_xbar.f \
	  tb/unit/tb_axil_xbar_flat.sv -Mdir build/unit/xbar -o sim
	./build/unit/xbar/sim

lint-soc:
	$(VERILATOR) --lint-only -Wall -Wno-fatal --timescale 1ns/1ps --top-module design_1_wrapper \
	  -f flist/rissp_soc.f

# Keep the generated testbench copies (make would delete them as intermediates).
.SECONDARY:

# Testbench copy with the one Verilator change (see tools/adapt_tb.py).
build/tb/%.v: $(VIV_TB)/%.v tools/adapt_tb.py
	mkdir -p build/tb
	python3 tools/adapt_tb.py $< $@
	diff -u $< $@ > build/tb/$*.diff || true

build/soc/%/sim: build/tb/%.v flist/rissp_soc.f $(wildcard rtl/*/*.v rtl/*/*.sv)
	mkdir -p build/soc
	$(VERILATOR) $(SOC_VFLAGS) --top-module $* -f flist/rissp_soc.f $< -Mdir build/soc/$* -o sim

soc-tbs: $(addprefix build/soc/,$(addsuffix /sim,$(TBS)))

# One run: make run-tb_sha3. Log in logs/run-<tb>.log.
run-%: build/soc/%/sim
	mkdir -p logs
	./build/soc/$*/sim +FIRMWARE=$(FW_DIR)/$(patsubst tb_%,%,$*).hex > logs/run-$*.log 2>&1
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/run-$*.log | head -1 | sed 's/^/$*: /'

# [t-014] RSA-2048 fast firmware (CTRL = 0x3), source next to rsa2048.s in
# RISP/hardware/firmware, built with the chipyard toolchain (tools/build_fw.py).
FAST_FW := $(FW_DIR)/rsa2048_fast.hex
$(FW_DIR)/rsa2048_fast.s: $(FW_DIR)/rsa2048.s tools/gen_rsa2048_fast_s.py
	python3 tools/gen_rsa2048_fast_s.py $< $@
$(FAST_FW): $(FW_DIR)/rsa2048_fast.s tools/build_fw.py
	python3 tools/build_fw.py $(FW_DIR) $<

# Rebuild every firmware .s with the chipyard toolchain and compare with the shipped .hex/.coe.
fw-check: tools/build_fw.py
	python3 tools/build_fw.py build/fw-chipyard $(wildcard $(FW_DIR)/*.s)
	@for s in $(wildcard $(FW_DIR)/*.s); do n=$$(basename $$s .s); \
	  cmp -s build/fw-chipyard/$$n.hex $(FW_DIR)/$$n.hex && cmp -s build/fw-chipyard/$$n.coe $(FW_DIR)/$$n.coe \
	  && echo "$$n: same" || { echo "$$n: DIFFERENT"; exit 1; }; done

run-tb_rsa2048_fast: build/soc/tb_rsa2048/sim $(FAST_FW)
	mkdir -p logs
	./build/soc/tb_rsa2048/sim +FIRMWARE=$(FAST_FW) > logs/run-tb_rsa2048_fast.log 2>&1
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/run-tb_rsa2048_fast.log | head -1 | sed 's/^/tb_rsa2048_fast: /'

run-all: $(addprefix run-,$(TBS))
	python3 tools/summary.py $(TBS) > logs/summary.txt
	cat logs/summary.txt

# [PA1] unit test of the rsa core at WIDTH 32, 64 and 256 against Python pow()
RSA_UT_WIDTHS := 32 64 256
test-rsa-pa1: tools/gen_rsa_vectors.py tb/unit/tb_rsa_core_pa1.sv rtl/patched/RSA_core.v
	mkdir -p build/unit logs
	rm -f logs/test-rsa-pa1.log
	for w in $(RSA_UT_WIDTHS); do \
	  python3 tools/gen_rsa_vectors.py build/unit/rsa_vec_$$w.hex $$w && \
	  $(VERILATOR) $(VFLAGS) --top-module tb_rsa_core_pa1 -GW=$$w rtl/patched/RSA_core.v \
	    tb/unit/tb_rsa_core_pa1.sv -Mdir build/unit/rsa_pa1_$$w -o sim > build/unit/rsa_pa1_$$w.build.log 2>&1 && \
	  ./build/unit/rsa_pa1_$$w/sim +VEC=build/unit/rsa_vec_$$w.hex >> logs/test-rsa-pa1.log 2>&1 || exit 1; \
	done
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/test-rsa-pa1.log

# [PA1] RSA IP alone (RSA_mark03, 2048-bit) through its AXI4-Lite port.
# SEEDS: random AXI timing seeds; XRAND=1 also randomizes initial register state.
RSA_IP_SEEDS ?= 1 2 3
RSA_IP_SRC := $(RISP_IP)/acc_rsa/hdl/RSA_mark03.v rtl/patched/RSA_mark03_slave_lite_v1_0_S00_AXI.v \
              rtl/patched/RSA_core.v tb/unit/tb_rsa_ip_axi.sv
test-rsa-ip: tools/gen_rsa_ip_vectors.py $(RSA_IP_SRC)
	mkdir -p build/unit logs
	python3 tools/gen_rsa_ip_vectors.py build/unit/rsa_ip_vec.hex
	$(VERILATOR) $(VFLAGS) -O3 --x-assign unique --x-initial unique --top-module tb_rsa_ip_axi \
	  $(RSA_IP_SRC) -Mdir build/unit/rsa_ip -o sim > build/unit/rsa_ip.build.log 2>&1
	rm -f logs/test-rsa-ip.log
	for s in $(RSA_IP_SEEDS); do \
	  echo "--- seed $$s" >> logs/test-rsa-ip.log; \
	  ./build/unit/rsa_ip/sim +verilator+seed+$$s +verilator+rand+reset+2 \
	    +VEC=build/unit/rsa_ip_vec.hex >> logs/test-rsa-ip.log 2>&1 || exit 1; \
	done
	@grep -E '^--- seed|==> \[(PASS|FAIL)\]' logs/test-rsa-ip.log

clean:
	rm -rf build
