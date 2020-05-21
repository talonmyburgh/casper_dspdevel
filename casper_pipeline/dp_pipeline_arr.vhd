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
--   Pipeline array of g_nof_streams by g_pipeline cycles.
-- Description:
--   See dp_pipeline.

ENTITY dp_pipeline_arr IS
  GENERIC (
    g_nof_streams : NATURAL := 1;
    g_pipeline    : NATURAL := 1  -- 0 for wires, > 0 for registers, 
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- ST sink
    snk_out_arr  : OUT t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);
    snk_in_arr   : IN  t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);
    -- ST source
    src_in_arr   : IN  t_dp_siso_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_siso_rdy);
    src_out_arr  : OUT t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0)
  );
END dp_pipeline_arr;


ARCHITECTURE str OF dp_pipeline_arr IS

BEGIN

  gen_nof_streams : FOR I IN 0 TO g_nof_streams-1 GENERATE
    u_p : ENTITY work.dp_pipeline
    GENERIC MAP (
      g_pipeline => g_pipeline
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => snk_out_arr(I),
      snk_in       => snk_in_arr(I),
      -- ST source
      src_in       => src_in_arr(I),
      src_out      => src_out_arr(I)
    );
  END GENERATE;
  
END str;
