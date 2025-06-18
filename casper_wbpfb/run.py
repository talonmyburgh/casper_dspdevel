from vunit import VUnit
from vunit.sim_if.factory import SIMULATOR_FACTORY
from os.path import join, dirname, abspath
script_dir = dirname(__file__)
import generic_dicts

# Function for package mangling.
def manglePkg(file_name, line_number, new_line):
    with open(file_name, 'r') as file:
        lines = file.readlines()
    lines[line_number] = new_line
    with open(file_name, 'w') as file:
        lines = file.writelines(lines)

#gather arguments specifying which tests to run:
# test_to_run = sys.argv[1]

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_sprom = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_dprom = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_sprom.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_dprom.add_dependency_on(xpm_source_file_base)

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
ip_stratixiv_mult_rtl = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_mult_rtl.vhd"))
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
common_components_lib.add_source_files(join(script_dir, "../common_components/common_paged_reg.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_switch.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_select_symbol.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_components_pkg.vhd"))

# COMMON PACKAGE Library
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
if SIMULATOR_FACTORY.select_simulator().name == "ghdl":
    #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c_2008redirect.vhdl"))
    #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_generic_pkg-body_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_generic_pkg_2008redirect.vhdl"))
    #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_generic_pkg-body_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_generic_pkg_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c_2008redirect.vhdl"))
else:
    # use the "hacked" up VHDL93 version in other simulators 
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_str_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/tb_common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_lfsr_sequences_pkg.vhd"))

# DP PACKAGE Library
dp_pkg_lib = vu.add_library("dp_pkg_lib")
dp_pkg_lib.add_source_file(join(script_dir, "../casper_dp_pkg/dp_stream_pkg.vhd"))

# DP COMPONENTS Library
dp_components_lib = vu.add_library("dp_components_lib")
dp_components_lib.add_source_file(join(script_dir, "../casper_dp_components/dp_hold_input.vhd"))
dp_components_lib.add_source_file(join(script_dir, "../casper_dp_components/dp_hold_ctrl.vhd"))
dp_components_lib.add_source_file(join(script_dir, "../casper_dp_components/dp_block_gen.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# COMMON COUNTER Library
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_file(join(script_dir, "../casper_counter/common_counter.vhd"))

# CASPER ADDER Library
casper_adder_lib = vu.add_library("casper_adder_lib")
casper_adder_lib.add_source_file(join(script_dir, "../casper_adder/common_add_sub.vhd"))
casper_adder_lib.add_source_file(join(script_dir, "../casper_adder/common_adder_tree.vhd"))
casper_adder_lib.add_source_file(join(script_dir, "../casper_adder/common_adder_tree_a_str.vhd"))

# CASPER MUlTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib")
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))
tech_complex_mult = casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_agilex_versal_cmult.vhd"))
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
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# CASPER FILTER Library
#Ensure bitwidths in fil_pkg are correct:
fil_pkg = join(script_dir, "../casper_filter/fil_pkg.vhd")
#Required line entries.
fil_line_entries = ['CONSTANT c_fil_in_dat_w       : natural := 8;\n','CONSTANT c_fil_out_dat_w      : natural := 16;\n','CONSTANT c_fil_coef_dat_w    : natural := 16;\n']
manglePkg(fil_pkg, slice(7,10), fil_line_entries)

casper_filter_lib = vu.add_library("casper_filter_lib")
casper_filter_lib.add_source_file(fil_pkg)
casper_filter_lib.add_source_file(join(script_dir, "../casper_filter/fil_ppf_ctrl.vhd"))
casper_filter_lib.add_source_file(join(script_dir, "../casper_filter/fil_ppf_filter.vhd"))
casper_filter_lib.add_source_file(join(script_dir, "../casper_filter/fil_ppf_single.vhd"))
casper_filter_lib.add_source_file(join(script_dir, "../casper_filter/fil_ppf_wide.vhd"))

# CASPER MEM Library
casper_mm_lib = vu.add_library("casper_mm_lib")
casper_mm_lib.add_source_file(join(script_dir, "../casper_mm/tb_common_mem_pkg.vhd"))

# CASPER SIM TOOLS Library
casper_sim_tools_lib = vu.add_library("casper_sim_tools_lib")
casper_sim_tools_lib.add_source_file(join(script_dir, "../casper_sim_tools/common_wideband_data_scope.vhd"))

# CASPER PIPELINE Library
casper_pipeline_lib = vu.add_library("casper_pipeline_lib")
casper_pipeline_lib.add_source_file(join(script_dir, "../casper_pipeline/dp_pipeline.vhd"))

# CASPER DIAGNOSTICS Library
casper_diagnostics_lib = vu.add_library("casper_diagnostics_lib")
casper_diagnostics_lib.add_source_file(join(script_dir, "../casper_diagnostics/diag_pkg.vhd"))

# RTWOSDF Library
r2sdf_fft_lib = vu.add_library("r2sdf_fft_lib")
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoBF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoBFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/twiddlesPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoSDFPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoWeights.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoWMul.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoSDFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir, "../r2sdf_fft/rTwoSDF.vhd"))

# WIDEBAND FFT Library
#Ensure bitwidths in fft_gnrcs_intrfcs_pkg are correct:
fft_pkg = join(script_dir, "../casper_wb_fft/fft_gnrcs_intrfcs_pkg.vhd")
#Required line entries.
fft_line_entries = ['CONSTANT c_fft_in_dat_w       : natural := 16;\n','CONSTANT c_fft_out_dat_w      : natural := 16;\n','CONSTANT c_fft_stage_dat_w    : natural := 18;\n']
manglePkg(fft_pkg, slice(7,10), fft_line_entries)

