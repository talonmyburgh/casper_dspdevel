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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY tb_tb_common_adder_tree IS
END tb_tb_common_adder_tree;

ARCHITECTURE tb OF tb_tb_common_adder_tree IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN
  -- Usage:
  -- > as 4
  -- > run -all

  -- g_representation : STRING  := "SIGNED";
  -- g_pipeline       : NATURAL := 1;  -- amount of pipelining per stage
  -- g_nof_inputs     : NATURAL := 1;  -- >= 1
  -- g_symbol_w       : NATURAL := 8;
  -- g_sum_w          : NATURAL := 8  -- worst case bit growth requires g_symbol_w + c_nof_stages;
    
  gen_nof_inputs : FOR I IN 1 TO 31 GENERATE
    -- SIGNED
    s_pipe_0  : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 0, I, 8, 8+ceil_log2(I));
    s_pipe_1  : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 1, I, 8, 8+ceil_log2(I));
    s_pipe_2  : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 2, I, 8, 8+ceil_log2(I));
    
    s_sum_w_0      : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 1, I, 8, 8);
    s_sum_w_plus_1 : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 1, I, 8, 8+1);
    s_sum_w_min_1  : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 1, I, 8, 8-1);
    s_sum_w_wider  : ENTITY work.tb_common_adder_tree GENERIC MAP ("SIGNED", 1, I, 8, 8+8);
    
    -- UNSIGNED
    u_pipe_0  : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 0, I, 8, 8+ceil_log2(I));
    u_pipe_1  : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 1, I, 8, 8+ceil_log2(I));
    u_pipe_2  : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 2, I, 8, 8+ceil_log2(I));
    
    u_sum_w_0      : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 1, I, 8, 8);
    u_sum_w_plus_1 : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 1, I, 8, 8+1);
    u_sum_w_min_1  : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 1, I, 8, 8-1);
    u_sum_w_wider  : ENTITY work.tb_common_adder_tree GENERIC MAP ("UNSIGNED", 1, I, 8, 8+8);
  END GENERATE;
  
END tb;
