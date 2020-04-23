from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'casper_common_counter_lib'
cntlib = vu.add_library("casper_common_counter_lib")

# Add all files ending in .vhd in current working directory to library
cntlib.add_source_files("*.vhd")

pkglib = vu.add_library("common_pkg_lib")

pkglib.add_source_files("../casper_common_pkg/*.vhd")

# Run vunit function
vu.main()
