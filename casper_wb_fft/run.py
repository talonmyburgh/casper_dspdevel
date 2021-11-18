from vunit import VUnit
from os.path import join, abspath, split
import sys

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
# script_dir = dirname(__file__)
script_dir,_ = split(abspath(__file__))

#gather arguments specifying which tests to run:
# test_to_run = sys.argv[1]
test_to_run = 'par'
arg_options = ['pipe','par','all','wb','none']
if test_to_run in arg_options:
    pass
else:
    print("Invalid argument, running no tests.")
    quit

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

# CASPER ADDER Library
casper_adder_lib = vu.add_library("casper_adder_lib")
casper_adder_lib.add_source_file(join(script_dir,"../casper_adder/common_add_sub.vhd"))

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
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# CASPER MEM Library
casper_mm_lib = vu.add_library("casper_mm_lib")
casper_mm_lib.add_source_file(join(script_dir,"../casper_mm/tb_common_mem_pkg.vhd"))

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
wb_fft_lib.add_source_file(join(script_dir,"fft_sepa.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_gnrcs_intrfcs_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"tb_fft_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_reorder_sepa_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_bf_par.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_par.vhd"))

# CONSTANTS COMMON TO PIPELINE AND PARALLEL TESTS
if test_to_run in arg_options[0:3]:
    c_fft_two_real = dict(
        g_use_reorder = True,
        g_use_fft_shift = False,
        g_use_separate = True,
        g_nof_chan = 0,
        g_wb_factor = 1,
        g_twiddle_offset = 0, 
        g_nof_points = 128,
        g_in_dat_w = 8,
        g_out_dat_w = 16,
        g_out_gain_w = 0,
        g_stage_dat_w = 18,
        g_guard_w = 2,
        g_guard_enable = True
    )
    c_fft_complex = c_fft_two_real.copy()
    c_fft_complex.update({'g_nof_points':64})
    c_fft_complex.update({'g_use_separate':False})
    c_fft_complex_fft_shift = c_fft_complex.copy()
    c_fft_complex_fft_shift.update({'g_use_fft_shift':True})
    c_fft_complex_flipped = c_fft_complex.copy()
    c_fft_complex_flipped.update({'g_use_reorder':False})

    c_impulse_chirp = script_dir+"/data/run_pfft_m_impulse_chirp_8b_128points_16b.dat"
    c_sinusoid_chirp = script_dir+"/data/run_pfft_m_sinusoid_chirp_8b_128points_16b.dat"
    c_noise = script_dir+"/data/run_pfft_m_noise_8b_128points_16b.dat"
    c_dc_agwn = script_dir+"/data/run_pfft_m_dc_agwn_8b_128points_16b.dat"
    c_phasor_chirp = script_dir+"/data/run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat"
    c_phasor = script_dir+"/data/run_pfft_complex_m_phasor_8b_64points_16b.dat"
    c_noise_complex = script_dir+"/data/run_pfft_complex_m_noise_complex_8b_64points_16b.dat"
    c_zero = "UNUSED"
    c_unused = "UNUSED"

    diff_margin = 2

    # REAL TESTS
    c_act_two_real_chirp = c_fft_two_real.copy()
    c_act_two_real_chirp.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_sinusoid_chirp,
    'g_data_file_a_nof_lines':25600,
    'g_data_file_b':c_impulse_chirp,
    'g_data_file_b_nof_lines':25600,
    'g_data_file_c':c_unused,
    'g_data_file_c_nof_lines':0,
    'g_data_file_nof_lines':25600,
    'g_enable_in_val_gaps':False})

    c_act_two_real_a0 = c_act_two_real_chirp.copy()
    c_act_two_real_a0.update({'g_data_file_a':c_zero,
    'g_data_file_nof_lines':5120})

    c_act_two_real_b0 = c_act_two_real_chirp.copy()
    c_act_two_real_b0.update({'g_data_file_b':c_zero,
    'g_data_file_nof_lines':5120})

    c_rnd_two_real_noise = c_act_two_real_chirp.copy()
    c_rnd_two_real_noise.update({'g_data_file_a':c_noise,
    'g_data_file_a_nof_lines':1280,
    'g_data_file_b':c_dc_agwn,
    'g_data_file_b_nof_lines':1280,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':True})

    # COMPLEX TESTS
    c_act_complex_chirp = c_fft_complex.copy()
    c_act_complex_chirp.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':12800,
    'g_enable_in_val_gaps':False})

    c_act_complex_fft_shift = c_fft_complex_fft_shift.copy()
    c_act_complex_fft_shift.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':False})

    c_act_complex_flipped = c_fft_complex_flipped.copy()
    c_act_complex_flipped.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':False})

    c_rnd_complex_noise = c_fft_complex.copy()
    c_rnd_complex_noise.update({
    'g_data_file_c':c_noise_complex,
    'g_data_file_c_nof_lines':640,
    'g_data_file_nof_lines':640,
    'g_enable_in_val_gaps':True})
