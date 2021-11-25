from vunit import VUnit
from os.path import join, dirname

# script_dir = dirname(__file__)
script_dir = dirname(__file__)

#gather arguments specifying which tests to run:
# test_to_run = sys.argv[1]

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
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
ip_mult_infer = ip_xpm_mult_lib.add_source_file(join(script_dir, "../ip_xpm/mult/ip_mult_infer.vhd"))

# STRATIXIV Multiplier library
ip_stratixiv_mult_lib = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
ip_stratixiv_complex_mult_rtl = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult_rtl.vhd"))
ip_stratixiv_complex_mult = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult.vhd"))
ip_stratixiv_mult = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_mult_rtl.vhd"))
ip_stratixiv_mult_rtl = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_mult.vhd"))
ip_stratixiv_complex_mult.add_dependency_on(altera_mf_source_file)
ip_stratixiv_mult.add_dependency_on(altera_mf_source_file)

# XPM RAM library
ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
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
common_components_lib.add_source_files(join(script_dir, "../common_components/common_paged_reg.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_switch.vhd"))

# COMMON PACKAGE Library
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_str_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/tb_common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_lfsr_sequences_pkg.vhd"))

# DP PACKAGE Library
dp_pkg_lib = vu.add_library("dp_pkg_lib")
dp_pkg_lib.add_source_file(join(script_dir,"../casper_dp_pkg/dp_stream_pkg.vhd"))

# DP COMPONENTS Library
dp_components_lib = vu.add_library("dp_components_lib")
dp_components_lib.add_source_file(join(script_dir,"../casper_dp_components/dp_hold_input.vhd"))
dp_components_lib.add_source_file(join(script_dir,"../casper_dp_components/dp_hold_ctrl.vhd"))
dp_components_lib.add_source_file(join(script_dir,"../casper_dp_components/dp_block_gen.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# COMMON COUNTER Library
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_file(join(script_dir, "../casper_counter/common_counter.vhd"))

# CASPER ADDER Library
casper_adder_lib = vu.add_library("casper_adder_lib")
casper_adder_lib.add_source_file(join(script_dir,"../casper_adder/common_add_sub.vhd"))
casper_adder_lib.add_source_file(join(script_dir,"../casper_adder/common_adder_tree.vhd"))
casper_adder_lib.add_source_file(join(script_dir,"../casper_adder/common_adder_tree_a_str.vhd"))

# CASPER MUlTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib")
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))
tech_complex_mult = casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_mult.vhd"))
tech_complex_mult.add_dependency_on(ip_cmult_3dsp)
tech_complex_mult.add_dependency_on(ip_cmult_4dsp)
tech_complex_mult.add_dependency_on(ip_mult_infer)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult_rtl)

# CASPER MULTIPLEXER Library
casper_multiplexer_lib = vu.add_library("casper_multiplexer_lib")
casper_multiplexer_lib.add_source_files(join(script_dir, "../casper_multiplexer/common_multiplexer.vhd"))
casper_multiplexer_lib.add_source_files(join(script_dir, "../casper_multiplexer/common_zip.vhd"))
casper_multiplexer_lib.add_source_files(join(script_dir, "../casper_multiplexer/common_demultiplexer.vhd"))

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
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# CASPER FILTER Library
casper_filter_lib = vu.add_library("casper_filter_lib")
casper_filter_lib.add_source_file(join(script_dir,"../casper_filter/fil_pkg.vhd"))
casper_filter_lib.add_source_file(join(script_dir,"../casper_filter/fil_ppf_ctrl.vhd"))
casper_filter_lib.add_source_file(join(script_dir,"../casper_filter/fil_ppf_filter.vhd"))
casper_filter_lib.add_source_file(join(script_dir,"../casper_filter/fil_ppf_single.vhd"))
casper_filter_lib.add_source_file(join(script_dir,"../casper_filter/fil_ppf_wide.vhd"))

