from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'casper_multiplier_lib'
lib1 = vu.add_library("casper_multiplier_lib")

# Add all files ending in .vhd in current working directory to library
lib1.add_source_files("*.vhd")

# Create library 'casper_common_components_lib'
lib2 = vu.add_library("common_components_lib",allow_duplicate=True)
lib2.add_source_files("../casper_common_components/*.vhd")

# Create library 'casper_common_pkg_lib'
lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files("../casper_common_pkg/*.vhd")

# Run vunit function
vu.main()
