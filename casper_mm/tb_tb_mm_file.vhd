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

-- Author:
--   E. Kooistra        Feb 2017  Initial.
-- Purpose: Multi testbench of tb_mm_file to verify mm_file and mm_file_pkg.
-- Usage:
-- > as 4
-- > run -all

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY tb_tb_mm_file IS
END tb_tb_mm_file;

ARCHITECTURE tb OF tb_tb_mm_file IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN
  -- g_tb_index           : NATURAL := 0;
  -- g_mm_nof_accesses    : NATURAL := 100;
  -- g_mm_timeout         : TIME := sel_a_b(g_mm_throttle_en, 1 ns, 0 ns);  -- default 0 for full speed MM, use > 0 to define number of mm_clk without MM access after which the MM file IO is paused
  -- g_mm_pause           : TIME := 1 us;                                   -- defines the time for which MM file IO is paused to reduce the file IO rate when the MM slave is idle
  -- g_timeout_gap        : INTEGER := -1;    -- no gap when < 0, else force MM access gap after g_timeout_gap wr or rd strobes
  -- g_cross_clock_domain : BOOLEAN := FALSE --TRUE
    
  u_one_clk                        : ENTITY work.tb_mm_file GENERIC MAP (0, 10000,   0 ns, 1 us, -1, FALSE);
  u_one_clk_mm_throttle            : ENTITY work.tb_mm_file GENERIC MAP (1, 10000, 100 ns, 1 us, -1, FALSE);
  u_cross_clk                      : ENTITY work.tb_mm_file GENERIC MAP (2,  1000,   0 ns, 1 us, -1, TRUE);
  u_cross_clk_mm_throttle          : ENTITY work.tb_mm_file GENERIC MAP (3,  1000, 100 ns, 1 us, -1, TRUE);
  u_with_gap_one_clk               : ENTITY work.tb_mm_file GENERIC MAP (4, 10000,   0 ns, 1 us,  3, FALSE);
  u_with_gap_one_clk_mm_throttle   : ENTITY work.tb_mm_file GENERIC MAP (5, 10000, 100 ns, 1 us,  3, FALSE);
  u_with_gap_cross_clk             : ENTITY work.tb_mm_file GENERIC MAP (6,  1000,   0 ns, 1 us,  3, TRUE);
  u_with_gap_cross_clk_mm_throttle : ENTITY work.tb_mm_file GENERIC MAP (7,  1000, 100 ns, 1 us,  3, TRUE);
  
END tb;