# CASPER MEM Library
casper_mm_lib = vu.add_library("casper_mm_lib")
casper_mm_lib.add_source_file(join(script_dir,"../casper_mm/tb_common_mem_pkg.vhd"))

# CASPER SIM TOOLS Library
casper_sim_tools_lib =vu.add_library("casper_sim_tools_lib")
casper_sim_tools_lib.add_source_file(join(script_dir,"../casper_sim_tools/common_wideband_data_scope.vhd"))

# RTWOSDF Library
r2sdf_fft_lib = vu.add_library("r2sdf_fft_lib")
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoBF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoBFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/twiddlesPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoSDFPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoWeights.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoWMul.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoSDFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"../r2sdf_fft/rTwoSDF.vhd"))

# WIDEBAND FFT Library
wb_fft_lib = vu.add_library("wb_fft_lib")
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_sepa.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_gnrcs_intrfcs_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/tb_fft_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_reorder_sepa_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_r2_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_r2_bf_par.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"../casper_wb_fft/fft_r2_par.vhd"))

# WIDEBAND PFB Library
wbpfb_lib = vu.add_library("wbpfb_lib")
wbpfb_lib.add_source_file(join(script_dir,"wbpfb_gnrcs_intrfcs_pkg.vhd"))
wbpfb_lib.add_source_file(join(script_dir,"dp_bsn_restore_global.vhd"))
wbpfb_lib.add_source_file(join(script_dir,"dp_block_gen_valid_arr.vhd"))
wbpfb_lib.add_source_file(join(script_dir,"wbpfb_unit_dev.vhd"))
wbpfb_lib.add_source_file(join(script_dir,"tb_wbpfb_unit_wide.vhd"))
wbpfb_lib.add_source_file(join(script_dir,"tb_tb_vu_wbpfb_unit_wide.vhd"))

# CONSTANTS FOR TESTS
c_stage_dat_extra_w = 28
c_pre_ab              = "../../../../../data/mem/hex/run_pfb_m_pfir_coeff_fircls1_16taps_32points_16b"                 
c_pre_ab_1024         = "../../../../../data/mem/hex/run_pfb_m_pfir_coeff_fircls1_16taps_1024points_16b"                 
c_pre_ab_v2           = "../../../../../data/mem/hex/run_pfb_m_v2_pfir_coeff_fircls1_16taps_1024points_16b"              
c_pre_c               = "../../../../../data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_32points_16b"
c_pre_c_64            = "../../../../../data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_64points_16b"
c_pre_c_1024          = "../../../../../data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_1024points_16b"
  
c_sinusoid_chirp_1024 = "../../../../../data/run_pfb_m_sinusoid_chirp_8b_16taps_1024points_16b.dat"   
c_sinusoid_chirp      = "../../../../../data/run_pfb_m_sinusoid_chirp_8b_16taps_32points_16b.dat"     
c_sinusoid_1024       = "../../../../../data/run_pfb_m_sinusoid_8b_16taps_1024points_16b.dat"         
c_sinusoid_1024_v2    = "../../../../../data/run_pfb_m_v2_sinusoid_8b_16taps_1024points_16b.dat"      
c_sinusoid            = "../../../../../data/run_pfb_m_sinusoid_8b_16taps_32points_16b.dat"           
c_impulse_chirp       = "../../../../../data/run_pfb_m_impulse_chirp_8b_16taps_32points_16b.dat"      
c_noise_1024          = "../../../../../data/run_pfb_m_noise_8b_16taps_1024points_16b.dat"            
c_noise               = "../../../../../data/run_pfb_m_noise_8b_16taps_32points_16b.dat"              
c_dc_agwn             = "../../../../../data/run_pfb_m_dc_agwn_8b_16taps_32points_16b.dat"            

