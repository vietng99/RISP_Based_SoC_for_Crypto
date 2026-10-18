# RV32I SoC, open-source flow. Standalone: run from risp_soc_oss as
#   make -f mk/rv32i.mk lint | tbs | run-all | run-tb_rv32i_<name> | run-tb_rv32i_rsa2048_fast
# Top: rtl/soc/design_1_rv32i.sv, sources: flist/rv32i_soc.f.
RISP_OSS  := $(abspath .)
VERILATOR ?= verilator
RISP_ROOT ?= $(abspath ..)
RISP_IP   := $(RISP_ROOT)/ip_repo
VIV_TB    := $(RISP_ROOT)/hardware/testbench/rv32i
FW_DIR    := $(RISP_ROOT)/hardware/firmware
B         := build/rv32i
export RISP_OSS RISP_IP

.PHONY: lint tbs run-all run-tb_rv32i_rsa2048_fast
.SECONDARY:

# tb_rv32i_<x> runs the firmware named in its header (<x>.coe, AES ones are aes_<x>).
TBS := tb_rv32i_ecb tb_rv32i_cbc tb_rv32i_cfb tb_rv32i_ctr tb_rv32i_sha3 tb_rv32i_sha3_4 \
       tb_rv32i_sha3_16 tb_rv32i_rsa2048 tb_rv32i_ecb_dbg
fw_tb_rv32i_ecb     := aes_ecb
fw_tb_rv32i_ecb_dbg := aes_ecb
fw_tb_rv32i_cbc     := aes_cbc
fw_tb_rv32i_cfb     := aes_cfb
fw_tb_rv32i_ctr     := aes_ctr
fw_tb_rv32i_sha3    := sha3
fw_tb_rv32i_sha3_4  := sha3_4
fw_tb_rv32i_sha3_16 := sha3_16
fw_tb_rv32i_rsa2048 := rsa2048

SOC_VFLAGS := --binary --timing -j 8 -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
              --timescale 1ns/1ps

lint:
	mkdir -p logs
	$(VERILATOR) --lint-only -Wall -Wno-fatal --timescale 1ns/1ps --top-module design_1_wrapper \
	  -f flist/rv32i_soc.f > logs/rv32i-lint.log 2>&1; \
	  echo "lint exit $$?, %Error lines: $$(grep -c '%Error' logs/rv32i-lint.log)"

# Testbench copy with the one Verilator clock-force change (tools/adapt_tb.py, shared with RISSP).
$(B)/tb/%.v: $(VIV_TB)/%.v tools/adapt_tb.py
	mkdir -p $(B)/tb
	python3 tools/adapt_tb.py $< $@
	diff -u $< $@ > $(B)/tb/$*.diff || true

$(B)/soc/%/sim: $(B)/tb/%.v flist/rv32i_soc.f rtl/soc/design_1_rv32i.sv $(wildcard rtl/*/*.v)
	mkdir -p $(B)/soc logs
	$(VERILATOR) $(SOC_VFLAGS) --top-module $* -f flist/rv32i_soc.f $< -Mdir $(B)/soc/$* -o sim \
	  > logs/rv32i-build-$*.log 2>&1

tbs: $(addprefix $(B)/soc/,$(addsuffix /sim,$(TBS)))
	cat $(B)/tb/*.diff > logs/rv32i-tb-adapt.diff

run-%: $(B)/soc/%/sim
	mkdir -p logs
	./$(B)/soc/$*/sim +FIRMWARE=$(FW_DIR)/$(fw_$*).hex > logs/rv32i-run-$*.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/rv32i-run-$*.log | head -1 | sed 's/^/$*: /'

# [t-014] RSA-2048 with CTRL = 0x3 (fast flow); RISP/hardware/firmware/rsa2048_fast.hex (main Makefile builds it).

run-tb_rv32i_rsa2048_fast: $(B)/soc/tb_rv32i_rsa2048/sim
	./$(B)/soc/tb_rv32i_rsa2048/sim +FIRMWARE=$(RISP_OSS)/../RISP_SoC_6projects/RISP/hardware/firmware/rsa2048_fast.hex \
	  > logs/rv32i-run-tb_rv32i_rsa2048_fast.log 2>&1 || true
	@grep -E '==> \[(PASS|FAIL)\]|TIMEOUT' logs/rv32i-run-tb_rv32i_rsa2048_fast.log | head -1 | sed 's/^/tb_rv32i_rsa2048_fast: /'

run-all: $(addprefix run-,$(TBS)) run-tb_rv32i_rsa2048_fast
	python3 tools/summary_rv32i.py $(TBS) tb_rv32i_rsa2048_fast > logs/summary-rv32i.txt
	cat logs/summary-rv32i.txt
