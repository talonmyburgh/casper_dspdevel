from vunit import VUnit
import glob

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
lib1 = vu.add_library("casper_ram_lib")
txt = glob.glob("*.vhd")
for x in txt:
    s = x.split('/')[-1]
    if(s != "ip_sdp_ram_infer_tb.vhd" and s!="ip_tdp_ram_infer_tb.vhd" and s!= "tech_memory_ram_crwk_crw.vhd" and s!= "common_ram_crw_crw_ratio.vhd"
    and s!= "altera_mf.vhd" and s!= "altera_mf_components.vhd" and s!= "ip_stratixiv_ram_cr_cw.vhd" and s!= "ip_stratixiv_ram_crw_crw.vhd" and s!= "ip_stratixiv_ram_crwk_crw.vhd"):
        lib1.add_source_files(s)

lib2 = vu.add_library("common_components_lib")
lib2.add_source_files("../casper_common_components/*.vhd")

lib3 = vu.add_library("common_pkg_lib")
lib3.add_source_files("../casper_common_pkg/*.vhd")

# Run vunit function
vu.main()