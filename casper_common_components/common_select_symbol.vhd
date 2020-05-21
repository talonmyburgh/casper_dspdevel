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
USE work.common_components_pkg.ALL;

-- Purpose: Select symbol from input data stream
-- Description:
--   The in_data is a concatenation of g_nof_symbols, that are each g_symbol_w
--   bits wide. The symbol with index set by in_sel is passed on to the output
--   out_dat.
-- Remarks:
-- . If the in_select index is too large for g_nof_input range then the output
--   passes on symbol 0.

ENTITY common_select_symbol IS
  GENERIC (
    g_pipeline_in  : NATURAL := 0;
    g_pipeline_out : NATURAL := 1;
    g_nof_symbols  : NATURAL := 4;
    g_symbol_w     : NATURAL := 16;
    g_sel_w        : NATURAL := 2
  );
  PORT (
    rst        : IN  STD_LOGIC;
    clk        : IN  STD_LOGIC;
    
    in_data    : IN  STD_LOGIC_VECTOR(g_nof_symbols*g_symbol_w-1 DOWNTO 0);
    in_val     : IN  STD_LOGIC := '0';
    in_sop     : IN  STD_LOGIC := '0';
    in_eop     : IN  STD_LOGIC := '0';
    in_sync    : IN  STD_LOGIC := '0';
    
    in_sel     : IN  STD_LOGIC_VECTOR(g_sel_w-1 DOWNTO 0);
    out_sel    : OUT STD_LOGIC_VECTOR(g_sel_w-1 DOWNTO 0);  -- pipelined in_sel, use range to allow leaving it OPEN
    
    out_symbol : OUT STD_LOGIC_VECTOR(g_symbol_w-1 DOWNTO 0);
    out_val    : OUT STD_LOGIC;         -- pipelined in_val
    out_sop    : OUT STD_LOGIC;         -- pipelined in_sop
    out_eop    : OUT STD_LOGIC;         -- pipelined in_eop
    out_sync   : OUT STD_LOGIC          -- pipelined in_sync
  );
END common_select_symbol;


ARCHITECTURE rtl OF common_select_symbol IS

  CONSTANT c_pipeline   : NATURAL := g_pipeline_in + g_pipeline_out;

  SIGNAL in_data_reg    : STD_LOGIC_VECTOR(in_data'RANGE);
  SIGNAL in_sel_reg     : STD_LOGIC_VECTOR(in_sel'RANGE);
  
  SIGNAL sel_symbol     : STD_LOGIC_VECTOR(g_symbol_w-1 DOWNTO 0);
  
BEGIN

  -- pipeline input
  u_pipe_in_data : common_pipeline GENERIC MAP ("SIGNED", g_pipeline_in, 0, in_data'LENGTH, in_data'LENGTH) PORT MAP (rst, clk, '1', '0', '1', in_data, in_data_reg);
  u_pipe_in_sel  : common_pipeline GENERIC MAP ("SIGNED", g_pipeline_in, 0, g_sel_w,        g_sel_w)        PORT MAP (rst, clk, '1', '0', '1', in_sel,  in_sel_reg);
  
  no_sel : IF g_nof_symbols=1 GENERATE
    sel_symbol <= in_data_reg;
  END GENERATE;
  
  gen_sel : IF g_nof_symbols>1 GENERATE
    -- Default pass on symbol 0 else if supported pass on the selected symbol
    p_sel : PROCESS(in_sel_reg, in_data_reg)
    BEGIN
      sel_symbol <= in_data_reg(g_symbol_w-1 DOWNTO 0);
      
      FOR I IN g_nof_symbols-1 DOWNTO 0 LOOP
        IF TO_UINT(in_sel_reg)=I THEN
          sel_symbol <= in_data_reg((I+1)*g_symbol_w-1 DOWNTO I*g_symbol_w);
        END IF;
      END LOOP;
    END PROCESS;
  END GENERATE;
    
  -- pipeline selected symbol output and control outputs
  u_pipe_out_symbol : common_pipeline GENERIC MAP ("SIGNED", g_pipeline_out, 0, g_symbol_w,    g_symbol_w)    PORT MAP (rst, clk, '1', '0', '1', sel_symbol, out_symbol);
  u_pipe_out_sel    : common_pipeline GENERIC MAP ("SIGNED", c_pipeline,     0, in_sel'LENGTH, in_sel'LENGTH) PORT MAP (rst, clk, '1', '0', '1', in_sel,     out_sel);
  
  u_pipe_out_val  : common_pipeline_sl GENERIC MAP (c_pipeline, 0, FALSE) PORT MAP (rst, clk, '1', '0', '1', in_val,  out_val);
  u_pipe_out_sop  : common_pipeline_sl GENERIC MAP (c_pipeline, 0, FALSE) PORT MAP (rst, clk, '1', '0', '1', in_sop,  out_sop);
  u_pipe_out_eop  : common_pipeline_sl GENERIC MAP (c_pipeline, 0, FALSE) PORT MAP (rst, clk, '1', '0', '1', in_eop,  out_eop);
  u_pipe_out_sync : common_pipeline_sl GENERIC MAP (c_pipeline, 0, FALSE) PORT MAP (rst, clk, '1', '0', '1', in_sync, out_sync);

END rtl;