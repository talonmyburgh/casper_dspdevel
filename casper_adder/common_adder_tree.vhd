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

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

-- Purpose: Parallel adder tree.
-- Description:
-- . Add g_nof_inputs from an input vector in_dat. The number of stages in the
--   adder tree is ceil_log2(g_nof_inputs). Each amount of pipelining per stage
--   is set by g_pipeline.
-- Remarks:
-- . Use ceil_log2(g_nof_inputs) instead of true_log2() for the number of
--   stages in the adder tree, to have also for g_nof_inputs = 1 one stage that
--   effectively adds 0 to the single in_dat. In this way this 'str'
--   architecture behaves the same as  the 'recursive' architecture for
--   g_nof_inputs = 1. The 'recursive' architecture uses this one bit growth
--   for g_nof_inputs = 1 to match the bit growth of a parallel adder in the
--   same stage when g_nof_inputs is odd.
  

ENTITY common_adder_tree IS
  GENERIC (
    g_representation : STRING  := "SIGNED";
    g_pipeline       : NATURAL := 1;          -- amount of pipelining per stage
    g_nof_inputs     : NATURAL := 4;          -- >= 1, nof stages = ceil_log2(g_nof_inputs)
    g_dat_w          : NATURAL := (12+16)+2;
    g_sum_w          : NATURAL := (12+16)+4   -- g_dat_w + ceil_log2(g_nof_inputs)
  );
  PORT (
    clk    : IN  STD_LOGIC;
    clken  : IN  STD_LOGIC := '1';
    in_dat : IN  STD_LOGIC_VECTOR(g_nof_inputs*g_dat_w-1 DOWNTO 0);
    sum    : OUT STD_LOGIC_VECTOR(             g_sum_w-1 DOWNTO 0)
  );
END common_adder_tree;