##########################################################################################

# PIPELINE TEST CONSTANTS AND CONFIGURATIONS
if test_to_run =='pipe' or test_to_run == 'all':
    wb_fft_lib.add_source_file(join(script_dir,"tb_fft_r2_pipe.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_fft_r2_pipe.vhd"))

    #EXTRA PIPELINE CONSTANTS
    c_fft_two_real_more_channels = c_fft_two_real.copy()
    c_fft_two_real_more_channels.update({'g_nof_chan':1})
    c_fft_complex_more_channels = c_fft_complex.copy()
    c_fft_complex_more_channels.update({'g_nof_chan':1})
    c_fft_complex_fft_shift_more_channels = c_fft_complex_fft_shift.copy()
    c_fft_complex_fft_shift_more_channels.update({'g_nof_chan':1})
    c_fft_complex_flipped_more_channels = c_fft_complex_flipped.copy()
    c_fft_complex_flipped_more_channels.update({'g_nof_chan':1})

    c_rnd_two_real_channels = c_fft_two_real_more_channels.copy()
    c_rnd_two_real_channels.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_noise,
    'g_data_file_a_nof_lines':1280,
    'g_data_file_b':c_dc_agwn,
    'g_data_file_b_nof_lines':1280,
    'g_data_file_c':c_unused,
    'g_data_file_c_nof_lines':0,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':True})

    c_act_complex_channels = c_fft_complex_more_channels.copy()
    c_act_complex_channels.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':False})

    c_act_complex_fft_shift_chirp = c_act_complex_fft_shift.copy()
    c_act_complex_fft_shift_chirp.update({'g_data_file_nof_lines':12800})

    c_act_complex_fft_shift_channels = c_fft_complex_fft_shift_more_channels.copy()
    c_act_complex_fft_shift_channels.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':False})

    c_act_complex_flipped_channels = c_fft_complex_flipped_more_channels.copy()
    c_act_complex_flipped_channels.update({'g_diff_margin': diff_margin,
    'g_data_file_a':c_unused,
    'g_data_file_a_nof_lines':0,
    'g_data_file_b':c_unused,
    'g_data_file_b_nof_lines':0,
    'g_data_file_c':c_phasor_chirp,
    'g_data_file_c_nof_lines':12800,
    'g_data_file_nof_lines':1280,
    'g_enable_in_val_gaps':False})

    # PIPELINE TB CONFIGURATIONS
    PIPE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_pipe")
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_two_real_chirp",
        generics=c_act_two_real_chirp)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_two_real_a0",
        generics=c_act_two_real_a0)
    PIPE_TB_GENERATED.add_config(
        name = "c_act_two_real_b0",
        generics=c_act_two_real_b0)
    PIPE_TB_GENERATED.add_config(
        name = "u_rnd_two_real_noise",
        generics=c_rnd_two_real_noise)
    PIPE_TB_GENERATED.add_config(
        name = "u_rnd_two_real_channels",
        generics=c_rnd_two_real_channels)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_chirp",
        generics=c_act_complex_chirp)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_channels",
        generics=c_act_complex_channels)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_fft_shift_chirp",
        generics=c_act_complex_fft_shift_chirp)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_fft_shift_channels",
        generics=c_act_complex_fft_shift_channels)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_flipped",
        generics=c_act_complex_flipped)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_flipped_channels",
        generics=c_act_complex_flipped_channels)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_rnd_complex_noise",
        generics=c_rnd_complex_noise)
##########################################################################################

# PARALLEL TEST CONFIGURATIONS
if test_to_run =='par' or test_to_run == 'all':
    wb_fft_lib.add_source_file(join(script_dir,"tb_fft_r2_par.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_fft_r2_par.vhd"))

    PAR_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_par")
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_two_real_chirp",
        generics= c_act_complex_chirp)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_two_real_a0",
        generics= c_act_two_real_a0)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_two_real_b0",
        generics= c_act_two_real_b0)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_rnd_two_real_noise",
        generics= c_rnd_two_real_noise)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_complex_chirp",
        generics= c_act_complex_chirp)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_complex_fft_shift",
        generics= c_act_complex_fft_shift)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_act_complex_flipped",
        generics= c_act_complex_flipped)    
    PAR_TB_GENERATED.add_config(
        name = "u_par_rnd_complex_noise",
        generics= c_rnd_complex_noise)    
##########################################################################################

if test_to_run =='wb' or test_to_run == 'all':
    wb_fft_lib.add_source_file(join(script_dir,"tb_fft_r2_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_fft_r2_wide.vhd"))
##########################################################################################

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.main()
