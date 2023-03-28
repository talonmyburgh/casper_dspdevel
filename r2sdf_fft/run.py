from vunit import VUnit
from os.path import join, abspath, split

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()
vu.add_random()

script_dir,_ = split(abspath(__file__))
# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_file(join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_file(join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# XPM Multiplier library
ip_xpm_mult_lib = vu.add_library("ip_xpm_mult_lib", allow_duplicate=True)
ip_cmult_3dsp = ip_xpm_mult_lib.add_source_file(join(script_dir, "../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd"))
ip_cmult_4dsp = ip_xpm_mult_lib.add_source_file(join(script_dir, "../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd"))

# STRATIXIV Multiplier library
ip_stratixiv_mult_lib = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
ip_stratixiv_complex_mult_rtl = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult_rtl.vhd"))
ip_stratixiv_complex_mult = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult.vhd"))
ip_stratixiv_complex_mult.add_dependency_on(altera_mf_source_file)

# XPM RAM library
ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

# COMMON COMPONENTS Library 
common_components_lib = vu.add_library("common_components_lib")
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_bit_delay.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline_sl.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_delay.vhd"))

# COMMON PACKAGE Library
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_str_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/tb_common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_lfsr_sequences_pkg.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# COMMON COUNTER Library
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_file(join(script_dir, "../casper_counter/common_counter.vhd"))

# CASPER MUlTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib")
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))
tech_complex_mult = casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_complex_mult.vhd"))
tech_complex_mult.add_dependency_on(ip_cmult_3dsp)
tech_complex_mult.add_dependency_on(ip_cmult_4dsp)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult_rtl)

# CASPER REQUANTIZE Library
casper_requantize_lib = vu.add_library("casper_requantize_lib")
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_round.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_resize.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_requantize.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/r_shift_requantize.vhd"))

# CASPER RAM Library
casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# RTWOSDF Library
# Pathline for twid coefficients
twid_path_stem = script_dir + '/data/twids/sdf_twiddle_coeffs'
print(twid_path_stem)

r2sdf_fft_lib = vu.add_library("r2sdf_fft_lib")
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoBF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoBFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"twiddlesPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDFPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoWeights.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoWMul.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_rTwoSDF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_rTwoSDF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_vu_twiddlepkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_vu_rtwosdf_vfmodel.vhd"))
# Setup the Twiddle Testbench by calling it's python function
from r2sdf_fft_py import tb_twiddle_package_setup
tb_twiddle_package_setup(r2sdf_fft_lib)
from r2sdf_fft_py import tb_vu_trwosdf_vfmodel_setup
tb_vu_trwosdf_vfmodel_setup(r2sdf_fft_lib)

TB_GENERATED = r2sdf_fft_lib.test_bench("tb_tb_vu_rTwoSDF")
TB_GENERATED.add_config(
    name = "u_act_impulse_16p_16i_16o",
    generics=dict(g_use_uniNoise_file = False,g_in_en = 1,g_use_reorder = True,g_nof_points = 16,g_in_dat_w = 16,g_out_dat_w = 16,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_act_noise_1024p_8i_14o",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 1,g_use_reorder = True,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_rnd_noise_1024p_8i_14o",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 0,g_use_reorder = True,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_rnd_noise_1024p_8i_14o_flipped",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 0,g_use_reorder = False,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
# Don't optimize in Modelsim/Questa GUI mode
vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])
vu.main()
