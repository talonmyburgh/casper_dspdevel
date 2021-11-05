from vunit import VUnit
import os

# Create VUnit instance by parsing command line arguments
script_dir = os.path.dirname(__file__)

vu = VUnit.from_argv()

lib = vu.add_library("xpm")
lib.add_source_files(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
lib.add_source_files(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/*.vhd"))

# lib0 = vu.add_library("altera_mf")
# lib0.add_source_files(os.path.join(script_dir, "../intel/altera_mf/*.vhd"))

lib1 = vu.add_library("casper_ram_lib")
lib1.add_source_files(os.path.join(script_dir, "./*.vhd"))

TB_GENERATED = lib1.test_bench("tb_tb_vu_common_paged_ram_crw_crw")
TB_GENERATED.add_config(name = "common_paged_ram_crw_crw_test")

lib2 = vu.add_library("common_components_lib")
lib2.add_source_files(os.path.join(script_dir, "../common_components/*.vhd"))

lib3 = vu.add_library("common_pkg_lib")
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/*.vhd"))

lib4 = vu.add_library("ip_xpm_ram_lib")
lib4.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/*.vhd"))

lib5 = vu.add_library("ip_stratixiv_ram_lib")
lib5.add_source_files(os.path.join(script_dir, "../ip_stratixiv/ram/*.vhd"))

lib6 = vu.add_library("technology_lib",allow_duplicate = True)
lib6.add_source_files(os.path.join(script_dir, "../technology/technology_select_pkg.vhd"))


vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.main()