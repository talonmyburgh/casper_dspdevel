#Author: Talon Myburgh
#Company: Mydon Solutions

from vunit import VUnit
import numpy as np
import itertools
import glob
from os.path import dirname, join, abspath

# Function for package mangling.
def manglePkg(file_name, line_number, new_line):
    with open(file_name, 'r') as file:
        lines = file.readlines()
    lines[line_number] = new_line
    with open(file_name, 'w') as file:
        lines = file.writelines(lines)


def mapping(aggre, inpts):
    mult_map = {}
    mult = 0
    for a in range(aggre):
        aa = a * inpts
        for s in range(aa, aa + inpts):
            for ss in range(s, aa + inpts):
                mult_map[mult] = (s, ss)
                mult += 1
    return mult_map

def cross_mult(c_val_dict):
    ans_dict = {}
    for test, val in c_val_dict.items():
        tests = test.split(':')
        aggregations = int(tests[1])
        streams = int(tests[0])
        nof_cmults = aggregations * int(((streams +1)*streams)/2)
        answers = np.zeros(nof_cmults,dtype=np.complex64)
        mult_map = mapping(aggregations,streams)
        for ans in range(nof_cmults):
            a = val[mult_map[ans][0]]
            b = np.conj(val[mult_map[ans][1]])
            answers[ans] = val[mult_map[ans][0]] * np.conj(val[mult_map[ans][1]])
        ans_dict[test] = answers
    return ans_dict

def turn_cint_to_int(number:complex, cin_bwidth:int):
    if number.real >= 0:
        real = int(number.real)
    else:
        real = int(number.real) + 2**32
    
    if number.imag >= 0:
        imag = int(number.imag)
    else:
        imag = int(number.imag) + 2**32
    real_binary = bin(real & (2**cin_bwidth - 1))[2:].zfill(cin_bwidth)
    imag_binary = bin(imag & (2**cin_bwidth - 1))[2:].zfill(cin_bwidth)
    binary = real_binary + imag_binary
    return int(binary, 2)

def split_int_gen_complexint(number, bitwidth):
    if number < 0:
        number += 2**32
    binary = bin(number & (2**bitwidth-1))[2:].zfill(bitwidth)
    first_half = binary[:bitwidth//2]
    second_half = binary[bitwidth//2:]
    if first_half:
        first_int = int(first_half, 2)
        if first_int >= 2**(bitwidth//2-1):
            first_int -= 2**(bitwidth//2)
    else:
        first_int = 0
    if second_half:
        second_int = int(second_half, 2)
        if second_int >= 2**(bitwidth//2-1):
            second_int -= 2**(bitwidth//2)
    else:
        second_int = 0
    return first_int + second_int*1j

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir =  abspath(dirname(__file__))

aggregations = np.random.randint(2 , 4, 1)
streams = np.random.randint(2, 14, 1)
# aggregations = np.array([2])
# streams = np.array([3])
# inpt_bitwidths = np.array([4])
inpt_bitwidths = int(np.random.randint(2, 10, 1))

package_vals = [f'  CONSTANT c_cross_mult_nof_input_streams : NATURAL := {int(streams)};\n',
f'  CONSTANT c_cross_mult_aggregation_per_stream : NATURAL := {int(aggregations)};\n',
f'  CONSTANT c_cross_mult_input_bit_width : NATURAL := {int(inpt_bitwidths)};\n',
f'  CONSTANT c_cross_mult_output_bit_width : NATURAL := {2*int(inpt_bitwidths)+1};\n']

manglePkg(join(script_dir,'correlator_pkg.vhd'), slice(5,9),package_vals)

# COMMON COMPONENTS Library 
common_components_lib = vu.add_library("common_components_lib",allow_duplicate=True)
common_components_lib.add_source_files(script_dir + "/../common_components/common_pipeline.vhd")
common_components_lib.add_source_files(script_dir + "/../common_components/common_pipeline_sl.vhd")

# COMMON PACKAGE Library
common_pkg_lib = vu.add_library("common_pkg_lib",allow_duplicate = True)
common_pkg_lib.add_source_files(script_dir + "/../common_pkg/*.vhd")
common_pkg_lib.add_source_files(script_dir + "/../common_pkg/tb_common_pkg.vhd")

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib",allow_duplicate = True)
technology_lib.add_source_files(script_dir + "/../technology/technology_select_pkg.vhd")

# XPM Multiplier library
ip_xpm_mult_lib = vu.add_library("ip_xpm_mult_lib", allow_duplicate=True)
ip_xpm_mult_lib.add_source_files(script_dir + "/../ip_xpm/mult/*.vhd")

# STRATIXIV Multiplier library
ip_stratixiv_mult_lib = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
ip_stratixiv_mult_lib.add_source_files(script_dir + "/../ip_stratixiv/mult/*rtl.vhd")

# CASPER MUlTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib")
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))
tech_complex_mult = casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_agilex_versal_cmult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/cmult.vhd"))

# CASPER CORRELATOR Library
casper_correlator_lib = vu.add_library("casper_correlator_lib",allow_duplicate=True)
casper_correlator_lib.add_source_files(join(script_dir,'*.vhd'))

TB_GENERATED = casper_correlator_lib.test_bench("tb_tb_vu_cross_multiplier")

value_dict = {}
# Here we generate the test values. Note that these values are all taken as complex where real and imag are join (i.e. 85 = 5+5j)
for s, a in itertools.product(streams, aggregations):
    print(f"""
        Generating test for values:
        bitwidth = {inpt_bitwidths}
        nof streams = {s}
        nof aggregations = {a}""")
    max_val = int(2**(2*inpt_bitwidths) -1)
    min_val = 0
    value_dict[f"{s}:{a}"] = np.random.randint(min_val, max_val, size=(s,a))

generics_dict = {}
#Turn this into strings so they can be passed to generic g_values
for key,val in value_dict.items():
    strval = ', '.join(map(str, val.flatten()))
    generics_dict[key] = strval

#Here we must construct the complex values for testing
c_dict = {}
for key,val in value_dict.items():
    values = val.flatten(order = 'F') #now we've flattened across aggregations which is how the module works and what the mapping expects
    c_val = np.zeros(values.shape, dtype=np.complex64)
    for i,v in enumerate(values):
        c_val[i] =  split_int_gen_complexint(int(v),2*int(inpt_bitwidths))
    c_dict[key] = c_val

cross_mult_result = cross_mult(c_dict)
result_dict = {}
for test, val in cross_mult_result.items():
    tests = test.split(':')
    stream = int(tests[0])
    aggre = int(tests[1])
    int_val = np.zeros(val.shape,dtype=np.int64)
    for i,v in enumerate(val):
        int_val[i] = turn_cint_to_int(v ,2*int(inpt_bitwidths) + 1)
    result_dict[test] = int_val.reshape(int_val.size//aggre,aggre)

generics_result = {}
#convert result dict to set of strings for generics:
for key, result in result_dict.items():
    strval = ', '.join(map(str, result.flatten()))
    generics_result[key] = strval

for key, val in generics_dict.items():
    vals = key.split(':')
    streams = int(vals[0])
    aggregations = int(vals[1])
    config_name = f"Streams={streams},Aggregations={aggregations},inputbitwidth={inpt_bitwidths}"
    TB_GENERATED.add_config(
        name = config_name,
        generics = {
            'g_values' : val,
            'g_results' : generics_result[key]
        }
    )

print(generics_dict)

print(generics_result)

# RUN
vu.set_compile_option("ghdl.a_flags", ["-frelaxed", "-Wno-hide"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","--syn-binding"])
vu.main()
