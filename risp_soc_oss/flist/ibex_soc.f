// Ibex SoC (design_1, Ibex_SoC project) open-source RTL. Needs RISP_OSS and RISP_IP (= RISP/ip_repo).
// Same as flist/rissp_soc.f except the CPU sources and the top (rtl/soc/design_1_ibex.sv).
+incdir+${RISP_IP}/cpu_ibex/ip_repo/src
${RISP_OSS}/rtl/patched_ibex/xilinx_clkbuf_models.v   // BUFGCE/BUFHCE models (no unisim in Verilator)
${RISP_IP}/cpu_ibex/ip_repo/src/ibex_axi_top_combined.sv
-f ${RISP_OSS}/flist/axil_xbar.f
${RISP_IP}/acc_aes/src/AESEncrypt.v
${RISP_IP}/acc_aes/src/AddRoundKey.v
${RISP_IP}/acc_aes/src/KeyExpansionRound.v
${RISP_IP}/acc_aes/src/MixColumns.v
${RISP_IP}/acc_aes/src/ShiftRows.v
${RISP_IP}/acc_aes/src/SubBytes.v
${RISP_IP}/acc_aes/src/SubTable.v
${RISP_IP}/acc_aes/src/aes_axi_slave.v
${RISP_IP}/acc_aes/src/aes_wrapper.v
${RISP_IP}/acc_sha3/hdl/SHA3_hardware_new.v
${RISP_IP}/acc_sha3/hdl/SHA3_hardware_new_slave_lite_v1_0_S01_AXI.v
${RISP_IP}/acc_sha3/src/F_permutation.v
${RISP_IP}/acc_sha3/src/Keccak.v
${RISP_IP}/acc_sha3/src/Padder.v
${RISP_IP}/acc_sha3/src/Padder1.v
${RISP_IP}/acc_sha3/src/rconst2in1.v
${RISP_IP}/acc_sha3/src/round2in1.v
${RISP_IP}/acc_rsa/hdl/RSA_mark03.v
${RISP_IP}/acc_rsa/hdl/RSA_mark03_slave_lite_v1_0_S00_AXI.v   // PA1-R, installed 2026-10-14 (t-012)
${RISP_OSS}/rtl/patched/RSA_core.v   // = ip_repo/acc_rsa/src/RSA_core.v except the t[] clear line (Verilator form)
${RISP_OSS}/rtl/soc/clk_rst.v
${RISP_OSS}/rtl/soc/ip_wrappers.v
${RISP_OSS}/rtl/mem/rom_sync.v
${RISP_OSS}/rtl/mem/ram_sp_be.v
${RISP_OSS}/rtl/mem/axil_bram_ctrl.v
${RISP_OSS}/rtl/periph/axil_uartlite.v
${RISP_OSS}/rtl/soc/design_1_ibex.sv
