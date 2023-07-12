import os
import random
from itertools import product
from vunit import VUnit

def generate_tests(obj, direc, add_sub, inp_pipeline, out_pipeline, in_dat_w):
    """
    Generate test by varying the generics of casper_adder:
        direc : string {SUB,ADD,BOTH}
        add_sub : int {0,1}
        pipeline_in : int {0,1}
        pipeline_out : int {5}
        in_dat_w : int {1,5}
        out_dat_w : int {in_dat_w,in_dat_w+1}
    """
    testnum = 1;
    for d, a_s, i_pipe, o_pipe, i_d_w in product(direc,add_sub,inp_pipeline,out_pipeline,in_dat_w):
        ab_value_ranges = [(0,0,0,0)] # default, exhaustive
        if i_d_w > 14:
            min_val = -(2**(i_d_w-1))
            max_val = (-min_val)-1

            ab_value_ranges = [
                (min_val,min_val+128,-16,15),
                (-128,+128,-16,15),
                (max_val,max_val-128,-16,15)
                ]
        elif i_d_w > 10:
            ab_value_ranges = [(0,0,-16,15)] # default, exhaustive

        for a_v_min, a_v_max, b_v_min, b_v_max in ab_value_ranges:
            non_exhaustive_value_range = any([lim != 0 for lim in [a_v_min, a_v_max, b_v_min, b_v_max]])
            value_range_string = ", a_val = [%d,%d] , b_val = [%d,%d]" % (
                a_v_min if a_v_min != 0 else -(2**(i_d_w-1)),
                a_v_max if a_v_max != 0 else (2**(i_d_w-1))-1,
                b_v_min if b_v_min != 0 else -(2**(i_d_w-1)),
                b_v_max if b_v_max != 0 else (2**(i_d_w-1))-1 
            )
            config_name1 = "TestA%d"%(testnum)
            #testnum = testnum + 1
            #config_name1 = "direc = %s, add_sub = %s, i_pipe = %i, o_pipe = %i, in_dat_w = %i, out_dat_w = %i" % (d, a_s, i_pipe, o_pipe, i_d_w, i_d_w)
            #if non_exhaustive_value_range:
            #    config_name1 += value_range_string
            obj.add_config(
                name = config_name1,
                generics=dict(g_direction=d,g_sel_add=a_s,g_pipeline_in=i_pipe, g_pipeline_out=o_pipe, g_in_dat_w=i_d_w,g_out_dat_w=i_d_w,
                                g_a_val_min=a_v_min, g_a_val_max=a_v_max, g_b_val_min=b_v_min, g_b_val_max=b_v_max)
            )
            #config_name2 = "direc = %s, add_sub = %s, i_pipe = %i, o_pipe = %i, in_dat_w = %i, out_dat_w = %i" % (d, a_s, i_pipe, o_pipe, i_d_w, i_d_w+1)
            #if non_exhaustive_value_range:
            #    config_name2 += value_range_string
            config_name2 = "TestB%d"%(testnum)
            testnum = testnum + 1
            obj.add_config(
                name = config_name2,
                generics=dict(g_direction=d,g_sel_add=a_s,g_pipeline_in=i_pipe, g_pipeline_out=o_pipe, g_in_dat_w=i_d_w,g_out_dat_w=i_d_w+1,
                                g_a_val_min=a_v_min, g_a_val_max=a_v_max, g_b_val_min=b_v_min, g_b_val_max=b_v_max)
            )

vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir = os.path.dirname(__file__)

lib1 = vu.add_library("casper_adder_lib",allow_duplicate=True)
lib1.add_source_files(os.path.join(script_dir, "*.vhd"))
TB_GENERATED = lib1.test_bench("tb_tb_vu_common_add_sub")

direc_values = ['BOTH']
add_sub_values = [0,1]
inp_pipeline_values = random.sample([0,1], 1)
out_pipeline_values = [0] + random.sample(range(1,5), 1)
in_dat_w_values = [18] + random.sample(range(4, 8), 1) + random.sample(range(9, 17), 1) 

generate_tests(TB_GENERATED,
    direc_values,
    add_sub_values,
    inp_pipeline_values,
    out_pipeline_values,
    in_dat_w_values
)

lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files(os.path.join(script_dir, "../common_components/*.vhd"))

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_file(os.path.join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_file(os.path.join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(os.path.join(script_dir, "../technology/technology_select_pkg.vhd"))

casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_file(os.path.join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_file(os.path.join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(os.path.join(script_dir, "../technology/technology_select_pkg.vhd"))

casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(os.path.join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/float_pkg_c.vhd"))
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/*.vhd"))






vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
#vu.set_sim_option("ghdl.elab_e", True)
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags",["--max-stack-alloc=4096"])
vu.set_compile_option("nvc.a_flags",["--relaxed"])
vu.set_sim_option("nvc.heap_size", "128m -M 128m")
vu.main()
