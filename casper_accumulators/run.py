from vunit import VUnit
from os.path import dirname, join
from itertools import product
import numpy as np

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
script_dir = dirname(__file__)

# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_files(join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_files(join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# Create library 'casper_counter_lib'
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_files(join(script_dir,"../casper_counter/common_counter.vhd"))
casper_counter_lib.add_source_files(join(script_dir,"../casper_counter/free_run_up_counter.vhd"))

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

# Create library 'ip_xpm_ram_lib'
ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)
# CASPER adder library
casper_adder_lib = vu.add_library("casper_adder_lib")
casper_adder_lib.add_source_file(join(script_dir, "../casper_adder/common_add_sub.vhd"))

# COMMON COMPONENTS Library 
common_components_lib = vu.add_library("common_components_lib")
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline_sl.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_delay.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_components_pkg.vhd"))

# Create library 'casper_ram_lib'
casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_files(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))

# Create library 'technology_lib'
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# Create library 'casper_delay_lib'
casper_delay_lib = vu.add_library("casper_delay_lib")
casper_delay_lib.add_source_file(join(script_dir, "../casper_delay/delay_bram.vhd"))

# MISC Library compile
casper_misc_lib = vu.add_library("casper_misc_lib")
casper_misc_lib.add_source_files(join(script_dir, "../misc/pulse_ext.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "../misc/edge_detect.vhd"))

# Accumulator Library
casper_accumulator_lib = vu.add_library("casper_accumulator_lib")
casper_accumulator_lib.add_source_files(join(script_dir, "./addr_bram_vacc.vhd"))
casper_accumulator_lib.add_source_files(join(script_dir, "./tb_addr_bram_vacc.vhd"))
casper_accumulator_lib.add_source_files(join(script_dir, "./tb_tb_addr_bram_vacc.vhd"))

TB_ADDR_BRAM_VACC = casper_accumulator_lib.test_bench("tb_tb_vu_addr_bram_vacc")

# Generics
bit_w = [8,18]
ramp = np.arange(16)
rampstr = ",".join(map(str, ramp))
randnums= np.random.randint(-100,100,32)
randstr =  ",".join(map(str, randnums))

for b_w in bit_w:
    vector_len = ramp.size
    config_name = "TB_ADDR_BRAM_VACC: bit_w=%d, vec_len=%d, strvalue=%s..." % (b_w,vector_len,rampstr[0:8])
    TB_ADDR_BRAM_VACC.add_config(
        name=config_name,
        generics=dict(
            g_bit_w=b_w,
            g_values=rampstr,
            g_vector_length=vector_len
        )
    )
    vector_len = randnums.size
    config_name = "TB_ADDR_BRAM_VACC: bit_w=%d, vec_len=%d, strvalue=%s..." % (b_w,vector_len,randstr[0:8])
    TB_ADDR_BRAM_VACC.add_config(
        name=config_name,
        generics=dict(
            g_bit_w=b_w,
            g_values=randstr,
            g_vector_length=vector_len
        )
    )

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide", "-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.main()