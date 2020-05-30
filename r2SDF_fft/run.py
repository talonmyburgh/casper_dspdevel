from vunit import VUnit
import glob
from itertools import product

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

def generate_tests(test,use_noise_file, in_en, reorder, nof_pts, in_dat_w,out_dat_w,guard_w):
    """
    Generate test by varying the generics of rTwoSDF_tb:
        g_use_uniNoise_file : boolean
        g_in_en             : natural
        g_use_reorder       : boolean 
        g_nof_points        : natural
        g_in_dat_w          : natural   
        g_out_dat_w         : natural
        g_guard_w           : natural
    """

    for nsfile, i_e,r_ord,nop,i_d_w,o_d_w,g_w in product(use_noise_file, in_en, reorder, nof_pts, in_dat_w,out_dat_w,guard_w):
        config_name1 = "Noise file used = %s, in_en = %s, use_reorder = %i, nof_points = %i, in_dat_w = %i, out_dat_w = %i, guard_bits = %i" % (nsfile, i_e,r_ord,nop,i_d_w,o_d_w,g_w)
        print(config_name1)
        test.add_config(
            name = config_name1,
            generics=dict(g_use_uniNoise_file=nsfile,g_in_en=i_e,g_use_reorder=r_ord,
             g_nof_points=nop, g_in_dat_w=i_d_w,g_out_dat_w=o_d_w,g_guard_w = g_w)
        )

# Create library 'lib'
lib1 = vu.add_library("r2sdf_fft_lib")
lib1.add_source_files("*.vhd")
TB_GENERATED = lib1.test_bench("tb_rTwoSDF")
generate_tests(TB_GENERATED, [True],[1,0],[True,False],[1024],[8,10],[14,18],[2])

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
