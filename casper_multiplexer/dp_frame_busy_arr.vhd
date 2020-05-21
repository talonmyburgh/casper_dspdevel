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

-- Purpose: Output frame busy control signal for array of streams
-- Description:
--   See dp_frame_busy.

LIBRARY IEEE, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ENTITY dp_frame_busy_arr IS
  GENERIC (
    g_nof_inputs : NATURAL := 1;
    g_pipeline   : NATURAL := 0
  );
  PORT (
    rst             : IN  STD_LOGIC;
    clk             : IN  STD_LOGIC;
    snk_in_arr      : IN  t_dp_sosi_arr(g_nof_inputs-1 DOWNTO 0);
    snk_in_busy_arr : OUT STD_LOGIC_VECTOR(g_nof_inputs-1 DOWNTO 0)
  );
END dp_frame_busy_arr;


ARCHITECTURE str OF dp_frame_busy_arr IS  
BEGIN

  gen_nof_inputs : FOR I IN 0 TO g_nof_inputs-1 GENERATE
    u_dp_frame_busy : ENTITY work.dp_frame_busy
    GENERIC MAP (
      g_pipeline => g_pipeline
    )
    PORT MAP (
      rst         => rst,
      clk         => clk,
      snk_in      => snk_in_arr(I),
      snk_in_busy => snk_in_busy_arr(I)
    );
  END GENERATE;

END str;
