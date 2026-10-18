# Ibex SoC (RISP/hardware/projects/Ibex_SoC), open-source flow (no Vivado IP).
# Standalone: run from risp_soc_oss as `make -f mk/ibex.mk <target>`.
#   lint      Verilator -Wall lint of design_1_wrapper (Ibex top)
#   tbs       build one simulator per Ibex testbench
#   run-all   run every testbench, write logs/ibex-run-<tb>.log and logs/summary-ibex.txt
#   run-tb_ibex_rsa2048_fast   tb_ibex_rsa2048 with RISP/hardware/firmware/rsa2048_fast.hex (CTRL = 0x3)
RISP_OSS  := $(abspath .)
VERILATOR ?= verilator
RISP_ROOT ?= $(abspath ..)
RISP_IP   := $(RISP_ROOT)/ip_repo
VIV_TB    := $(RISP_ROOT)/hardware/testbench/ibex
FW_DIR    := $(RISP_ROOT)/hardware/firmware
export RISP_OSS RISP_IP

# tb_ibex_<name> runs firmware <name>.hex; the AES testbenches use aes_<mode>.hex.
TBS := tb_ibex_ecb tb_ibex_cbc tb_ibex_cfb tb_ibex_ctr tb_ibex_sha3 tb_ibex_sha3_4 tb_ibex_sha3_16 tb_ibex_rsa2048
fw_of = $(FW_DIR)/$(patsubst ecb,aes_ecb,$(patsubst cbc,aes_cbc,$(patsubst cfb,aes_cfb,$(patsubst ctr,aes_ctr,$(patsubst tb_ibex_%,%,$(1)))))).hex

SOC_VFLAGS := --binary --timing -j 8 -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
              --timescale 1ns/1ps
B := build/ibex

.PHONY: lint tbs run-all run-tb_ibex_rsa2048_fast
.SECONDARY:

lint:
	mkdir -p logs
	$(VERILATOR) --lint-only -Wall -Wno-fatal --timescale 1ns/1ps --top-module design_1_wrapper \
	  -f flist/ibex_soc.f > logs/ibex-lint.log 2>&1; grep -c '%Error' logs/ibex-lint.log || true

# Testbench copy with the one Verilator change (tools/adapt_tb.py, same as RISSP).
$(B)/tb/%.v: $(VIV_TB)/%.v tools/adapt_tb.py
	mkdir -p $(B)/tb logs
	python3 tools/adapt_tb.py $< $@
	diff -u $< $@ > $(B)/tb/$*.diff || true

$(B)/soc/%/sim: $(B)/tb/%.v flist/ibex_soc.f rtl/soc/design_1_ibex.sv $(wildcard rtl/*/*.v rtl/*/*.sv)
	mkdir -p $(B)/soc logs
	$(VERILATOR) $(SOC_VFLAGS) --top-module $* -f flist/ibex_soc.f $< -Mdir $(B)/soc/$* -o sim \
	  > logs/ibex-build-$*.log 2>&1 || (tail -30 logs/ibex-build-$*.log; exit 1)

tbs: $(addprefix $(B)/soc/,$(addsuffix /sim,$(TBS)))

run-%: $(B)/soc/%/sim
	./$(B)/soc/$*/sim +FIRMWARE=$(call fw_of,$*) > logs/ibex-run-$*.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/ibex-run-$*.log | head -1 | sed 's/^/$*: /'

run-tb_ibex_rsa2048_fast: $(B)/soc/tb_ibex_rsa2048/sim
	./$(B)/soc/tb_ibex_rsa2048/sim +FIRMWARE=$(RISP_OSS)/../RISP_SoC_6projects/RISP/hardware/firmware/rsa2048_fast.hex > logs/ibex-run-tb_ibex_rsa2048_fast.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/ibex-run-tb_ibex_rsa2048_fast.log | head -1 | sed 's/^/tb_ibex_rsa2048_fast: /'

run-all: $(addprefix run-,$(TBS)) run-tb_ibex_rsa2048_fast
	cat $(B)/tb/*.diff > logs/ibex-tb-adapt.diff
	# tools/summary.py reads logs/run-<tb>.log; same code, pointed at logs/ibex-run-<tb>.log
	sed -e 's|f"run-{tb}.log"|f"ibex-run-{tb}.log"|' -e 's|^LOGS = .*|LOGS = Path("logs")|' tools/summary.py \
	  | python3 - $(TBS) tb_ibex_rsa2048_fast > logs/summary-ibex.txt
	cat logs/summary-ibex.txt
