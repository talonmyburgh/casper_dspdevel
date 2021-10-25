from itertools import product
from vunit import VUnit

def generate_tests(obj, direc, add_sub, inp_pipeline, out_pipeline, in_dat_w):
    """
    Generate test by varying the generics of common_counter:
        direc : string {SUB,ADD,BOTH}
        add_sub : int {0,1}
        pipeline_in : int {0,1}
        pipeline_out : int {5}
        in_dat_w : int {1,5}
        out_dat_w : int {in_dat_w,in_dat_w+1}
    """

    for d, a_s, i_pipe, o_pipe, i_d_w in product(direc,add_sub,inp_pipeline,out_pipeline,in_dat_w):
        config_name1 = "direc = %s, add_sub = %s, i_pipe = %i, o_pipe = %i, in_dat_w = %i, out_dat_w = %i" % (d, a_s, i_pipe, o_pipe, i_d_w, i_d_w)
        obj.add_config(
            name = config_name1,
            generics=dict(g_direction=d,s_sel_add=a_s,g_pipeline_in=i_pipe, g_pipeline_out=o_pipe, g_in_dat_w=i_d_w,g_out_dat_w=i_d_w)
        )
        config_name2 = "direc = %s, add_sub = %s, i_pipe = %i, o_pipe = %i, in_dat_w = %i, out_dat_w = %i" % (d, a_s, i_pipe, o_pipe, i_d_w, i_d_w+1)
        obj.add_config(
            name = config_name2,
            generics=dict(g_direction=d,s_sel_add=a_s,g_pipeline_in=i_pipe, g_pipeline_out=o_pipe, g_in_dat_w=i_d_w,g_out_dat_w=i_d_w+1)
        )

vu = VUnit.from_argv()

lib1 = vu.add_library("casper_adder_lib",allow_duplicate=True)
lib1.add_source_files("*.vhd")
TB_GENERATED = lib1.test_bench("common_add_sub_tb")
generate_tests(TB_GENERATED,
    ['BOTH'],
    [0,1],
    [0,1],
    [0, 1, 3],
    [4, 8, 14, 18]
)

lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files("../common_components/*.vhd")

lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files("../common_pkg/*.vhd")

vu.main()