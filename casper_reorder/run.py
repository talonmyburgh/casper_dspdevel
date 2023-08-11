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

# Create library 'casper_reorder_lib'
casper_reorder_lib = vu.add_library("casper_reorder_lib")
casper_reorder_lib.add_source_files(join(script_dir, "./*.vhd"))

# # Create library 'barrel_switcher_pkg'
# barrel_switcher_pkg = vu.add_library("barrel_switcher_pkg")
# barrel_switcher_pkg.add_source_files(join(script_dir, "./mux.vhd"))
# barrel_switcher_pkg.add_source_files(join(script_dir, "./barrel_switcher.vhd"))
# barrel_switcher_pkg.add_source_files(join(script_dir, "./tb_barrel_switcher.vhd"))
# barrel_switcher_pkg.add_source_files(join(script_dir, "./tb_tb_vu_barrel_switcher.vhd"))

TB_BARREL_SWITCHER = casper_reorder_lib.test_bench("tb_tb_vu_barrel_switcher")

for input_count in [3, 4, 8, 15, 31, 63, 64]:
    for input_width in [3, 4, 8, 16, 32]:
        TB_BARREL_SWITCHER.add_config(
            name = f"Barrel Shifter ({input_count} inputs of {input_width} bits)",
            generics={
                "g_barrel_switch_inputs": input_count,
                "g_barrel_switcher_division_bit_width": input_width
            }
        )


vu.set_compile_option("ghdl.a_flags", ["-Wno-hide", "-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])

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
