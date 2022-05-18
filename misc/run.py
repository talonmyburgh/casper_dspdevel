from vunit import VUnit
from os.path import dirname, join
from itertools import product

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
script_dir = dirname(__file__)

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

#MISC Library compile
casper_lib_misc = vu.add_library("casper_misc_lib")
casper_lib_misc.add_source_files(join(script_dir, "./*.vhd"))

RI_TO_C_TB = casper_lib_misc.test_bench("tb_tb_vu_ri_to_c")
C_TO_RI_TB = casper_lib_misc.test_bench("tb_tb_vu_c_to_ri")

async_arr = [True, False]
bit_w = [8,18]
input_val = [-4, 12]

for async_val, bit_w_val, input_v in product(async_arr, bit_w, input_val):
    ri_to_c_config_name = "RI_TO_C: async=%r, bit_w=%d, re/im_input_val=%d" % (async_val, bit_w_val, input_v)
    RI_TO_C_TB.add_config(
        name = ri_to_c_config_name,
        generics=dict(g_async = async_val, g_re_in_w = bit_w_val, g_im_in_w = bit_w_val,
        g_re_in_val = input_v, g_im_in_val = input_v)
    )
    c_to_ri_config_name = "C_TO_RI: async=%r, bit_w=%d, input_val=%d" % (async_val, bit_w_val, input_v)
    C_TO_RI_TB.add_config(
        name = c_to_ri_config_name,
        generics=dict(g_async = async_val, g_bit_width = bit_w_val, g_c_in_val = input_v)
    )
vu.set_compile_option("ghdl.a_flags", ["-frelaxed"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])
vu.main()
