package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*
# See: https://github.com/Xilinx/XilinxTclStore/blob/master/tclapp/xilinx/junit/README.md

set origin_dir "."
set outputDir ./synth_output
set_report ./report.xml

file mkdir $outputDir



read_vhdl "$origin_dir/wb_wrapper.vhd"
read_vhdl "$origin_dir/top.vhd"
# read_xdc "$origin_dir/wb_wrapper_ooc.xdc"
read_xdc "$origin_dir/test.xdc"
read_vhdl -library common_components_lib "$origin_dir/../../common_components/common_bit_delay.vhd"
read_vhdl -library common_components_lib "$origin_dir/../../common_components/common_delay.vhd"
read_vhdl -library common_components_lib "$origin_dir/../../common_components/common_pipeline.vhd"
read_vhdl -library common_components_lib "$origin_dir/../../common_components/common_pipeline_sl.vhd"
read_vhdl -library common_components_lib "$origin_dir/../../common_components/common_components_pkg.vhd"

read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/fixed_float_types_c.vhd"
read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/fixed_pkg_c.vhd"
read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/common_pkg.vhd"
read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/common_str_pkg.vhd"
read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/common_lfsr_sequences_pkg.vhd"
#read_vhdl -library common_pkg_lib "$origin_dir/../../common_pkg/float_pkg_c.vhd"

read_vhdl -library technology_lib "$origin_dir/../../technology/technology_select_pkg_versal.vhd"

read_vhdl -library casper_multiplier_lib "$origin_dir/../../casper_multiplier/tech_mult_component.vhd"
read_vhdl -library casper_multiplier_lib "$origin_dir/../../casper_multiplier/tech_agilex_versal_cmult.vhd"
read_vhdl -library casper_multiplier_lib "$origin_dir/../../casper_multiplier/tech_complex_mult.vhd"
read_vhdl -library casper_multiplier_lib "$origin_dir/../../casper_multiplier/common_complex_mult.vhd"

read_vhdl -library casper_counter_lib "$origin_dir/../../casper_counter/common_counter.vhd"

read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_ram_pkg.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/tech_memory_component_pkg.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/tech_memory_ram_cr_cw.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/tech_memory_ram_crw_crw.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_ram_crw_crw.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_paged_ram_crw_crw.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_paged_ram_rw_rw.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_paged_ram_r_w.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/tech_memory_rom_r_r.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/tech_memory_rom_r.vhd"
read_vhdl -library casper_ram_lib "$origin_dir/../../casper_ram/common_rom_r_r.vhd"

read_vhdl -library casper_requantize_lib "$origin_dir/../../casper_requantize/common_round.vhd"
read_vhdl -library casper_requantize_lib "$origin_dir/../../casper_requantize/common_resize.vhd"
read_vhdl -library casper_requantize_lib "$origin_dir/../../casper_requantize/common_requantize.vhd"
read_vhdl -library casper_requantize_lib "$origin_dir/../../casper_requantize/r_shift_requantize.vhd"

read_vhdl -library casper_multiplexer_lib "$origin_dir/../../casper_multiplexer/common_zip.vhd"

read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/twiddlesPkg.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoSDFPkg.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoBF.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoBFStage.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoWeights.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoSDFStage.vhd"
read_vhdl -library r2sdf_fft_lib "$origin_dir/../../r2sdf_fft/rTwoWMul.vhd"

read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_pkg.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_gnrcs_intrfcs_pkg.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_r2_bf_par.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_r2_par.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_sepa.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_reorder_sepa_pipe.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_r2_pipe.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_sepa_wide.vhd"
read_vhdl -library wb_fft_lib "$origin_dir/../../casper_wb_fft/fft_r2_wide.vhd"

read_vhdl -library ip_xpm_mult_lib "$origin_dir/../../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd"
read_vhdl -library ip_xpm_mult_lib "$origin_dir/../../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd"
read_vhdl -library ip_xpm_ram_lib "$origin_dir/../../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"
read_vhdl -library ip_xpm_ram_lib "$origin_dir/../../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"
read_vhdl -library ip_xpm_ram_lib "$origin_dir/../../ip_xpm/ram/ip_xpm_rom_r.vhd"
read_vhdl -library ip_xpm_ram_lib "$origin_dir/../../ip_xpm/ram/ip_xpm_rom_r_r.vhd"

update_compile_order

run_step {synth_design -top top -part xczu48dr-ffvg1517-1-i}

write_checkpoint -force $outputDir/post_synth
# validation
validate_timing "Post synth_design"
validate_logic "Post synth_design"


# opt_design
#run_step {opt_design}
#write_checkpoint opt_design.dcp
# validation
#validate_timing "Post opt_design"
#validate_logic "Post opt_design"

# place_design
#run_step {place_design}
#write_checkpoint place_design.dcp
# validation
#validate_timing "Post place_design"
#validate_logic "Post place_design"

# phys_opt_design
#run_step {phys_opt_design}
#write_checkpoint phys_opt_design.dcp
# validation
#validate_timing "Post phys_opt_design"
#validate_logic "Post phys_opt_design"

# route_design
#run_step {route_design}
#write_checkpoint route_design.dcp
# validation
#validate_timing "Post route_design"
#validate_routing "Post route_design"


validate_messages "Final"
validate_drcs "Final"

write_results
