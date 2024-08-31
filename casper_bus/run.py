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


# CASPER BUS Library
casper_bus_lib = vu.add_library("casper_bus_lib")
casper_bus_lib.add_source_file(join(script_dir, "../casper_bus/*.vhd"))

TB_BUS_MUX = casper_bus_lib.test_bench("tb_tb_vu_bus_mux")
for delays in [0,1,2]:
    for input_count in [2,3,6]:
        for input_width in [4,8]:
            TB_BUS_MUX.add_config(
                name = f"Mux ({input_count} inputs of {input_width} bits)",
                generics={
                    "g_delay": delays,
                    "g_nof_inputs": input_count,
                    "g_bit_width": input_width
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