c_phasor_chirp_1024   = "../../../../../data/run_pfb_complex_m_phasor_chirp_8b_16taps_1024points_16b.dat"   
c_phasor_chirp_128    = "../../../../../data/run_pfb_complex_m_phasor_chirp_8b_16taps_128points_16b.dat"    
c_phasor_chirp_64     = "../../../../../data/run_pfb_complex_m_phasor_chirp_8b_16taps_64points_16b.dat"     
c_phasor_chirp        = "../../../../../data/run_pfb_complex_m_phasor_chirp_8b_16taps_32points_16b.dat"     
c_phasor              = "../../../../../data/run_pfb_complex_m_phasor_8b_16taps_32points_16b.dat"           
c_noise_complex_1024  = "../../../../../data/run_pfb_complex_m_noise_complex_8b_16taps_1024points_16b.dat"  
c_noise_complex_128   = "../../../../../data/run_pfb_complex_m_noise_complex_8b_16taps_128points_16b.dat"   
c_noise_complex_64    = "../../../../../data/run_pfb_complex_m_noise_complex_8b_16taps_64points_16b.dat"    
c_noise_complex       = "../../../../../data/run_pfb_complex_m_noise_complex_8b_16taps_32points_16b.dat"    

c_zero                = "UNUSED"
c_un                  = "UNUSED"
 
##CONSTANT t_wpfb#########################################################################################################

# wb 1, two real
c_wb1_two_real_1024 = dict(
    g_wb_factor = 1,
    g_nof_points = 1024,
    g_nof_chan = 0,
    g_nof_wb_streams = 1,
    g_nof_taps = 16,
    g_fil_backoff_w = 1,
    g_fil_in_dat_w = 8,
    g_fil_out_dat_w = 16,
    g_coef_dat_w = 16,
    g_use_reorder = True,
    g_use_fft_shift = False,
    g_use_separate = True,
    g_fft_in_dat_w = 16,
    g_fft_out_dat_w = 16,
    g_fft_out_gain_w = 1,
    g_stage_dat_w = 18,
    g_guard_w = 2,
    g_guard_enable = True,
)
c_wb1_two_real = c_wb1_two_real_1024.copy()
c_wb1_two_real.update({'g_nof_points':32})
c_wb1_two_real_4streams = c_wb1_two_real_1024.copy()
c_wb1_two_real_4streams.update({'g_nof_streams':4})
c_wb1_two_real_4channels = c_wb1_two_real_1024.copy()
c_wb1_two_real_4channels.update({'g_nof_chan':2})

# wb 4, two real
c_wb4_two_real_1024 = c_wb1_two_real_1024.copy()
c_wb1_two_real_1024.update({'g_wb_factor':4,'g_stage_dat_w':c_stage_dat_extra_w})
c_wb4_two_real = c_wb1_two_real_1024.copy()
c_wb4_two_real.update({'g_nof_points':32,'g_wb_factor':4})
c_wb4_two_real_4streams = c_wb4_two_real.copy()
c_wb4_two_real_4streams.update({'g_nof_streams':4})
c_wb4_two_real_4channels = c_wb4_two_real.copy()
c_wb4_two_real_4channels.update({'g_nof_chan':4})

# wb 1, complex reordered
c_wb1_complex_1024 = c_wb1_two_real_1024.copy()
c_wb1_complex_1024.update({'g_use_separate':False})
c_wb1_complex_64 = c_wb1_complex_1024.copy()
c_wb1_complex_64.update({'g_nof_points':64})
c_wb1_complex = c_wb1_complex_1024.copy()
c_wb1_complex.update({'g_nof_points':32})
c_wb1_complex_4streams = c_wb1_complex.copy()
c_wb1_complex_4streams.update({'g_nof_streams':4})
c_wb1_complex_4channels = c_wb1_complex_4streams.copy()
c_wb1_complex_4channels.update({'g_nof_chan':2})

# wb 1, complex fft_shift
c_wb1_complex_fft_shift = c_wb1_complex.copy()
c_wb1_complex_fft_shift.update({'g_use_fft_shift':True})

