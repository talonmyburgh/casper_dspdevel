from vunit import VUnit
import os, glob

# Create VUnit instance by parsing command line arguments
script_dir = os.path.dirname(__file__)

vu = VUnit.from_argv()

lib = vu.add_library("xpm")
lib.add_source_files(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib.add_source_file(os.path.join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

lib0 = vu.add_library("altera_mf")
lib0.add_source_files(os.path.join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib0.add_source_files(os.path.join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

lib1 = vu.add_library("casper_ram_lib")
lib1.add_source_files(os.path.join(script_dir, "./*.vhd"))

TB_GENERATED = lib1.test_bench("tb_tb_vu_common_paged_ram_crw_crw")
TB_GENERATED.add_config(name="common_paged_ram_crw_crw_test")

lib2 = vu.add_library("common_components_lib")
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_pipeline.vhd"))

lib3 = vu.add_library("common_pkg_lib")
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/common_pkg.vhd"))
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/tb_common_pkg.vhd"))

lib4 = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = lib4.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = lib4.add_source_files(os.path.join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

lib5 = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = lib5.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = lib5.add_source_file(os.path.join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

lib6 = vu.add_library("technology_lib",allow_duplicate = True)
lib6.add_source_files(os.path.join(script_dir, "../technology/technology_select_pkg.vhd"))

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide", "-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.main()