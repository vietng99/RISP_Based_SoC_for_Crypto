// RISSP SoC (design_1) with the RISSP v2b CPU (per-type instruction blocks) [t-027]. Same as rissp_v2_soc.f except the CPU files.
-f ${RISP_OSS}/flist/axil_xbar.f
${RISP_OSS}/rtl/cores/rissp_v2b/rissp_top.v
${RISP_OSS}/rtl/cores/rissp_v2b/fetch_stage.v
${RISP_OSS}/rtl/cores/rissp_v2b/register_file.v
${RISP_OSS}/rtl/cores/rissp_v2b/modular_ex.v
${RISP_OSS}/rtl/cores/rissp_v2b/alu_adder.v
${RISP_OSS}/rtl/cores/rissp_v2b/u_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/i_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/r_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/s_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/b_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/j_type_block.v
${RISP_OSS}/rtl/cores/rissp_v2b/axi_rissp_master.v
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
${RISP_OSS}/rtl/soc/design_1.sv