# wb 1, complex without reorder
c_wb1_complex_flipped_1024 = c_wb1_complex_1024.copy()
c_wb1_complex_flipped_1024.update({'g_use_reorder':False})
c_wb1_complex_flipped_64 = c_wb1_complex_flipped_1024.copy()
c_wb1_complex_flipped_64.update({'g_nof_points':64})
c_wb1_complex_flipped = c_wb1_complex_flipped_1024.copy()
c_wb1_complex_flipped.update({'g_nof_points':32})

# wb 4, complex reordered
c_wb4_complex_1024 = c_wb1_complex_1024.copy()
c_wb4_complex_1024.update({'g_wb_factor':4})
c_wb4_complex_64 = c_wb4_complex_1024.copy()
c_wb4_complex_64.update({'g_nof_points':64})
c_wb4_complex = c_wb4_complex_1024.copy()
c_wb4_complex.update({'g_nof_points':32})
c_wb4_complex_4streams = c_wb4_complex.copy()
c_wb4_complex_4streams.update({'g_nof_streams':4})
c_wb4_complex_4channels = c_wb4_complex.copy()
c_wb4_complex_4channels.update({'g_nof_chan':2})

# wb 4, complex fft_shift
c_wb4_complex_fft_shift = c_wb4_complex.copy()
c_wb4_complex_fft_shift.update({'g_use_fft_shift':True})

# wb 4, complex without reorder
c_wb4_complex_flipped_1024 = c_wb4_complex.copy()
c_wb4_complex_flipped_1024.update({'g_use_reorder':False})
c_wb4_complex_flipped_64 = c_wb4_complex_flipped_1024.copy()
c_wb4_complex_flipped_64.update({'g_nof_points':64})
c_wb4_complex_flipped = c_wb4_complex_flipped_1024.copy()
c_wb4_complex_flipped.update({'g_nof_points':32})
c_wb4_complex_flipped_channels = c_wb4_complex_flipped.copy()
c_wb4_complex_flipped_channels.update({'g_nof_chan':2})

##########################################################################################################################

##Test bench dictionaries and configurations#########################################################################################################
TB_GENERATED = wbpfb_lib.test_bench('tb_tb_vu_wbpfb_unit_wide')
# u_act_wb4_two_real_a0_1024
c_act_wb4_two_real_a0_1024 = dict( 
    g_diff_margin = 1,
    g_coefs_file_prefix_ab = c_pre_ab_v2,
    g_coefs_file_prefix_c = c_pre_c_1024,
    g_data_file_a = c_sinusoid_1024_v2,
    g_data_file_a_nof_lines = 51200,
    g_data_file_b = c_zero,
    g_data_file_b_nof_lines = 51200,
    g_data_file_c = c_un,
    g_data_file_c_nof_lines = 0,
    g_data_file_nof_lines = 51200,
    g_enable_in_val_gaps = False
)
c_act_wb4_two_real_a0_1024.update(c_wb4_two_real_1024)
TB_GENERATED.add_config(
    name = 'u_act_wb4_two_real_a0_1024',
    generics=c_act_wb4_two_real_a0_1024
)

# u_act_wb4_two_real_ab_1024
c_act_wb4_two_real_ab_1024 = c_act_wb4_two_real_a0_1024.copy()
c_act_wb4_two_real_ab_1024.update({'g_data_file_a':c_sinusoid_chirp_1024,'g_coefs_file_prefix_ab':c_pre_ab_1024, 'g_data_file_a_nof_lines':204800, 'g_data_file_b':c_noise_1024})
TB_GENERATED.add_config(
    name = 'u_act_wb4_two_real_ab_1024',
    generics=c_act_wb4_two_real_ab_1024
)

# u_act_wb1_two_real_ab_1024
c_act_wb1_two_real_ab_1024 = c_act_wb4_two_real_ab_1024.copy()
c_act_wb1_two_real_ab_1024.update(c_wb1_two_real_1024)
c_act_wb1_two_real_ab_1024.update({'g_diff_margin': 5})
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_ab_1024',
    generics=c_act_wb1_two_real_ab_1024
)

