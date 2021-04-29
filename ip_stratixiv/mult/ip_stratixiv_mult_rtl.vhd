-------------------------------------------------------------------------------
--
-- Copyright (C) 2011
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

LIBRARY IEEE, common_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

-- no support for rounding in this RTL architecture
 ENTITY  ip_stratixiv_mult_rtl IS 
  GENERIC (
    g_in_a_w           : POSITIVE := 18;
    g_in_b_w           : POSITIVE := 18;
    g_out_p_w          : POSITIVE := 36;      -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
    g_nof_mult         : POSITIVE := 1;       -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
    g_pipeline_input   : NATURAL  := 1;        -- 0 or 1
    g_pipeline_product : NATURAL  := 1;        -- 0 or 1
    g_pipeline_output  : NATURAL  := 1;        -- >= 0
    g_representation   : STRING   := "SIGNED"   -- or "UNSIGNED"
  );
  PORT (
    rst        : IN  STD_LOGIC;
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    in_a       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_a_w-1 DOWNTO 0);
    in_b       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_b_w-1 DOWNTO 0);
    out_p      : OUT STD_LOGIC_VECTOR(g_nof_mult*(g_in_a_w+g_in_b_w)-1 DOWNTO 0)
  );
 END ip_stratixiv_mult_rtl;


ARCHITECTURE str OF ip_stratixiv_mult_rtl IS

  CONSTANT c_prod_w          : NATURAL := g_in_a_w+g_in_b_w;
  
  -- registers
  SIGNAL reg_a         : STD_LOGIC_VECTOR(in_a'RANGE);
  SIGNAL reg_b         : STD_LOGIC_VECTOR(in_b'RANGE);
  SIGNAL reg_prod      : STD_LOGIC_VECTOR(g_nof_mult*c_prod_w-1 DOWNTO 0);
  SIGNAL reg_result    : STD_LOGIC_VECTOR(out_p'RANGE);
  
  -- combinatorial
  SIGNAL nxt_a         : STD_LOGIC_VECTOR(in_a'RANGE);
  SIGNAL nxt_b         : STD_LOGIC_VECTOR(in_b'RANGE);
  SIGNAL nxt_prod      : STD_LOGIC_VECTOR(g_nof_mult*c_prod_w-1 DOWNTO 0);
  SIGNAL nxt_result    : STD_LOGIC_VECTOR(out_p'RANGE);
  
  -- the active signals
  SIGNAL inp_a         : STD_LOGIC_VECTOR(in_a'RANGE);
  SIGNAL inp_b         : STD_LOGIC_VECTOR(in_b'RANGE);
  SIGNAL prod          : STD_LOGIC_VECTOR(g_nof_mult*c_prod_w-1 DOWNTO 0);   -- stage dependent on g_pipeline_product being 0 or 1
  SIGNAL result        : STD_LOGIC_VECTOR(out_p'RANGE);                      -- stage dependent on g_pipeline_output  being 0 or 1
  
BEGIN

  ------------------------------------------------------------------------------
  -- Registers
  ------------------------------------------------------------------------------
  
  -- Put all potential registers in a single process for optimal DSP inferrence
  -- Use rst only if it is supported by the DSP primitive, else leave it at '0'
  p_reg : PROCESS (rst, clk)
  BEGIN
    IF rst='1' THEN
      reg_a      <= (OTHERS=>'0');
      reg_b      <= (OTHERS=>'0');
      reg_prod   <= (OTHERS=>'0');
      reg_result <= (OTHERS=>'0');
    ELSIF rising_edge(clk) THEN
      IF clken='1' THEN
        reg_a      <= nxt_a;
        reg_b      <= nxt_b;
        reg_prod   <= nxt_prod;
        reg_result <= nxt_result;
      END IF;
    END IF;
  END PROCESS;
  
  ------------------------------------------------------------------------------
  -- Inputs
  ------------------------------------------------------------------------------
  
  nxt_a <= in_a;
  nxt_b <= in_b;
  
  no_input_reg : IF g_pipeline_input=0 GENERATE   -- wired
    inp_a <= nxt_a;
    inp_b <= nxt_b;
  END GENERATE;
  
  gen_input_reg : IF g_pipeline_input>0 GENERATE  -- register input
    inp_a <= reg_a;
    inp_b <= reg_b;
  END GENERATE;
  
  ------------------------------------------------------------------------------
  -- Products
  ------------------------------------------------------------------------------

  gen_mult : FOR I IN 0 TO g_nof_mult-1 GENERATE  
    nxt_prod((I+1)*c_prod_w-1 DOWNTO I*c_prod_w) <=
      STD_LOGIC_VECTOR(  SIGNED(inp_a((I+1)*g_in_a_w-1 DOWNTO I*g_in_a_w)) *   SIGNED(inp_b((I+1)*g_in_b_w-1 DOWNTO I*g_in_b_w))) WHEN g_representation="SIGNED" ELSE
      STD_LOGIC_VECTOR(UNSIGNED(inp_a((I+1)*g_in_a_w-1 DOWNTO I*g_in_a_w)) * UNSIGNED(inp_b((I+1)*g_in_b_w-1 DOWNTO I*g_in_b_w)));
  END GENERATE;
  
  no_product_reg : IF g_pipeline_product=0 GENERATE   -- wired
    prod <= nxt_prod;
  END GENERATE;  
  gen_product_reg : IF g_pipeline_product>0 GENERATE  -- register
    prod <= reg_prod;
  END GENERATE;

  ------------------------------------------------------------------------------
  -- Results
  ------------------------------------------------------------------------------
  nxt_result <= prod;

  no_result_reg : IF g_pipeline_output=0 GENERATE   -- wired
    result <= nxt_result;
  END GENERATE;  
  gen_result_reg : IF g_pipeline_output>0 GENERATE  -- register
    result <= reg_result;
  END GENERATE;

out_p <= result;
  
END str;
