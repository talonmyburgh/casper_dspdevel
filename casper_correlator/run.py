#Author: Talon Myburgh
#Company: Mydon Solutions

from vunit import VUnit
import numpy as np
import itertools
import glob
from os.path import dirname, join, abspath

def mapping(aggre, inpts):
    mult_map = {}
    mult = 0
    for a in range(aggre):
        aa = a * inpts
        for s in range(aa, aa + inpts):
            for ss in range(s, aa + inpts):
        #         print(s,' ', ss)
                mult_map[mult] = (s, ss)
                mult += 1
    return mult_map

def cross_mult(c_val_dict):
    ans_dict = {}
    for test, val in c_val_dict.items():
        aggregations = int(test[1])
        streams = int(test[0])
        nof_cmults = aggregations * int(((streams +1)*streams)/2)
        answers = np.zeros(nof_cmults,dtype=np.complex64)
        mult_map = mapping(aggregations,streams)
        for ans in range(nof_cmults):
            a = val[mult_map[ans][0]]
            b = np.conj(val[mult_map[ans][1]])
            print(f"Multiplying: a = {a}, b = {b}")
            answers[ans] = val[mult_map[ans][0]] * np.conj(val[mult_map[ans][1]])
        ans_dict[test] = answers
    return ans_dict

def turn_cint_to_int(number:complex):
    real = int(number.real)
    imag = int(number.imag)
    real_binary = bin(int(number.real))[2:] if real >=0 else bin(int(number.real))[3:] 
    imag_binary = bin(int(number.imag))[2:] if imag >=0 else bin(int(number.imag))[3:]
    binary = real_binary + imag_binary
    return int(binary, 2)

def split_int_gen_complexint(number, bitwidth):
    binary = bin(number & (2**bitwidth-1))[2:].zfill(bitwidth)
    first_half = binary[:bitwidth//2]
    second_half = binary[bitwidth//2:]
    if first_half:
        first_int = int(first_half, 2)
    else:
        first_int = 0
    if second_half:
        second_int = int(second_half, 2)
    else:
        second_int = 0
    if number < 0:
        first_int = -first_int
        second_int = -second_int
    return first_int + second_int*1j

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
script_dir =  abspath(dirname(__file__))
print("file: ", __file__)
print("script dir: ",script_dir)

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

# CASPER MULTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib", allow_duplicate=True)
casper_multiplier_lib.add_source_files(script_dir + "/../casper_multiplier/*.vhd")

# CASPER CORRELATOR Library
casper_correlator_lib = vu.add_library("casper_correlator_lib",allow_duplicate=True)
casper_correlator_lib.add_source_files(join(script_dir,'*.vhd'))

TB_GENERATED = casper_correlator_lib.test_bench("tb_tb_vu_cross_multiplier")

# aggregations = np.random.randint(1 , 6, 1)
# streams = np.random.randint(1, 10, 1)
aggregations = np.array([2])
streams = np.array([3])
# inpt_bitwidths = int(np.random.randint(4, 8, 1))
inpt_bitwidths = np.array([5])

value_dict = {}
#Here we generate the test values. Note that these values are all taken as complex where real and imag are join (i.e. 85 = 5+5j)
# for s, a in itertools.product(streams, aggregations):
#     print(f"""
#         Generating test for values:
#         bitwidth = {inpt_bitwidths}
#         nof streams = {s}
#         nof aggregations = {a}""")
#     max_val = int(2**inpt_bitwidths -1)
#     min_val = int(-2**inpt_bitwidths)
#     value_dict[f"{s}{a}"] = np.random.randint(min_val, max_val, size=(s,a))

value_dict['32'] =np.array([[5,28],[-30,17],[-13,25]])

generics_dict = {}
#Turn this into strings so they can be passed to generic g_values
for key,val in value_dict.items():
    rows = int(key[0])
    columns = int(key[1])
    strval = ""
    for s in range(rows):
        col_str = ""
        for a in range(columns):
            col_str = ', '.join(map(str, val[s,:]))
        strval += col_str + "; " if s < rows - 1 else col_str
    generics_dict[key] = strval

print(generics_dict)
#Here we must construct the complex values for testing
c_dict = {}
for key,val in value_dict.items():
    print(val)
    values = val.flatten(order = 'F') #now we've flattened across aggregations which is how the module works and what the mapping expects
    print(values)
    c_val = np.zeros(values.shape, dtype=np.complex64)
    for i,v in enumerate(values):
        c_val[i] =  split_int_gen_complexint(int(v),int(inpt_bitwidths))
    c_dict[key] = c_val

print(c_dict)
cross_mult_result = cross_mult(c_dict)
result_dict = {}
for test, val in cross_mult_result.items():
    stream = int(test[0])
    aggre = int(test[1])
    int_val = np.zeros(val.shape,dtype=np.int64)
    for i,v in enumerate(val):
        int_val[i] = turn_cint_to_int(v)
    result_dict[test] = int_val.reshape(int_val.size//aggre,aggre)

generics_result = {}
#convert result dict to set of strings for generics:
for key, result in result_dict.items():
    streams, aggre = result.shape
    strval = ""
    for s in range(streams):
        col_str = ""
        for a in range(aggre):
            col_str = ', '.join(map(str, result[s,:]))
        strval += col_str + "; " if s < streams - 1 else col_str
    generics_result[key] = strval
print(generics_result)

