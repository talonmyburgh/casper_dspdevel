-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Purpose:
--   Pipeline the source output by one cycle or by g_pipeline cycles.
-- Description:
--   The dp_pipeline instantiates 0:g_pipeline stages of dp_pipeline_one.
--   The dp_pipeline_one provides a single clock cycle delay of the source
--   output (i.e. sosi). The dp_pipeline_one holds valid sink input in case
--   src_in.ready goes low and makes src_out.valid high again when
--   src_in.ready goes high again, without the need for a valid sink input to
--   push this held data out.
--   The dp_pipeline delays the data, sop, eop by one cycle relative to the
--   valid. However the src_out.valid still has the same phase as the
--   snk_in.valid, because both valids depends on the same src_in.ready.
--   Therefore dp_pipeline cannot be used to delay the valid phase by one
--   cycle. Hence the may purpose of dp_pipeline is to register the sosi.
-- Remarks:
-- . Ready latency = 1
-- . Without flow control so when src_in.ready = '1' fixed, then the hold
--   logic in dp_pipeline becomes void and dp_pipeline then just pipelines the
--   snk_in sosi.

ENTITY dp_pipeline IS
  GENERIC (
    g_pipeline   : NATURAL := 1  -- 0 for wires, > 0 for registers, 
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- ST sink
    snk_out      : OUT t_dp_siso;
    snk_in       : IN  t_dp_sosi;
    -- ST source
    src_in       : IN  t_dp_siso := c_dp_siso_rdy;
    src_out      : OUT t_dp_sosi
  );
END dp_pipeline;


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ENTITY dp_pipeline_one IS
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- ST sink
    snk_out      : OUT t_dp_siso;
    snk_in       : IN  t_dp_sosi;
    -- ST source
    src_in       : IN  t_dp_siso := c_dp_siso_rdy;
    src_out      : OUT t_dp_sosi
  );
END dp_pipeline_one;


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ARCHITECTURE str OF dp_pipeline IS

  SIGNAL snk_out_arr      : t_dp_siso_arr(0 TO g_pipeline);
  SIGNAL snk_in_arr       : t_dp_sosi_arr(0 TO g_pipeline);
  
BEGIN

  -- Input at index 0
  snk_out       <= snk_out_arr(0);
  snk_in_arr(0) <= snk_in;
  
  -- Output at index g_pipeline
  snk_out_arr(g_pipeline) <= src_in;
  src_out                 <= snk_in_arr(g_pipeline);
  
  gen_p : FOR I IN 1 TO g_pipeline GENERATE
    u_p : ENTITY work.dp_pipeline_one
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => snk_out_arr(I-1),
      snk_in       => snk_in_arr(I-1),
      -- ST source
      src_in       => snk_out_arr(I),
      src_out      => snk_in_arr(I)
    );
  END GENERATE;
  
END str;


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, dp_components_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ARCHITECTURE str OF dp_pipeline_one IS

  SIGNAL nxt_src_out      : t_dp_sosi;
  SIGNAL i_src_out        : t_dp_sosi;
  
BEGIN

  src_out <= i_src_out;

  -- Pipeline register
  p_clk : PROCESS(rst, clk)
  BEGIN
    IF rst='1' THEN
      i_src_out <= c_dp_sosi_rst;
    ELSIF rising_edge(clk) THEN
      i_src_out <= nxt_src_out;
    END IF;
  END PROCESS;
  
  -- Input control
  u_hold_input : ENTITY dp_components_lib.dp_hold_input
  PORT MAP (
    rst              => rst,
    clk              => clk,
    -- ST sink
    snk_out          => snk_out,
    snk_in           => snk_in,
    -- ST source
    src_in           => src_in,
    next_src_out     => nxt_src_out,
    pend_src_out     => OPEN,
    src_out_reg      => i_src_out
  );  
    
END str;
