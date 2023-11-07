from vunit import VUnit
from os.path import dirname, join
import random

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()
script_dir = dirname(__file__)

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

# Create library 'common_slv_arr_pkg_lib'
common_slv_arr_pkg_lib = vu.add_library("common_slv_arr_pkg_lib")
common_slv_arr_pkg_lib.add_source_files(join(script_dir, "../common_slv_arr_pkg/common_slv_arr_pkg.vhd"))

# COMMON COMPONENTS Library 
common_components_lib = vu.add_library("common_components_lib")
common_components_lib.add_source_files(join(script_dir, "../common_components/common_components_pkg.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_delay.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline_sl.vhd"))

# Create library 'casper_counter_lib'
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_files(join(script_dir, "../casper_counter/free_run_up_counter.vhd"))
casper_counter_lib.add_source_files(join(script_dir, "../casper_counter/common_counter.vhd"))

# Create library 'casper_delay_lib'
casper_delay_lib = vu.add_library("casper_delay_lib")
casper_delay_lib.add_source_files(join(script_dir, "../casper_delay/delay_simple.vhd"))
casper_delay_lib.add_source_files(join(script_dir, "../casper_delay/delay_bram_en_plus.vhd"))

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_files(join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_files(join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# XPM RAM library
ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_r_r = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_r = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_r_r.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_r.add_dependency_on(xpm_source_file_tdpram)

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# CASPER RAM Library
casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r.vhd"))

# CASPER MISC Library
casper_misc_lib = vu.add_library("casper_misc_lib")
casper_misc_lib.add_source_file(join(script_dir, "../misc/sync_delay_en.vhd"))
casper_misc_lib.add_source_file(join(script_dir, "../misc/edge_detect.vhd"))
casper_misc_lib.add_source_file(join(script_dir, "../misc/reg.vhd"))

# CASPER BUS Library
casper_bus_lib = vu.add_library("casper_bus_lib")
casper_bus_lib.add_source_file(join(script_dir, "../casper_bus/bus_fill_slv_arr.vhd"))

# Create library 'casper_reorder_lib'
casper_reorder_lib = vu.add_library("casper_reorder_lib")
casper_reorder_lib.add_source_files(join(script_dir, "./*.vhd"))
# casper_reorder_lib.add_source_files(join(script_dir, "./mux.vhd"))
# casper_reorder_lib.add_source_files(join(script_dir, "./dbl_buffer.vhd"))
# casper_reorder_lib.add_source_files(join(script_dir, "./*reorder.vhd"))

# Really, the barrel_switcher gets tested within the square_transposer
TB_BARREL_SWITCHER = casper_reorder_lib.test_bench("tb_tb_vu_barrel_switcher")
for input_count in [3,]:
    for input_width in [4]:
        TB_BARREL_SWITCHER.add_config(
            name = f"Barrel Shifter ({input_count} inputs of {input_width} bits)",
            generics={
                "g_barrel_switch_inputs": input_count,
                "g_barrel_switcher_division_bit_width": input_width
            }
        )

TB_SQUARE_TRANSPOSER = casper_reorder_lib.test_bench("tb_tb_vu_square_transposer")
for input_count in [2, 3, 4]:
    for input_width in [4, 5, 8]:
        TB_SQUARE_TRANSPOSER.add_config(
            name = f"Square-Transposer ({input_count} inputs of {input_width} bits)",
            generics={
                "g_inputs_2exp": input_count,
                "g_input_bit_width": input_width
            }
        )

# Not working yet, RAM/ROM values come out as zeros
mem_filepath_prefix = join(dirname(__file__), "data")
print(mem_filepath_prefix)
TB_REORDER = casper_reorder_lib.test_bench("tb_tb_vu_reorder")
for input_count in [1]:
    for input_width in [4, 8]:
        for order, reorder_map in {
            # order 1 is not really a reorder,
            ## and the verbatim reimplementation invokes
            ## nonsensical delays...
            1: [0, 1, 2, 3, 4, 5, 6, 7],
            2: [1, 0, 2, 3, 4, 5, 6, 7],
            3: [0, 3, 1, 2, 4, 5, 6, 7],
        }.items():
            for map_latency in [1]:
                for bram_latency in [1]:
                    for fanout_latency in [0]:
                        for double_buffer in [False, True]:
                            for block_ram in [False, True]:
                                for software_controlled in [False]:

                                    TB_REORDER.add_config(
                                        name = f"Reorder {reorder_map} (order: {order}, double_buffer: {double_buffer}, block_ram: {block_ram}, {input_count} inputs of {input_width} bits)",
                                        generics={
                                            "g_input_bit_width": input_width,
                                            "g_nof_inputs": input_count,
                                            "g_reorder_map": ','.join(map(str, reorder_map)),
                                            "g_reorder_order": order if not double_buffer else 2,
                                            "g_map_latency": map_latency,
                                            "g_bram_latency": bram_latency,
                                            "g_fanout_latency": fanout_latency,
                                            "g_double_buffer": double_buffer,
                                            "g_block_ram": block_ram,
                                            "g_software_controlled": software_controlled,
                                            "g_mem_filepath": join(mem_filepath_prefix, f"order{order}.mem"),
                                        }
                                    )

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide", "-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])
# vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])

# simulator_if = vu._create_simulator_if()
# test_list = vu._create_tests(simulator_if)
# vu._get_testbench_files(simulator_if)

# print()

# for source in vu.get_compile_order():
#     print(source._source_file.compile_options)
#     filename = source._source_file.name
#     libraryname = source._source_file.library.name
#     break

vu.main()
