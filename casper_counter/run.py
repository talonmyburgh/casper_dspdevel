from vunit import VUnit
from os.path import dirname, join

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir = dirname(__file__)

# Create library 'casper_counter_lib'
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_files(join(script_dir,"./*.vhd"))

common_pkg_lib = vu.add_library("common_pkg_lib")
#common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

TB_GENERATED = casper_counter_lib.test_bench("tb_tb_vu_common_counter")

# Run vunit function
vu.main()
