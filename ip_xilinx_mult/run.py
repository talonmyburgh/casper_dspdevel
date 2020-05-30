from vunit import VUnit
from itertools import product

def generate_tests(obj,whichmult,a_wdth, b_wdth):
    for a_wd, b_wd in product(a_wdth, b_wdth):
        config_name = "%s : A_Width = %i, B_Width = %i" % (whichmult, a_wd, b_wd)
        obj.add_config(
            name = config_name,
            generics=dict(a_wd=a_wd,b_wd = b_wd)
        )

vu = VUnit.from_argv()
# Create VUnit instance by parsing command line arguments

# Create library 'lib'
lib = vu.add_library("ip_xilinx_mult_lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("*.vhd")

cmult_infer_tb = lib.test_bench("ip_cmult_infer_tb")
cmult_rtl_tb = lib.test_bench("ip_cmult_rtl_tb")

generate_tests(cmult_infer_tb,"CMULT_INFER",[8,13,18],[8,13,18])
generate_tests(cmult_rtl_tb,"CMULT_RTL",[8,13,18],[8,13,18])

# Run vunit function
vu.main()
