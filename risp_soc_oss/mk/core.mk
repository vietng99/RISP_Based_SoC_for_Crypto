# RISSP SoC with another CPU in place of rissp_top (CORE_SWAP_DESIGN.md).
# design_1.sv, the RISSP testbenches (build/tb, same copies as RISSP) and the
# firmware are the RISSP ones; only flist/$(CORE)_soc.f differs.
# Standalone: run from risp_soc_oss as `make -f mk/core.mk CORE=<rocket|cva6> <target>`.
#   lint      Verilator lint of design_1_wrapper
#   tbs       build one simulator per RISSP testbench
#   run-all   run every testbench + rsa2048_fast, write logs/<core>-run-<tb>.log and logs/summary-<core>.txt
CORE      ?= cva6
RISP_OSS  := $(abspath .)
VERILATOR ?= verilator
RISP_ROOT ?= $(abspath ..)
RISP_IP   := $(RISP_ROOT)/ip_repo
VIV_TB    := $(RISP_ROOT)/hardware/testbench/rissp
FW_DIR    := $(RISP_ROOT)/hardware/firmware
export RISP_OSS RISP_IP

TBS := tb_aes_ecb tb_aes_cbc tb_aes_cfb tb_aes_ctr tb_sha3 tb_sha3_4 tb_sha3_16 tb_rsa tb_rsa2048
SOC_VFLAGS := --binary --timing -j 8 -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD -Wno-MULTITOP \
              --timescale 1ns/1ps
FLIST := flist/$(CORE)_soc.f
# Rocket prints a commit trace on every instruction unless PRINTF_COND is 0 (assertions stay on).
ifeq ($(CORE),rocket)
SOC_VFLAGS += +define+PRINTF_COND=0
endif
B := build/$(CORE)

.PHONY: lint tbs run-all run-tb_rsa2048_fast
.SECONDARY:

lint:
	mkdir -p logs
	$(VERILATOR) --lint-only -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD -Wno-MULTITOP --timescale 1ns/1ps \
	  --top-module design_1_wrapper -f $(FLIST) > logs/$(CORE)-lint.log 2>&1; grep -c '%Error' logs/$(CORE)-lint.log || true

# Same testbench copy as the RISSP build (tools/adapt_tb.py).
build/tb/%.v: $(VIV_TB)/%.v tools/adapt_tb.py
	mkdir -p build/tb
	python3 tools/adapt_tb.py $< $@
	diff -u $< $@ > build/tb/$*.diff || true

$(B)/soc/%/sim: build/tb/%.v $(FLIST) rtl/soc/design_1.sv $(wildcard rtl/*/*.v rtl/*/*.sv rtl/cores/*/*.sv rtl/cores/*/*.v)
	mkdir -p $(B)/soc logs
	$(VERILATOR) $(SOC_VFLAGS) --top-module $* -f $(FLIST) $< -Mdir $(B)/soc/$* -o sim \
	  > logs/$(CORE)-build-$*.log 2>&1 || (tail -30 logs/$(CORE)-build-$*.log; exit 1)

tbs: $(addprefix $(B)/soc/,$(addsuffix /sim,$(TBS)))

run-%: $(B)/soc/%/sim
	./$(B)/soc/$*/sim +FIRMWARE=$(FW_DIR)/$(patsubst tb_%,%,$*).hex > logs/$(CORE)-run-$*.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/$(CORE)-run-$*.log | head -1 | sed 's/^/$*: /'

run-tb_rsa2048_fast: $(B)/soc/tb_rsa2048/sim
	./$(B)/soc/tb_rsa2048/sim +FIRMWARE=$(FW_DIR)/rsa2048_fast.hex > logs/$(CORE)-run-tb_rsa2048_fast.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/$(CORE)-run-tb_rsa2048_fast.log | head -1 | sed 's/^/tb_rsa2048_fast: /'

run-all: $(addprefix run-,$(TBS)) run-tb_rsa2048_fast
	# tools/summary.py reads logs/run-<tb>.log; same code, pointed at logs/<core>-run-<tb>.log
	sed -e 's|f"run-{tb}.log"|f"$(CORE)-run-{tb}.log"|' -e 's|^LOGS = .*|LOGS = Path("logs")|' tools/summary.py \
	  | python3 - $(TBS) tb_rsa2048_fast > logs/summary-$(CORE).txt
	cat logs/summary-$(CORE).txt