wb_fft_lib = vu.add_library("wb_fft_lib")
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_sepa.vhd"))
wb_fft_lib.add_source_file(fft_pkg)
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/tb_fft_pkg.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_reorder_sepa_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_r2_pipe.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_r2_bf_par.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_r2_par.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_r2_wide.vhd"))
wb_fft_lib.add_source_file(join(script_dir, "../casper_wb_fft/fft_sepa_wide.vhd"))

# WIDEBAND PFB Library
wpfb_lib = vu.add_library("wpfb_lib")
wpfb_lib.add_source_file(join(script_dir, "wbpfb_gnrcs_intrfcs_pkg.vhd"))
wpfb_lib.add_source_file(join(script_dir, "dp_bsn_restore_global.vhd"))
wpfb_lib.add_source_file(join(script_dir, "dp_block_gen_valid_arr.vhd"))
wpfb_lib.add_source_file(join(script_dir, "wbpfb_unit_dev.vhd"))
wpfb_lib.add_source_file(join(script_dir, "tb_wbpfb_unit_wide.vhd"))
wpfb_lib.add_source_file(join(script_dir, "tb_tb_vu_wbpfb_unit_wide.vhd"))

##########################################################################################################################

##Test bench dictionaries and configurations#########################################################################################################
TB_GENERATED = wpfb_lib.test_bench('tb_tb_vu_wbpfb_unit_wide')
## [u_act_wb4_two_real_a0_1024, u_act_wb4_two_real_ab_1024] fail due to `c_stage_dat_extra_w = 28`
# TB_GENERATED.add_config(
#     name = 'u_act_wb4_two_real_a0_1024',
#     generics=generic_dicts.u_act_wb4_two_real_a0_1024
# )
# TB_GENERATED.add_config(
#     name = 'u_act_wb4_two_real_ab_1024',
#     generics=generic_dicts.u_act_wb4_two_real_ab_1024
# )
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_ab_1024',
    generics=generic_dicts.u_act_wb1_two_real_ab_1024
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_chirp_1024',
    generics=generic_dicts.u_act_wb1_two_real_chirp_1024
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_chirp',
    generics=generic_dicts.u_act_wb1_two_real_chirp
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_a0',
    generics=generic_dicts.u_act_wb1_two_real_a0
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_two_real_b0',
    generics=generic_dicts.u_act_wb1_two_real_b0
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise',
    generics=generic_dicts.u_rnd_wb4_two_real_noise
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise_channels',
    generics=generic_dicts.u_rnd_wb4_two_real_noise_channels
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_two_real_noise_streams',
    generics=generic_dicts.u_rnd_wb4_two_real_noise_streams
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise',
    generics=generic_dicts.u_rnd_wb1_two_real_noise
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise_channels',
    generics=generic_dicts.u_rnd_wb1_two_real_noise_channels
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_two_real_noise_streams',
    generics=generic_dicts.u_rnd_wb1_two_real_noise_streams
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_chirp_1024',
    generics=generic_dicts.u_act_wb1_complex_chirp_1024
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp_1024',
    generics=generic_dicts.u_act_wb4_complex_chirp_1024
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_chirp_64',
    generics=generic_dicts.u_act_wb1_complex_chirp_64
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp_64',
    generics=generic_dicts.u_act_wb4_complex_chirp_64
)
TB_GENERATED.add_config(
    name = 'u_act_wb1_complex_flipped_noise_64',
    generics=generic_dicts.u_act_wb1_complex_flipped_noise_64
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped_noise_64',
    generics=generic_dicts.u_act_wb4_complex_flipped_noise_64
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_chirp',
    generics=generic_dicts.u_act_wb4_complex_chirp
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped',
    generics=generic_dicts.u_act_wb4_complex_flipped
)
TB_GENERATED.add_config(
    name = 'u_act_wb4_complex_flipped_channels',
    generics=generic_dicts.u_rnd_wb4_complex_flipped_channels
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_phasor',
    generics=generic_dicts.u_rnd_wb1_complex_phasor
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_phasor',
    generics=generic_dicts.u_rnd_wb4_complex_phasor
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_fft_shift_phasor',
    generics=generic_dicts.u_rnd_wb1_complex_fft_shift_phasor
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_fft_shift_phasor',
    generics=generic_dicts.u_rnd_wb4_complex_fft_shift_phasor
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise',
    generics=generic_dicts.u_rnd_wb1_complex_noise
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise_channels',
    generics=generic_dicts.u_rnd_wb1_complex_noise_channels
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb1_complex_noise_streams',
    generics=generic_dicts.u_rnd_wb1_complex_noise_streams
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise',
    generics=generic_dicts.u_rnd_wb4_complex_noise
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise_channels',
    generics=generic_dicts.u_rnd_wb4_complex_noise_channels
)
TB_GENERATED.add_config(
    name = 'u_rnd_wb4_complex_noise_streams',
    generics=generic_dicts.u_rnd_wb4_complex_noise_streams
)

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed", "-fsynopsys", "-fexplicit", "-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed", "-fsynopsys", "-fexplicit", "--syn-binding"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable","--max-stack-alloc=4096"])
vu.set_sim_option("disable_ieee_warnings",True)
vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])
vu.main()
