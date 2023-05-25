import os
from vunit import VUnit            

vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()
script_dir = os.path.dirname(__file__)

lib1 = vu.add_library("tb_lib",allow_duplicate=True)
lib1.add_source_files(os.path.join(script_dir, "common_fifo_rd.vhd"))
lib1.add_source_files(os.path.join(script_dir, "tb_common_fifo_rd.vhd"))
lib1.add_source_files(os.path.join(script_dir, "tb_tb_vu_common_fifo_rd.vhd"))
lib1.add_source_files(os.path.join(script_dir, "../casper_fifo/common_rl_decrease.vhd"))
TB_GENERATED = lib1.test_bench("tb_tb_vu_common_fifo_rd")

TB_GENERATED.add_config(
				name = "random",
				generics=dict(g_random_control=True)
		)


lib2 = vu.add_library("common_components_lib",allow_duplicate = True)
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_areset.vhd"))
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_async.vhd"))

lib3 = vu.add_library("common_pkg_lib",allow_duplicate = True)
lib3.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
lib3.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
lib3.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/*.vhd"))

lib5 = vu.add_library("dp_pkg_lib",allow_duplicate = True)
lib5.add_source_files(os.path.join(script_dir, "../casper_dp_pkg/*.vhd"))

lib6 = vu.add_library("dp_components_lib",allow_duplicate = True)
lib6.add_source_files(os.path.join(script_dir, "../casper_dp_components/dp_latency_adapter.vhd"))
lib6.add_source_files(os.path.join(script_dir, "../casper_dp_components/dp_latency_increase.vhd"))

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide"])
vu.main()