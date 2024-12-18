from vunit import VUnit
from os.path import dirname, join
import random

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir = dirname(__file__)

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/tb_common_pkg.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

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

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# Create library 'common_components_lib'
lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files(join(script_dir, "../common_components/*.vhd"))

# Create library 'ram_lib'
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

# Create library 'casper_counter_lib'
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_files(join(script_dir,"../casper_counter/common_counter.vhd"))
casper_counter_lib.add_source_files(join(script_dir,"../casper_counter/free_run_up_counter.vhd"))

# Create library 'common_slv_arr_pkg_lib'
common_slv_arr_pkg_lib = vu.add_library("common_slv_arr_pkg_lib")
common_slv_arr_pkg_lib.add_source_files(join(script_dir, "../common_slv_arr_pkg/common_slv_arr_pkg.vhd"))

# Create library 'casper_delay_lib'
casper_delay_lib = vu.add_library("casper_delay_lib")
casper_delay_lib.add_source_files(join(script_dir, "../casper_delay/delay_simple.vhd"))
casper_delay_lib.add_source_files(join(script_dir, "../casper_delay/delay_bram_en_plus.vhd"))

# Create library 'casper_accumulators_lib'
casper_accumulators_lib = vu.add_library("casper_accumulators_lib")
casper_accumulators_lib.add_source_files(join(script_dir, "../casper_accumulators/simple_accumulator.vhd"))

# Create library 'casper_flow_control_lib'
casper_flow_control_lib = vu.add_library("casper_flow_control_lib")
casper_flow_control_lib.add_source_files(join(script_dir, "../casper_flow_control/bus_create.vhd"))


# CASPER BUS Library
casper_bus_lib = vu.add_library("casper_bus_lib")
casper_bus_lib.add_source_files(join(script_dir, "*.vhd"))

TB_BUS_MUX = casper_bus_lib.test_bench("tb_tb_vu_bus_mux")
for delays in [0,1,2]:
    for input_count in [2,3,6]:
        for input_width in [4,8]:
            TB_BUS_MUX.add_config(
                name = f"Mux (delay {delays} of {input_count} inputs of {input_width} bits)",
                generics={
                    "g_delay": delays,
                    "g_nof_inputs": input_count,
                    "g_bit_width": input_width
                }
            )

TB_REPLICATE = casper_bus_lib.test_bench("tb_tb_vu_bus_replicate")
for delay in [0,1,2]:
    for replication_factor in [2, 3]:
        TB_REPLICATE.add_config(
            name = f"Replicate (x{replication_factor}) with delay {delay}",
            generics={
                "g_replication_factor": replication_factor,
                "g_latency": delay,
                "g_replicated_value": 6
            }
        )

TB_BUS_ACC = casper_bus_lib.test_bench("tb_tb_vu_bus_accumulator")
TB_BUS_ACC.add_config(
    name = f"Bus Accumulator",
    generics={}
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
