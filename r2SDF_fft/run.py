from vunit import VUnit
import glob
from itertools import product

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib' 
def generate_tests(test, in_en, use_ns_file, nop, reorder, i_d_w, o_d_w, g_w):
    for i_e, r_ord in product(in_en, reorder):
        config_name = "In enable = %i, Use noise file = %r, number of points = %i, use reorder = %r,in data width = %i,out data width = %i, guard bit width = %i"%(i_e,use_ns_file, nop,r_ord,i_d_w,o_d_w,g_w)
        test.add_config(
            name = config_name,
            generics = dict(g_in_en=i_e,g_use_uniNoise_file = use_ns_file,g_nof_points = nop,g_use_reorder=r_ord,g_in_dat_w=i_d_w,g_out_dat_w=o_d_w,g_guard_w=g_w)
        )
        
use_noise_file, in_en, use_reord, nof_pts, i_d_w, o_d_w, g_w= True, [1,0], [True,False], 1024,8,14,2 
lib1 = vu.add_library("r2sdf_fft_lib")
lib1.add_source_files("*.vhd")
TB_GENERATED = lib1.test_bench("tb_rTwoSDF")
generate_tests(TB_GENERATED,in_en,use_noise_file,nof_pts,use_reord,i_d_w,o_d_w,g_w)

lib2 = vu.add_library("common_pkg_lib")
lib2.add_source_files("../casper_common_pkg/*.vhd")

lib3 = vu.add_library("common_components_lib")
lib3.add_source_files("../casper_common_components/*.vhd")

lib4 = vu.add_library("casper_counter_lib")
txt = glob.glob("../casper_counter/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb"):
        lib4.add_source_files("../casper_counter/"+s)

lib5 = vu.add_library("casper_ram_lib")
txt = glob.glob("../casper_ram/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb" and s != "tech_memory_ram_crwk_crw.vhd" and s != "common_ram_crw_crw_ratio.vhd"):
        lib5.add_source_files("../casper_ram/"+s)

lib6 = vu.add_library("casper_multiplier_lib")
txt = glob.glob("../casper_multiplier/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb"):
        lib6.add_source_files("../casper_multiplier/"+s)

lib7 = vu.add_library("casper_adder_lib")
txt = glob.glob("../casper_adder/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb"):
        lib7.add_source_files("../casper_adder/"+s)

lib8 = vu.add_library("casper_requantize_lib")
txt = glob.glob("../casper_requantizer/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb" and s !="dp_requantize.vhd"):
        lib8.add_source_files("../casper_requantizer/"+s)
        
#Create library 'ip_xilinx_ram_lib'
lib9 = vu.add_library("ip_xilinx_ram_lib",allow_duplicate=True)
txt = glob.glob("../ip_xilinx_ram/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb"):
        lib9.add_source_files("../ip_xilinx_ram/"+s)
        
#Create library 'ip_xilinx_mult_lib'
lib10 = vu.add_library("ip_xilinx_mult_lib",allow_duplicate=True)
txt = glob.glob("../ip_xilinx_mult/*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s[-7:-4] != "_tb"):
        lib10.add_source_files("../ip_xilinx_mult/"+s)

# Run vunit function
vu.main()