# u_act_wb1_two_real_chirp_1024
c_act_wb1_two_real_chirp_1024 = c_act_wb1_two_real_ab_1024.copy()
c_act_wb1_two_real_chirp_1024.update({'g_data_file_b': c_zero})
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_chirp_1024',
    generics=c_act_wb1_two_real_chirp_1024
)

# u_act_wb1_two_real_chirp
c_act_wb1_two_real_chirp = dict( 
    g_diff_margin = 5,
    g_coefs_file_prefix_ab = c_pre_ab,
    g_coefs_file_prefix_c = c_pre_c,
    g_data_file_a = c_sinusoid_chirp,
    g_data_file_a_nof_lines = 6400,
    g_data_file_b = c_impulse_chirp,
    g_data_file_b_nof_lines = 6400,
    g_data_file_c = c_un,
    g_data_file_c_nof_lines = 0,
    g_data_file_nof_lines = 6400,
    g_enable_in_val_gaps = False
)
c_act_wb1_two_real_chirp.update(c_wb1_two_real)
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_chirp',
    generics=c_act_wb1_two_real_chirp
)

# u_act_wb1_two_real_a0
c_act_wb1_two_real_a0 = c_act_wb1_two_real_chirp.copy()
c_act_wb1_two_real_a0.update({'g_data_file_a':c_zero})
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_a0',
    generics=c_act_wb1_two_real_a0
)

# u_act_wb1_two_real_b0
c_act_wb1_two_real_b0 = c_act_wb1_two_real_chirp.copy()
c_act_wb1_two_real_b0.update({'g_data_file_b':c_zero})
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_b0',
    generics=c_act_wb1_two_real_b0
)

# u_rnd_wb4_two_real_noise
c_rnd_wb4_two_real_noise=dict( 
    g_diff_margin = 5,
    g_coefs_file_prefix_ab = c_pre_ab,
    g_coefs_file_prefix_c = c_pre_c,
    g_data_file_a = c_noise,
    g_data_file_a_nof_lines = 1600,
    g_data_file_b = c_dc_agwn,
    g_data_file_b_nof_lines = 1600,
    g_data_file_c = c_un,
    g_data_file_c_nof_lines = 0,
    g_data_file_nof_lines = 1600,
    g_enable_in_val_gaps = True
)
c_rnd_wb4_two_real_noise.update(c_wb4_two_real)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise',
    generics=c_rnd_wb4_two_real_noise
)

# u_rnd_wb4_two_real_noise_channels
c_rnd_wb4_two_real_noise_channels = c_rnd_wb4_two_real_noise.copy()
c_rnd_wb4_two_real_noise_channels.update(c_wb4_two_real_4channels)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise_channels',
    generics=c_rnd_wb4_two_real_noise_channels
)

# u_rnd_wb4_two_real_noise_streams
c_rnd_wb4_two_real_noise_streams = c_rnd_wb4_two_real_noise.copy()
c_rnd_wb4_two_real_noise_streams.update(c_wb4_two_real_4streams)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise_streams',
    generics=c_rnd_wb4_two_real_noise_streams
)

# u_rnd_wb1_two_real_noise
c_rnd_wb1_two_real_noise = c_rnd_wb4_two_real_noise.copy()
c_rnd_wb1_two_real_noise.update(c_wb1_two_real)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise',
    generics=c_rnd_wb1_two_real_noise
)

# u_rnd_wb1_two_real_noise_channels
c_rnd_wb1_two_real_noise_channels = c_rnd_wb4_two_real_noise.copy()
c_rnd_wb1_two_real_noise_channels.update(c_wb1_two_real_4channels)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise_channels',
    generics=c_rnd_wb1_two_real_noise_channels
)

# u_rnd_wb1_two_real_noise_streams
c_rnd_wb1_two_real_noise_streams = c_rnd_wb4_two_real_noise.copy()
c_rnd_wb1_two_real_noise_streams.update(c_wb1_two_real_4streams)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise_streams',
    generics=c_rnd_wb1_two_real_noise_streams
)

