from vunit import VUnit
from os.path import join, abspath, split,realpath,dirname
import numpy as np
from itertools import product
import random

def concat_re_im(re, im):
    return (re << 16) | im

def split_re_im(val):
    return (val >> 16) & 0xFFFF, val & 0xFFFF

def a_plus_b(a, b):
    """
    A and B are complex numbers where
    If a = w + ix, b = y + iz then 
    a+b = (w+y)/2 + i(x+z)/2 
    """
    return round((a.real + b.real) / 2), round((a.imag + b.imag) / 2)

def a_minus_b(a, b):
    """
    A and B are complex numbers where
    If a = w + ix, b = y + iz then 
    a-b = (w-y)/2 + i(x-z)/2 
    """
    return round((a.real - b.real) / 2), round((a.imag - b.imag) / 2)

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir,_ = split(abspath(__file__))

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_str_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

# Create library 'common_components_lib'
common_components_lib = vu.add_library("common_components_lib")
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline_sl.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib",allow_duplicate = True)
technology_lib.add_source_files(script_dir + "/../technology/technology_select_pkg.vhd")

# XPM Multiplier library
ip_xpm_mult_lib = vu.add_library("ip_xpm_mult_lib", allow_duplicate=True)
ip_xpm_mult_lib.add_source_files(script_dir + "/../ip_xpm/mult/*.vhd")

# STRATIXIV Multiplier library
ip_stratixiv_mult_lib = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
ip_stratixiv_mult_lib.add_source_files(script_dir + "/../ip_stratixiv/mult/*rtl.vhd")

# Multiplier Library
mult_lib = vu.add_library("casper_multiplier_lib")
mult_lib.add_source_files(join(script_dir, "../casper_multiplier/common_mult.vhd"))
mult_lib.add_source_files(join(script_dir, "../casper_multiplier/tech_mult.vhd"))
mult_lib.add_source_files(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))

# Create library 'casper_counter_lib'
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_file(join(script_dir,"../casper_counter/free_run_counter.vhd"))
casper_counter_lib.add_source_file(join(script_dir, "../casper_counter/common_counter.vhd"))

# Create library 'casper_adder_lib'
casper_adder_lib = vu.add_library("casper_adder_lib")
print(join(script_dir, "../casper_adder/casper_add_sub.vhd"))
casper_adder_lib.add_source_file(join(script_dir,"../casper_adder/common_add_sub.vhd"))

# Creat library 'casper_delay_lib'
casper_delay_lib = vu.add_library("casper_delay_lib")
casper_delay_lib.add_source_files(join(script_dir, "../casper_delay/delay_simple.vhd"))

#MISC Library compile
casper_misc_lib = vu.add_library("casper_misc_lib")
casper_misc_lib.add_source_files(join(script_dir, "./concat.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*ri_to_c.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*c_to_ri.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*bit_reverse.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*edge_detect.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*armed_trigger.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*pulse_ext.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*power.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*freeze_cntr.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*triggered_counter.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*stopwatch.vhd"))
casper_misc_lib.add_source_files(join(script_dir, "./*complex_addsub.vhd"))

RI_TO_C_TB = casper_misc_lib.test_bench("tb_tb_vu_ri_to_c")
C_TO_RI_TB = casper_misc_lib.test_bench("tb_tb_vu_c_to_ri")
BIT_REVERSE = casper_misc_lib.test_bench("tb_tb_vu_bit_reverse")
EDGE_DETECT = casper_misc_lib.test_bench("tb_tb_vu_edge_detect")
ARMED_TRIGGER = casper_misc_lib.test_bench("tb_tb_vu_armed_trigger")
PULSE_EXT = casper_misc_lib.test_bench("tb_tb_vu_pulse_ext")
POWER = casper_misc_lib.test_bench("tb_tb_vu_power")
FREEZE_CNTR = casper_misc_lib.test_bench("tb_tb_vu_freeze_cntr")
TRIGGERED_COUNTER = casper_misc_lib.test_bench("tb_tb_vu_triggered_counter")
STOPWATCH = casper_misc_lib.test_bench("tb_tb_vu_stopwatch")
COMPLEX_ADDSUB = casper_misc_lib.test_bench("tb_tb_vu_complex_addsub")

async_arr = [True, False]
bit_w = [8,18]
input_val = np.random.randint(0, 127, 2).tolist()

for async_val, bit_w_val, input_v in product(async_arr, bit_w, input_val):
    ri_to_c_config_name = "RI_TO_C: async=%r, bit_w=%d, re/im_input_val=%d" % (async_val, bit_w_val, input_v)
    RI_TO_C_TB.add_config(
        name = ri_to_c_config_name,
        generics=dict(g_async = async_val, g_re_in_w = bit_w_val, g_im_in_w = bit_w_val,
        g_re_in_val = input_v, g_im_in_val = input_v)
    )
    c_to_ri_config_name = "C_TO_RI: async=%r, bit_w=%d, input_val=%d" % (async_val, bit_w_val, input_v)
    C_TO_RI_TB.add_config(
        name = c_to_ri_config_name,
        generics=dict(g_async = async_val, g_bit_width = bit_w_val, g_c_in_val = input_v)
    )
    bit_reverse_config_name = "BIT_REVERSE: async=%r, num_bits=%d, input_val=%d" % (async_val, bit_w_val, input_v)
    BIT_REVERSE.add_config(
        name = bit_reverse_config_name,
        generics=dict(g_async = async_val, g_num_bits = bit_w_val, g_in_val = input_v)
    )
for bit_w_val, input_v in product(bit_w, input_val):
    edge_detect_config_name = "EDGE_DETECT: num_bits=%d, input_val=%d" % (bit_w_val, input_v)
    EDGE_DETECT.add_config(
        name = edge_detect_config_name,
        generics=dict(g_dat_w = bit_w_val, g_dat_val = input_v)
    )

for pulse_extension in [1] + random.sample(range(2,10), 1):
    pulse_ext_config_name = "PULSE_EXT: extension=%d" % (pulse_extension)
    PULSE_EXT.add_config(
        name = pulse_ext_config_name,
        generics=dict(g_extension = pulse_extension)
    )

ARMED_TRIGGER.add_config(
    name = "ARMED_TRIGGER"
)

for b_w in bit_w:
    power_config_name = "POWER: bit_w=%d" % (b_w)
    POWER.add_config(
        name = power_config_name,
        generics=dict(g_bit_width_in = b_w,
                      g_value_re = input_val[0],
                      g_value_im = input_val[1])
    )
    freeze_config_name = "FREEZE_CNTR: bit_w=%d" % (b_w)
    FREEZE_CNTR.add_config(
        name = freeze_config_name,
        generics=dict(g_num_cntr_bits = b_w)
    )
    triggered_config_name = "TRIGGERED_COUNTER: run_length=%d" % (b_w)
    TRIGGERED_COUNTER.add_config(
        name = triggered_config_name,
        generics=dict(g_run_length = b_w)
    )
    stopwatch_config_name = "STOPWATCH: num_clocks=%d" % (b_w)
    STOPWATCH.add_config(
        name = stopwatch_config_name,
        generics=dict(g_num_clocks = b_w)
    )

COMPLEX_ADDSUB.add_config(
    name = "COMPLEX_ADDSUB",
    generics=dict(g_a = 119, g_b = 85)
)
    
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])
vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])
vu.main()
