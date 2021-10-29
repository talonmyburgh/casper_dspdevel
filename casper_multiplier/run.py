from vunit import VUnit
from itertools import product
import random
import glob
import os
# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

def generate_tests(obj, in_dat_w, conjugate_b, out_dat_w, inp_pipeline,product_pipeline, adder_pipeline, out_pipeline):
    """
    Generate test by varying the generics of common_counter:
        in_dat_w : int {4,5,6,7,8}
        conjugate_b : int {TRUE,FALSE}
        out_dat_w : int {2*in_dat_w}
        out_pipeline : >=0
        inp_pipeline : {0,1}
        adder_pipeline : {0,1}
        product_pipeline : {0,1}
    """
    for i_d_w, conj_b, o_d_w in product(in_dat_w,conjugate_b,out_dat_w):
        ab_value_ranges = [(0,0,0,0)] # default, exhaustive
        if i_d_w > 10:
            min_val = -(2**(i_d_w-1))
            max_val = (-min_val)-1

            ab_value_ranges = [
                (min_val,min_val+16,-16,15),
                (-16,+16,-16,15),
                (max_val,max_val-16,-16,15)
                ]
        elif i_d_w > 6:
            ab_value_ranges = [(0,0,-16,15)] # default, exhaustive

        for a_v_min, a_v_max, b_v_min, b_v_max in ab_value_ranges:
            non_exhaustive_value_range = any([lim != 0 for lim in [a_v_min, a_v_max, b_v_min, b_v_max]])
            value_range_string = ", a_val = [%d, %d] , b_val = [%d, %d]" % (
                a_v_min if a_v_min != 0 else -(2**(i_d_w-1)),
                a_v_max if a_v_max != 0 else (2**(i_d_w-1))-1,
                b_v_min if b_v_min != 0 else -(2**(i_d_w-1)),
                b_v_max if b_v_max != 0 else (2**(i_d_w-1))-1 
            )

            config_name1 = "i_d_w=%i, o_d_w=%i, conj_b=%i, inp_pipeline=%i, out_pipeline=%i, add_pipe=%i, prod_pipe=%i" % (i_d_w,o_d_w,conj_b,inp_pipeline,out_pipeline,adder_pipeline,product_pipeline)
            if non_exhaustive_value_range:
                    config_name1 += value_range_string
            obj.add_config(
                name = config_name1,
                generics=dict(g_in_dat_w=i_d_w, g_out_dat_w=o_d_w, g_conjugate_b=conj_b, g_pipeline_input=inp_pipeline, g_pipeline_product=product_pipeline, g_pipeline_adder=adder_pipeline,
                g_pipeline_output=out_pipeline, g_a_val_min=a_v_min, g_a_val_max=a_v_max, g_b_val_min=b_v_min, g_b_val_max=b_v_max)
            )

script_dir, _ = os.path.split(os.path.realpath(__file__))
# Create library 'casper_multiplier_lib'
lib1 = vu.add_library("casper_multiplier_lib", allow_duplicate=True)
txt = glob.glob(script_dir + "/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s in ["tb_common_complex_mult.vhd",
            "common_complex_mult.vhd",
            "tech_complex_mult.vhd",
            "tech_mult_component.vhd",
            "tb_tb_vu_common_complex_mult.vhd"
            ]
    ):
        lib1.add_source_files(x)

inp_pipeline_values = 1 #+ random.sample([0,1], 1)
product_pipeline_values = 0 #+random.sample([0,1], 1)
adder_pipeline_values = 1 #+random.sample([0,1], 1)
out_pipeline_values = 1 #+ random.sample([0,1], 1)
in_dat_w_values = [4, 8, 18]# + random.sample(list(range(5, 8)) + list(range(9, 17)), 1) 
conj_values = [True,False]
out_dat_w_values = [2 * f for f in in_dat_w_values]# + [2 * f + 1 for f in in_dat_w_values]

TB_GENERATED = lib1.test_bench("tb_tb_vu_common_complex_mult")
# TB_GENERATED = lib1.test_bench("tb_common_complex_mult")

generate_tests(
    TB_GENERATED,
    in_dat_w_values,
    conj_values,
    out_dat_w_values,
    inp_pipeline_values,
    adder_pipeline_values,
    product_pipeline_values,
    out_pipeline_values
)

# Create library 'common_components_lib'
lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files(script_dir + "/../common_components/common_pipeline.vhd")
lib2.add_source_files(script_dir + "/../common_components/common_pipeline_sl.vhd")

# Create library 'common_pkg_lib'
lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files(script_dir + "/../common_pkg/*.vhd")
lib3.add_source_files(script_dir + "/../common_pkg/tb_common_pkg.vhd")

lib4 = vu.add_library("technology_lib",allow_duplicate = True)
lib4.add_source_files(script_dir + "/../technology/technology_select_pkg.vhd")

lib5 = vu.add_library("ip_xpm_mult_lib", allow_duplicate=True)
lib5.add_source_files(script_dir + "/../ip_xpm/mult/*.vhd")

lib6 = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
lib6.add_source_files(script_dir + "/../ip_stratixiv/mult/*rtl.vhd")
       
# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","--syn-binding"])
vu.main()
