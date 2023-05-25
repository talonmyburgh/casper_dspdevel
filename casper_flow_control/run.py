from vunit import VUnit
from os.path import dirname, join
import random

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()
script_dir = dirname(__file__)

# Create library 'common_pkg_lib'
common_pkg_lib = vu.add_library("common_pkg_lib")
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))

# Create library 'casper_flow_control_lib'
casper_flow_control_lib = vu.add_library("casper_flow_control_lib")
casper_flow_control_lib.add_source_files(join(script_dir, "./*.vhd"))

TB_MUNGE = casper_flow_control_lib.test_bench("tb_tb_vu_munge")
TB_BUS_EXPAND = casper_flow_control_lib.test_bench("tb_tb_vu_bus_expand")
TB_BUS_CREATE = casper_flow_control_lib.test_bench("tb_tb_vu_bus_create")

slice_bit_widths = [1, 4, 18]
slice_counts = [1, 19]

for count in slice_counts:
    for bit_width in slice_bit_widths:
        slice_values = random.choices(range(0, (2**bit_width)-1), k=count)
        slice_order = random.sample(range(0, count), count)

        slice_order_encoded = ",".join(map(str, slice_order))
        slice_values_encoded = ",".join(map(str, slice_values))

        config_name = "slice_bit_width=%s, slice_count=%s" %(bit_width, count)
        TB_MUNGE.add_config(
            name = config_name,
            generics=dict(
                g_number_of_divisions=count,
                g_division_size_bits=bit_width,
                g_order = slice_order_encoded,
                g_values = slice_values_encoded
            )
        )
    
    config_name = "expansion_count=%s" %(count)
    TB_BUS_EXPAND.add_config(
        name = config_name,
        generics=dict(
            g_values = slice_values_encoded
        )
    )
    
    config_name = "concat_count=%s" %(count)
    TB_BUS_CREATE.add_config(
        name = config_name,
        generics=dict(
            g_values = slice_values_encoded
        )
    )

config_name = "Repeated division."
TB_MUNGE.add_config(
    name = config_name,
    generics=dict(
        g_number_of_divisions=4,
        g_division_size_bits=2,
        g_order = "3,3,3,3",
        g_values = "0,0,0,3"
    )
)

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide", "-frelaxed","-fsynopsys","-fexplicit"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.main()
