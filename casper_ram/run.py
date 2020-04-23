from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib1 = vu.add_library("casper_ram_lib")

# Add all files ending in .vhd in current working directory to library
lib1.add_source_files("*.vhd")

lib5 = vu.add_library("ip_xilinx_ram_lib")
lib5.add_source_files("../ip_xilinx_ram/*.vhd")

lib2 = vu.add_library("common_components_lib")
lib2.add_source_files("../casper_common_components/*.vhd")

lib3 = vu.add_library("common_pkg_lib")
lib3.add_source_files("../casper_common_pkg/*.vhd")

#lib6 = vu.add_library("altera_mf_lib")
#lib6.add_source_files("../altera_mf/*.vhd")

#lib4 = vu.add_library("ip_stratixiv_ram_lib")
#lib4.add_source_files("../ip_stratixiv_ram/*.vhd")

# Run vunit function
vu.main()
