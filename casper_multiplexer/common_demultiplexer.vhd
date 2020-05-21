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
USE common_components_lib.common_components_pkg.ALL;

-- Purpose: Assign input to one of g_nof_out output streams based on out_sel input
-- Description: The output streams are concatenated into one SLV.
-- Remarks:
-- . Same scheme for pipeline handling and g_nof_out=1 handling as in common_select_symbol

ENTITY common_demultiplexer IS
  GENERIC (
    g_pipeline_in  : NATURAL := 0;
    g_pipeline_out : NATURAL := 0;
    g_nof_out      : NATURAL;
    g_dat_w        : NATURAL
 );
  PORT (
    rst         : IN  STD_LOGIC := '0';
    clk         : IN  STD_LOGIC := '0';  -- for g_pipeline_* = 0 no rst and clk are needed, because then the demultiplexer works combinatorialy
    
    in_dat      : IN  STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
    in_val      : IN  STD_LOGIC;

    out_sel     : IN  STD_LOGIC_VECTOR(ceil_log2(g_nof_out)-1 DOWNTO 0);
    out_dat     : OUT STD_LOGIC_VECTOR(g_nof_out*g_dat_w-1 DOWNTO 0);
    out_val     : OUT STD_LOGIC_VECTOR(g_nof_out        -1 DOWNTO 0)
  );
END;

ARCHITECTURE rtl OF common_demultiplexer IS
  
  CONSTANT c_sel_w    : NATURAL := out_sel'LENGTH;
  
  SIGNAL in_dat_reg    : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL in_val_reg    : STD_LOGIC;
  
  SIGNAL out_sel_reg   : STD_LOGIC_VECTOR(out_sel'RANGE);
  
  SIGNAL sel_dat       : STD_LOGIC_VECTOR(g_nof_out*g_dat_w-1 DOWNTO 0);
  SIGNAL sel_val       : STD_LOGIC_VECTOR(g_nof_out        -1 DOWNTO 0);
  
BEGIN

  -- pipeline input
  u_pipe_in_dat  : common_pipeline    GENERIC MAP ("SIGNED", g_pipeline_in, 0, g_dat_w, g_dat_w) PORT MAP (rst, clk, '1', '0', '1', in_dat,  in_dat_reg);
  u_pipe_in_val  : common_pipeline_sl GENERIC MAP (          g_pipeline_in, 0, FALSE)            PORT MAP (rst, clk, '1', '0', '1', in_val,  in_val_reg);
  
  u_pipe_out_sel : common_pipeline    GENERIC MAP ("SIGNED", g_pipeline_in, 0, c_sel_w, c_sel_w) PORT MAP (rst, clk, '1', '0', '1', out_sel, out_sel_reg);

  -- select combinatorialy
  no_sel : IF g_nof_out=1 GENERATE
    sel_dat    <= in_dat_reg;
    sel_val(0) <= in_val_reg;
  END GENERATE;
  
  gen_sel : IF g_nof_out>1 GENERATE
    p_sel : PROCESS(out_sel_reg, in_dat_reg, in_val_reg)
    BEGIN
      sel_val <= (OTHERS=>'0');
      FOR I IN g_nof_out-1 DOWNTO 0 LOOP
        sel_dat((I+1)*g_dat_w-1 DOWNTO I*g_dat_w) <= in_dat_reg;  -- replicate in_dat to all outputs, this requires less logic than default forcing invalid outputs to 0
        IF TO_UINT(out_sel_reg)=I THEN
          sel_val(I) <= in_val_reg;                               -- let out_sel determine which output is valid
        END IF;
      END LOOP;
    END PROCESS;
  END GENERATE;

  -- pipeline output
  u_pipe_out_dat : common_pipeline GENERIC MAP ("SIGNED", g_pipeline_out, 0, g_nof_out*g_dat_w, g_nof_out*g_dat_w) PORT MAP (rst, clk, '1', '0', '1', sel_dat, out_dat);
  u_pipe_out_val : common_pipeline GENERIC MAP ("SIGNED", g_pipeline_out, 0, g_nof_out        , g_nof_out        ) PORT MAP (rst, clk, '1', '0', '1', sel_val, out_val);
  
END rtl;