# u_act_wb1_complex_chirp_1024
c_act_wb1_complex_chirp_1024=dict( 
    g_diff_margin = 3,
    g_coefs_file_prefix_ab = c_pre_ab_1024,
    g_coefs_file_prefix_c = c_pre_c_1024,
    g_data_file_a = c_un,
    g_data_file_a_nof_lines = 0,
    g_data_file_b = c_un,
    g_data_file_b_nof_lines = 0,
    g_data_file_c = c_phasor_chirp_1024,
    g_data_file_c_nof_lines = 204800,
    g_data_file_nof_lines = 51200,
    g_enable_in_val_gaps = False
)
c_act_wb1_complex_chirp_1024.update(c_wb1_complex_1024)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_chirp_1024',
    generics=c_act_wb1_complex_chirp_1024
)

# u_act_wb4_complex_chirp_1024
c_act_wb4_complex_chirp_1024 = c_act_wb1_complex_chirp_1024.copy()
c_act_wb4_complex_chirp_1024.update(c_wb4_complex_1024)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp_1024',
    generics=c_act_wb4_complex_chirp_1024
)

# u_act_wb1_complex_chirp_64
c_act_wb1_complex_chirp_64 = dict( 
    g_diff_margin = 3,
    g_coefs_file_prefix_ab = c_pre_ab,
    g_coefs_file_prefix_c = c_pre_c_64,
    g_data_file_a = c_un,
    g_data_file_a_nof_lines = 0,
    g_data_file_b = c_un,
    g_data_file_b_nof_lines = 0,
    g_data_file_c = c_phasor_chirp_64,
    g_data_file_c_nof_lines = 12800,
    g_data_file_nof_lines = 12800,
    g_enable_in_val_gaps = False
)
c_act_wb1_complex_chirp_64.update(c_wb1_complex_64)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_chirp_64',
    generics=c_act_wb1_complex_chirp_64
)

# u_act_wb4_complex_chirp_64
c_act_wb4_complex_chirp_64 = c_act_wb1_complex_chirp_64.copy()
c_act_wb4_complex_chirp_64.update(c_wb4_complex_64)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp_64',
    generics=c_act_wb4_complex_chirp_64
)

# u_act_wb1_complex_flipped_noise_64
c_act_wb1_complex_flipped_noise_64 = c_act_wb1_complex_chirp_64.copy()
c_act_wb1_complex_flipped_noise_64.update({'g_data_file_c':c_noise_complex_64,'g_data_file_c_nof_lines':3200,'g_data_file_nof_lines':3200})
c_act_wb1_complex_flipped_noise_64.update(c_wb1_complex_flipped_64)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_flipped_noise_64',
    generics=c_act_wb1_complex_flipped_noise_64
)

# u_act_wb4_complex_flipped_noise_64
c_act_wb4_complex_flipped_noise_64 = c_act_wb1_complex_flipped_noise_64.copy()
c_act_wb4_complex_flipped_noise_64.update(c_wb4_complex_flipped_64)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped_noise_64',
    generics=c_act_wb4_complex_flipped_noise_64
)

# u_act_wb4_complex_chirp
c_act_wb4_complex_chirp = dict( 
    g_diff_margin = 3,
    g_coefs_file_prefix_ab = c_pre_ab,
    g_coefs_file_prefix_c = c_pre_c,
    g_data_file_a = c_un,
    g_data_file_a_nof_lines = 0,
    g_data_file_b = c_un,
    g_data_file_b_nof_lines = 0,
    g_data_file_c = c_phasor_chirp,
    g_data_file_c_nof_lines = 6400,
    g_data_file_nof_lines = 6400,
    g_enable_in_val_gaps = False
)
c_act_wb4_complex_chirp.update(c_wb4_complex)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp',
    generics=c_act_wb4_complex_chirp
)

# u_act_wb4_complex_flipped
c_act_wb4_complex_flipped = c_act_wb4_complex_chirp.copy()
c_act_wb4_complex_flipped.update(c_wb4_complex_flipped)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped',
    generics=c_act_wb4_complex_flipped
)

