import os
import random
from itertools import product
from vunit import VUnit

def generate_tests(obj,
pipeline_demux_in = [0,1],
pipeline_demux_out = [0,1,2],
nof_streams = [1,4,5],
pipeline_mux_in = [0,1,3],
pipeline_mux_out = [0,1,4],
dat_w = [8],
random_in_val = [True],
test_nof_cycles = 500000):
    """
    Generate test by varying the generics of casper_adder:
      pipeline_demux_in 	: NATURAL {0,1}
      pipeline_demux_out 	: NATURAL {0,1,2}
      nof_streams 				: NATURAL {1,4,5}
      pipeline_mux_in 		: NATURAL {0,1,3}
      pipeline_mux_out 		: NATURAL {0,1,4}
      dat_w 							: NATURAL {8}
      random_in_val 			: BOOLEAN {TRUE}
      test_nof_cycles 		: NATURAL {500000}
    """

    for pipe_demux_in, pipe_demux_out, nof_strms, pipe_mux_in, pipe_mux_out, d_w, random_val in product(
        pipeline_demux_in, pipeline_demux_out, nof_streams, pipeline_mux_in, pipeline_mux_out, dat_w, random_in_val
        ):
      config_name = 'pipe_demux_in = {} pipe_demux_out = {} nof_strms = {} pipe_mux_in = {} pipe_mux_out = {} d_w = {} random_val = {} nof_cycles = {}'.format(
        pipe_demux_in, pipe_demux_out, nof_strms, pipe_mux_in, pipe_mux_out, d_w, random_val, test_nof_cycles
      )

      obj.add_config(
          name = config_name,
          generics=dict(
            g_pipeline_demux_in=pipe_demux_in,
            g_pipeline_demux_out=pipe_demux_out,
            g_nof_streams=nof_strms,
            g_pipeline_mux_in=pipe_mux_in,
            g_pipeline_mux_out=pipe_mux_out,
            g_dat_w=d_w,
            g_random_in_val=random_val,
            g_test_nof_cycles=test_nof_cycles)
      )

vu = VUnit.from_argv()

script_dir = os.path.dirname(__file__)

lib1 = vu.add_library("casper_multiplexer_lib")
lib1.add_source_files(os.path.join(script_dir, "common_multiplexer.vhd"))
lib1.add_source_files(os.path.join(script_dir, "common_demultiplexer.vhd"))
lib1.add_source_files(os.path.join(script_dir, "tb_common_multiplexer.vhd"))
lib1.add_source_files(os.path.join(script_dir, "tb_tb_vu_common_multiplexer.vhd"))
TB_GENERATED = lib1.test_bench("tb_tb_vu_common_multiplexer")

generate_tests(TB_GENERATED,
pipeline_demux_in = random.sample([0,1], 1),
pipeline_demux_out = random.sample([0,1,2], 1),
nof_streams = random.sample([1,4,5], 1),
pipeline_mux_in = random.sample([0,1,3], 1),
pipeline_mux_out = random.sample([0,1,4], 1),
dat_w = [8] + random.sample(range(9, 19), 1),
random_in_val = [True],
test_nof_cycles = 500)


lib2 = vu.add_library("common_components_lib")
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_components_pkg.vhd"))
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_select_symbol.vhd"))
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_pipeline.vhd"))
lib2.add_source_files(os.path.join(script_dir, "../common_components/common_pipeline_sl.vhd"))

lib3 = vu.add_library("common_pkg_lib")
lib3.add_source_files(os.path.join(script_dir, "../common_pkg/*.vhd"))

vu.set_compile_option("ghdl.a_flags", ["-Wno-hide"])
vu.main()