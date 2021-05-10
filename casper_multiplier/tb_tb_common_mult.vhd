-------------------------------------------------------------------------------
--
-- Copyright (C) 2009
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-------------------------------------------------------------------------------

-- Usage:
--   > as 3
--   > run -all

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY tb_tb_common_mult IS
END tb_tb_common_mult;

ARCHITECTURE tb OF tb_tb_common_mult IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN
  -- g_in_dat_w         : NATURAL := 7;
  -- g_out_dat_w        : NATURAL := 11;  -- = 2*g_in_dat_w, or smaller to truncate MSbits, or larger to extend MSbits
  -- g_nof_mult         : NATURAL := 2;
  -- g_pipeline_input   : NATURAL := 1;
  -- g_pipeline_product : NATURAL := 1;
  -- g_pipeline_output  : NATURAL := 1
    
  
  -- Vary g_out_dat_w
  u_mult_7_12_nof_2_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 12, 2, 1, 1, 1);   -- truncate extra bit
  u_mult_7_13_nof_2_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 13, 2, 1, 1, 1);   -- truncate double sign bit
  u_mult_7_14_nof_2_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 14, 2, 1, 1, 1);   -- preserve full product range
  u_mult_7_15_nof_2_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 15, 2, 1, 1, 1);   -- extend product
  
  -- Vary g_nof_mult
  u_mult_7_11_nof_1_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 1, 1, 1, 1);
  u_mult_7_11_nof_3_pipe_1_1_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 3, 1, 1, 1);
  
  -- Vary g_pipeline_*
  u_mult_7_11_nof_1_pipe_0_0_0  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 2, 0, 0, 0);
  u_mult_7_11_nof_1_pipe_1_0_0  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 2, 1, 0, 0);
  u_mult_7_11_nof_1_pipe_0_1_0  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 2, 0, 1, 0);
  u_mult_7_11_nof_1_pipe_0_0_1  : ENTITY work.tb_common_mult GENERIC MAP (7, 11, 2, 0, 0, 1);
  
END tb;
