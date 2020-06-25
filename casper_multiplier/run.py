from vunit import VUnit
from itertools import product
import glob
# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

def generate_tests(obj, in_dat_w, conjugate_b, pipeline_in,pipeline_product, pipeline_adder, pipeline_out):
    """
    Generate test by varying the generics of common_counter:
        in_dat_w : int {4,5,6,7,8}
        out_dat_w : int {9,11,13,15,17}
        conjugate_b : int {TRUE,FALSE}
        pipeline_out : int {0,1}
        pipeline_in : {0,1}
        pipeline_adder : {0,1}
        pipeline_product : {0,1}
    """
    for i_d_w, conj_b in product(in_dat_w, conjugate_b):
        o_d_w = (2*i_d_w) +1
        config_name1 = "i_d_w=%i, o_d_w=%i, conj_b=%r, i_pipe=%i, o_pipe=%i, add_pipe=%i, prod_pipe=%i" % (i_d_w,o_d_w,conj_b,pipeline_in,pipeline_out,pipeline_adder,pipeline_product)
        obj.add_config(
            name = config_name1,
            generics=dict(g_in_dat_w=i_d_w,g_out_dat_w=o_d_w,g_conjugate_b=conj_b, g_pipeline_input=pipeline_in, g_pipeline_product=pipeline_product,g_pipeline_adder=pipeline_adder, g_pipeline_output=pipeline_out)
        )

# Create library 'casper_multiplier_lib'
lib1 = vu.add_library("casper_multiplier_lib")
lib1.add_source_files("*.vhd")
TB_GENERATED = lib1.test_bench("common_complex_mult_tb")
# config_name1 = "i_d_w=%i, o_d_w=%i, conj_b=%r, i_pipe=%i, o_pipe=%i, add_pipe=%i, prod_pipe=%i" % (4,8,False,1,1,1,0)
# TB_GENERATED.add_config(
#     name = config_name1,
#     generics=dict(g_in_dat_w=4,g_out_dat_w=8,g_conjugate_b=False, g_pipeline_input=1, g_pipeline_product=0,g_pipeline_adder=1, g_pipeline_output=1)
# )
generate_tests(TB_GENERATED, [3,4], [False,True], 1,0, 1, 1)

# Create library 'common_components_lib'
lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files("../casper_common_components/*.vhd")

# Create library 'casper_common_pkg_lib'
lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files("../casper_common_pkg/*.vhd")
       
# Run vunit function
vu.main()
