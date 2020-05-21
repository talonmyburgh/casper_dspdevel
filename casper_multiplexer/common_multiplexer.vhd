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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

-- Purpose: Assign one of g_nof_in input streams to the output based on in_sel input
-- Description: The input streams are concatenated into one SLV.
-- Remarks:

ENTITY common_multiplexer IS
  GENERIC (
    g_pipeline_in  : NATURAL := 0;
    g_pipeline_out : NATURAL := 0;
    g_nof_in       : NATURAL;
    g_dat_w        : NATURAL
 );
  PORT (
    clk         : IN  STD_LOGIC;
    rst         : IN  STD_LOGIC;

    in_sel      : IN  STD_LOGIC_VECTOR(ceil_log2(g_nof_in)-1 DOWNTO 0);
    in_dat      : IN  STD_LOGIC_VECTOR(g_nof_in*g_dat_w-1 DOWNTO 0);
    in_val      : IN  STD_LOGIC;

    out_dat     : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
    out_val     : OUT STD_LOGIC
  );
END;

ARCHITECTURE str OF common_multiplexer IS

BEGIN

  u_select_symbol : ENTITY common_components_lib.common_select_symbol
  GENERIC MAP (
    g_pipeline_in  => g_pipeline_in,
    g_pipeline_out => g_pipeline_out,
    g_nof_symbols  => g_nof_in,
    g_symbol_w     => g_dat_w,
    g_sel_w        => ceil_log2(g_nof_in)
  )
  PORT MAP (
    rst        => rst,
    clk        => clk,
    
    in_data    => in_dat,
    in_val     => in_val,
    
    in_sel     => in_sel,
    
    out_symbol => out_dat,
    out_val    => out_val
  );

END str;