# u_act_wb4_complex_flipped_channels
c_act_wb4_complex_flipped_channels = c_act_wb4_complex_chirp.copy()
c_act_wb4_complex_flipped_channels.update(c_wb4_complex_flipped_channels)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped_channels',
    generics=c_act_wb4_complex_flipped_channels
)

# u_rnd_wb1_complex_phasor
c_rnd_wb1_complex_phasor= dict( 
    g_diff_margin = 3,
    g_coefs_file_prefix_ab = c_pre_ab,
    g_coefs_file_prefix_c = c_pre_c,
    g_data_file_a = c_un,
    g_data_file_a_nof_lines = 0,
    g_data_file_b = c_un,
    g_data_file_b_nof_lines = 0,
    g_data_file_c = c_phasor,
    g_data_file_c_nof_lines = 1600,
    g_data_file_nof_lines = 1600,
    g_enable_in_val_gaps = True
)
c_rnd_wb1_complex_phasor.update(c_wb1_complex)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_phasor',
    generics=c_rnd_wb1_complex_phasor
)

# u_rnd_wb4_complex_phasor
c_rnd_wb4_complex_phasor = c_rnd_wb1_complex_phasor.copy()
c_rnd_wb4_complex_phasor.update(c_wb4_complex)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_phasor',
    generics=c_rnd_wb4_complex_phasor
)

# u_rnd_wb1_complex_fft_shift_phasor
c_rnd_wb1_complex_fft_shift_phasor = c_rnd_wb1_complex_phasor.copy()
c_rnd_wb1_complex_fft_shift_phasor.update(c_wb1_complex_fft_shift)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_fft_shift_phasor',
    generics=c_rnd_wb1_complex_fft_shift_phasor
)

# u_rnd_wb4_complex_fft_shift_phasor
c_rnd_wb4_complex_fft_shift_phasor = c_rnd_wb1_complex_phasor.copy()
c_rnd_wb4_complex_fft_shift_phasor.update(c_wb4_complex_fft_shift)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_fft_shift_phasor',
    generics=c_rnd_wb4_complex_fft_shift_phasor
)

# u_rnd_wb1_complex_noise
c_rnd_wb1_complex_noise = c_rnd_wb1_complex_phasor.copy()
c_rnd_wb1_complex_noise.update({'g_data_file_c':c_noise_complex})
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise',
    generics=c_rnd_wb1_complex_noise
)

# u_rnd_wb1_complex_noise_channels
c_rnd_wb1_complex_noise_channels =c_rnd_wb1_complex_noise.copy()
c_rnd_wb1_complex_noise_channels.update(c_wb1_complex_4channels)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise_channels',
    generics=c_rnd_wb1_complex_noise_channels
)

# u_rnd_wb1_complex_noise_streams
c_rnd_wb1_complex_noise_streams =c_rnd_wb1_complex_noise.copy()
c_rnd_wb1_complex_noise_streams.update(c_wb1_complex_4streams)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise_streams',
    generics=c_rnd_wb1_complex_noise_streams
)

# u_rnd_wb4_complex_noise
c_rnd_wb4_complex_noise =c_rnd_wb1_complex_noise.copy()
c_rnd_wb4_complex_noise.update(c_wb4_complex)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise',
    generics=c_rnd_wb4_complex_noise
)

# u_rnd_wb4_complex_noise_channels
c_rnd_wb4_complex_noise_channels =c_rnd_wb1_complex_noise.copy()
c_rnd_wb4_complex_noise_channels.update(c_wb4_complex_4channels)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise_channels',
    generics=c_rnd_wb4_complex_noise_channels
)

# u_rnd_wb4_complex_noise_streams
c_rnd_wb4_complex_noise_streams =c_rnd_wb1_complex_noise.copy()
c_rnd_wb4_complex_noise_streams.update(c_wb4_complex_4streams)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise_streams',
    generics=c_rnd_wb4_complex_noise_streams
)

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])
vu.main()
