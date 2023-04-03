from vunit import VUnit, VUnitCLI
from os.path import join, abspath, split,realpath,dirname
from importlib.machinery import SourceFileLoader
# load the r2sdf fix point accurate model from r2sdf module.
r2sdf_fft_py = SourceFileLoader("r2sdf_fft_py",f"{realpath(dirname(__file__))}/../r2sdf_fft/r2sdf_fft_py/__init__.py").load_module()
import numpy as np

def tb_vu_wb_fft_vfmodel_setup(ui):
   
    testbench=ui.test_bench("tb_vu_wb_fft_vfmodel")
    use_reorder = False
    in_dat_w = 18
    out_dat_w = 18
    stage_dat_w = 18
    guard_w = 0
    twiddle_width = 18
    fftsize_log2 = 13
    
    do_rounding = 1
    do_saturation = 1
    enable_pattern = 2 #every other clock
    # Decode some of those for VHDL
    if do_rounding==1:
        use_round = "ROUND"
        use_mult_round = "ROUND"
    if do_saturation==1:
        ovflw_behav = "SATURATE"

    scale_sched = 0
    for stage in range(0,fftsize_log2):
        if (stage % 2)==1:
            scale_sched = scale_sched + 2**stage
        # scale at Stage 0
        if stage==0:
            scale_sched = scale_sched + 2**stage
        if stage==2:
            scale_sched = scale_sched + 2**stage
    

    d_indices = np.arange(0,2*(2**fftsize_log2))
    # Generate a full scale cw with 12-bits
    data = 2047*np.exp(1.0j * 2*np.pi * d_indices*(-2e9/7e9))
    #noise = np.random.normal(0, 5.5, size=(data.shape[0]))
    #data = data + noise
    data = r2sdf_fft_py.roundsat(data,1,in_dat_w,0,1,1,1)

    enable_pattern = 0
    testbench.add_config(
        pre_config=r2sdf_fft_py.make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=r2sdf_fft_py.make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTWIDE_E0_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 1
    testbench.add_config(
        pre_config=r2sdf_fft_py.make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=r2sdf_fft_py.make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTWIDE_Erandom_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 2
    testbench.add_config(
        pre_config=r2sdf_fft_py.make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=r2sdf_fft_py.make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTWIDE_E10Clocks_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 3
    testbench.add_config(
        pre_config=r2sdf_fft_py.make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=r2sdf_fft_py.make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTWIDE_E100Clocks_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
        


            #    name=f"TwiddleMagic_w{bidx}b_{fftsize}",
            #    generics=dict(g_twiddle_width=bidx,g_fftsize_log2=fftsizelog2),
            #    post_check=make_twiddle_post_check(fftsize,bidx,1))    

# Function for package mangling.
def manglePkg(file_name, line_number, new_line):
    with open(file_name, 'r') as file:
        lines = file.readlines()
    lines[line_number] = new_line
    with open(file_name, 'w') as file:
        lines = file.writelines(lines)


cli = VUnitCLI()
# script_dir = dirname(__file__)
script_dir,_ = split(abspath(__file__))

#gather arguments specifying which tests to run:
# test_to_run = sys.argv[1]
cli.parser.add_argument('--par',action = 'store_true',help = 'Run the parallel FFT tests')
cli.parser.add_argument('--pipe',action = 'store_true', help = 'Run the pipeline FFT tests')
cli.parser.add_argument('--wide',action = 'store_true', help = 'Run the wide FFT tests')
cli.parser.add_argument('--bitaccurate',action = 'store_true', help = 'Run the bitaccurate FFT tests')
args = cli.parse_args()

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_args(args = args,compile_builtins=False)

# If none of the flags are specified, run all tests.
run_all = not(args.par or args.pipe or args.wide or args.bitaccurate)
vu.add_vhdl_builtins()
vu.add_random()

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
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
common_components_lib.add_source_files(join(script_dir, "../common_components/common_select_symbol.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_components_pkg.vhd"))

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
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_agilex_versal_cmult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_complex_mult.vhd"))
tech_complex_mult.add_dependency_on(ip_cmult_3dsp)
tech_complex_mult.add_dependency_on(ip_cmult_4dsp)
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
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# CASPER MEM Library
casper_mm_lib = vu.add_library("casper_mm_lib")
casper_mm_lib.add_source_file(join(script_dir,"../casper_mm/tb_common_mem_pkg.vhd"))

# CASPER SIM TOOLS Library
casper_sim_tools_lib =vu.add_library("casper_sim_tools_lib")
casper_sim_tools_lib.add_source_file(join(script_dir,"../casper_sim_tools/common_wideband_data_scope.vhd"))

# RTWOSDF Library
# Pathline for twid coefficients
twid_path_stem = abspath(script_dir + '/../r2sdf_fft/data/twids/sdf_twiddle_coeffs')
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
# WIDEBAND FFT Library
#Ensure bitwidths in fft_gnrcs_intrfcs_pkg are correct:
fft_pkg = join(script_dir,"fft_gnrcs_intrfcs_pkg.vhd")
#Required line entries.
fft_line_entries = ['CONSTANT c_fft_in_dat_w       : natural := 8;\n','CONSTANT c_fft_out_dat_w      : natural := 16;\n','CONSTANT c_fft_stage_dat_w    : natural := 18;\n']
manglePkg(fft_pkg, slice(7,10), fft_line_entries)

wb_fft_lib = vu.add_library("wb_fft_lib")
wb_fft_lib.add_source_file(join(script_dir,"fft_sepa.vhd"))
wb_fft_lib.add_source_file(fft_pkg)
wb_fft_lib.add_source_file(join(script_dir,"tb_fft_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_reorder_sepa_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_bf_par.vhd"))
wb_fft_lib.add_source_file(join(script_dir,"fft_r2_par.vhd"))

# CONSTANTS COMMON TO ALL TESTS
if args.par or args.pipe or run_all or args.wide:
    c_fft_two_real = dict(
        g_use_reorder = True,
        g_use_fft_shift = False,
        g_use_separate = True,
        g_nof_chan = 0,
        g_wb_factor = 1,
        g_twid_dat_w = 18,
        g_max_addr_w = 8,
        g_nof_points = 128,
        g_in_dat_w = 8,
        g_out_dat_w = 16,
        g_out_gain_w = 0,
        g_stage_dat_w = 18,
        g_guard_w = 2,
        g_guard_enable = True,
        g_pipe_reo_in_place = False,
        g_twid_file_stem = twid_path_stem
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
if args.pipe or run_all:
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

    c_rnd_two_real_noise_ip = c_rnd_two_real_noise.copy()
    c_rnd_two_real_noise_ip.update({'g_pipe_reo_in_place':True})

    c_act_complex_flipped_ip = c_act_complex_flipped.copy()
    c_act_complex_flipped_ip.update({'g_pipe_reo_in_place':True}) 

    c_fft_complex_flipped_more_channels_ip = c_fft_complex_flipped_more_channels.copy()
    c_fft_complex_flipped_more_channels.update({'g_pipe_reo_in_place':True}) 

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
        name = "u_rnd_two_real_noise_ip",
        generics=c_rnd_two_real_noise_ip)
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
        name = "u_pipe_act_complex_flipped_ip",
        generics=c_act_complex_flipped_ip)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_act_complex_flipped_channels",
        generics=c_act_complex_flipped_channels)
    PIPE_TB_GENERATED.add_config(
        name = "u_pipe_rnd_complex_noise",
        generics=c_rnd_complex_noise)
##########################################################################################

# PARALLEL TEST CONFIGURATIONS
if args.par or run_all:
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

if args.wide or run_all:
    wb_fft_lib.add_source_file(join(script_dir,"fft_sepa_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_fft_r2_par.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"fft_r2_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_fft_r2_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_fft_r2_wide.vhd"))

    #EXTRA WIDE CONSTANTS
    c_act_wb4_two_real_chirp = c_act_two_real_chirp.copy()
    c_act_wb4_two_real_chirp.update({'g_wb_factor':4})
    c_act_wb4_two_real_chirp_ip = c_act_wb4_two_real_chirp.copy()
    c_act_wb4_two_real_chirp_ip.update({'g_pipe_reo_in_place':True})
    c_act_wb4_two_real_a0 = c_act_two_real_a0.copy()
    c_act_wb4_two_real_a0.update({'g_wb_factor':4})
    c_act_wb4_two_real_b0 = c_act_two_real_b0.copy()
    c_act_wb4_two_real_b0.update({'g_wb_factor':4})
    c_act_wb4_two_real_b0 = c_act_two_real_b0.copy()
    c_act_wb4_two_real_b0.update({'g_wb_factor':4})
    c_rnd_wb4_two_real_noise = c_rnd_two_real_noise.copy()
    c_rnd_wb4_two_real_noise.update({'g_wb_factor':4})

    c_act_wb4_complex_fft_shift = c_act_complex_fft_shift.copy()
    c_act_wb4_complex_fft_shift.update({'g_wb_factor':4})
    c_act_wb4_complex_flipped = c_act_complex_flipped.copy()
    c_act_wb4_complex_flipped.update({'g_wb_factor':4})
    c_act_wb4_complex_flipped_ip = c_act_wb4_complex_flipped.copy()
    c_act_wb4_complex_flipped_ip.update({'g_pipe_reo_in_place':True})
    c_act_wb4_complex_chirp = c_act_complex_chirp.copy()
    c_act_wb4_complex_chirp.update({'g_wb_factor':4})
    c_rnd_wb4_complex_noise = c_rnd_complex_noise.copy()
    c_rnd_wb4_complex_noise.update({'g_wb_factor':4})
    c_rnd_wb4_complex_noise_ip = c_rnd_wb4_complex_noise.copy()
    c_rnd_wb4_complex_noise_ip.update({'g_pipe_reo_in_place':True})
    c_act_wb64_complex_noise = c_rnd_complex_noise.copy()
    c_act_wb64_complex_noise.update({'g_wb_factor':64})
    c_act_wb1_complex_noise = c_rnd_complex_noise.copy()
    c_act_wb1_complex_noise.update({'g_wb_factor':1})
    c_act_wb1_complex_noise_ip = c_act_wb1_complex_noise.copy()
    c_act_wb1_complex_noise_ip.update({'g_pipe_reo_in_place':True})

    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_two_real_chirp",
        generics=c_act_wb4_two_real_chirp
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_two_real_chirp_ip",
        generics=c_act_wb4_two_real_chirp_ip
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_two_real_a0",
        generics=c_act_wb4_two_real_a0
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_two_real_b0",
        generics=c_act_wb4_two_real_b0
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_rnd_two_real_noise",
        generics=c_rnd_wb4_two_real_noise
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_complex_chirp",
        generics=c_act_wb4_complex_chirp
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_complex_fft_shift",
        generics=c_act_wb4_complex_fft_shift
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_complex_flipped",
        generics=c_act_wb4_complex_flipped
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_complex_flipped_ip",
        generics=c_act_wb4_complex_flipped_ip
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_rnd_complex_noise",
        generics=c_rnd_wb4_complex_noise
    )
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_rnd_complex_noise_ip",
        generics=c_rnd_wb4_complex_noise_ip
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_wb1_complex_noise",
        generics=c_act_wb1_complex_noise
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_wb1_complex_noise_ip",
        generics=c_act_wb1_complex_noise_ip
    )
    WIDE_TB_GENERATED = wb_fft_lib.test_bench("tb_tb_vu_fft_r2_wide")
    WIDE_TB_GENERATED.add_config(
        name = "u_wide_act_wb64_complex_noise",
        generics=c_act_wb64_complex_noise
    )


if args.bitaccurate or run_all:
    wb_fft_lib.add_source_file(join(script_dir,"fft_sepa_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"fft_r2_wide.vhd"))
    wb_fft_lib.add_source_file(join(script_dir,"tb_vu_wb_fft_vfmodel.vhd"))
    tb_vu_wb_fft_vfmodel_setup(wb_fft_lib)

##########################################################################################

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])
vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])
vu.main()
