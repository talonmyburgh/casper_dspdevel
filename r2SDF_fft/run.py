from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib1 = vu.add_library("r2sdf_fft_lib")

# Add all files ending in .vhd in current working directory to library
lib1.add_source_files("*.vhd")

lib2 = vu.add_library("common_pkg_lib")
lib2.add_source_files("../casper_common_pkg/*.vhd")

lib3 = vu.add_library("common_components_lib")
lib3.add_source_files("../casper_common_components/*.vhd")

lib4 = vu.add_library("casper_counter_lib")
lib4.add_source_files("../casper_counter/*.vhd")

lib5 = vu.add_library("casper_ram_lib")
lib5.add_source_files("../casper_ram/*.vhd")

lib6 = vu.add_library("casper_multiplier_lib")
lib6.add_source_files("../casper_multiplier/*.vhd")

lib7 = vu.add_library("casper_adder_lib")
lib7.add_source_files("../casper_adder/*.vhd")

lib8 = vu.add_library("casper_requantize_lib")
lib8.add_source_files("../casper_requantizer/*.vhd")

# Run vunit function
vu.main()
