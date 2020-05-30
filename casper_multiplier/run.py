from vunit import VUnit
import glob
# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'casper_multiplier_lib'
lib1 = vu.add_library("casper_multiplier_lib")
lib1.add_source_files("*.vhd")

# Create library 'common_components_lib'
lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files("../casper_common_components/*.vhd")

# Create library 'casper_common_pkg_lib'
lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files("../casper_common_pkg/*.vhd")

#Create library 'ip_xilinx_mult_lib'
lib4 = vu.add_library("ip_xilinx_mult_lib",allow_duplicate=True)
inputtxt = glob.glob("../ip_xilinx_mult/*.vhd")
for i in inputtxt:
    if(i[-7:-4] != "_tb"):
        lib4.add_source_files(i)
       

# Run vunit function
vu.main()
