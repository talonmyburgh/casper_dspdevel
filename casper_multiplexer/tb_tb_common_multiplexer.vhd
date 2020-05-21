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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY tb_tb_common_multiplexer IS
END tb_tb_common_multiplexer;

ARCHITECTURE tb OF tb_tb_common_multiplexer IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN
  -- Usage:
  -- > as 3
  -- > run -all

  --  g_pipeline_demux_in  : NATURAL := 1;
  --  g_pipeline_demux_out : NATURAL := 1;
  --  g_nof_streams        : NATURAL := 4;
  --  g_pipeline_mux_in    : NATURAL := 1;
  --  g_pipeline_mux_out   : NATURAL := 1;
  --  g_dat_w              : NATURAL := 8;
  --  g_random_in_val      : BOOLEAN := TRUE;
  --  g_test_nof_cycles    : NATURAL := 500
    
  u_demux_mux_p0000       : ENTITY work.tb_common_multiplexer GENERIC MAP (0, 0, 4, 0, 0, 8, TRUE, 500000);
  u_demux_mux_p0000_nof_1 : ENTITY work.tb_common_multiplexer GENERIC MAP (0, 0, 1, 0, 0, 8, TRUE, 500000);
  u_demux_mux_p0011       : ENTITY work.tb_common_multiplexer GENERIC MAP (0, 0, 4, 1, 1, 8, TRUE, 500000);
  u_demux_mux_p1100       : ENTITY work.tb_common_multiplexer GENERIC MAP (1, 1, 4, 0, 0, 8, TRUE, 500000);
  u_demux_mux_p1111       : ENTITY work.tb_common_multiplexer GENERIC MAP (1, 1, 4, 1, 1, 8, TRUE, 500000);
  u_demux_mux_p1010       : ENTITY work.tb_common_multiplexer GENERIC MAP (1, 0, 4, 1, 0, 8, TRUE, 500000);
  u_demux_mux_p0101       : ENTITY work.tb_common_multiplexer GENERIC MAP (0, 1, 4, 0, 1, 8, TRUE, 500000);
  u_demux_mux_p1234_nof_1 : ENTITY work.tb_common_multiplexer GENERIC MAP (1, 2, 1, 3, 4, 8, TRUE, 500000);
  u_demux_mux_p1234_nof_5 : ENTITY work.tb_common_multiplexer GENERIC MAP (1, 2, 5, 3, 4, 8, TRUE, 500000);
  
END tb;
