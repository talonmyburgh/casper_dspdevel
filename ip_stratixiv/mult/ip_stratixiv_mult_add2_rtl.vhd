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
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;


------------------------------------------------------------------------------
-- Function:
-- . res = a0 * b0 + a1 * b1
-- . res = a0 * b0 - a1 * b1
------------------------------------------------------------------------------

ENTITY ip_stratixiv_mult_add2_rtl IS
  GENERIC (
    g_in_a_w           : POSITIVE;
    g_in_b_w           : POSITIVE;
    g_res_w            : POSITIVE;          -- g_in_a_w + g_in_b_w + log2(2)
    g_force_dsp        : BOOLEAN := TRUE;   -- when TRUE resize input width to >= 18
    g_add_sub          : STRING := "ADD";   -- or "SUB"
    g_nof_mult         : INTEGER := 2;      -- fixed
    g_pipeline_input   : NATURAL := 1;      -- 0 or 1
    g_pipeline_product : NATURAL := 0;      -- 0 or 1
    g_pipeline_adder   : NATURAL := 1;      -- 0 or 1
    g_pipeline_output  : NATURAL := 1       -- >= 0
  );
  PORT (
    rst        : IN  STD_LOGIC := '0';
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    in_a       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_a_w-1 DOWNTO 0);
    in_b       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_b_w-1 DOWNTO 0);
    res        : OUT STD_LOGIC_VECTOR(g_res_w-1 DOWNTO 0)
  );
END ip_stratixiv_mult_add2_rtl;


ARCHITECTURE str OF ip_stratixiv_mult_add2_rtl IS

  -- Extra output pipelining is only needed when g_pipeline_output > 1
  CONSTANT c_pipeline_output : NATURAL := sel_a_b(g_pipeline_output>0, g_pipeline_output-1, 0);

  CONSTANT c_prod_w     : NATURAL := g_in_a_w+g_in_b_w;
  CONSTANT c_sum_w      : NATURAL := c_prod_w+1;

  -- registers
  SIGNAL reg_a0         : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL reg_b0         : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL reg_a1         : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL reg_b1         : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL reg_prod0      : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL reg_prod1      : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL reg_sum        : SIGNED(c_sum_w-1 DOWNTO 0);
  SIGNAL reg_result     : SIGNED(g_res_w-1 DOWNTO 0);

  -- combinatorial
  SIGNAL nxt_a0     : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL nxt_b0     : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL nxt_a1     : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL nxt_b1     : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL nxt_prod0  : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL nxt_prod1  : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL nxt_sum    : SIGNED(c_sum_w-1 DOWNTO 0);
  SIGNAL nxt_result : SIGNED(g_res_w-1 DOWNTO 0);

  -- the active signals
  SIGNAL a0         : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL b0         : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL a1         : SIGNED(g_in_a_w-1 DOWNTO 0);
  SIGNAL b1         : SIGNED(g_in_b_w-1 DOWNTO 0);
  SIGNAL prod0      : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL prod1      : SIGNED(c_prod_w-1 DOWNTO 0);
  SIGNAL sum        : SIGNED(c_sum_w-1 DOWNTO 0);
  SIGNAL result     : SIGNED(g_res_w-1 DOWNTO 0);

BEGIN

  ------------------------------------------------------------------------------
  -- Registers
  ------------------------------------------------------------------------------

  -- Put all potential registers in a single process for optimal DSP inferrence
  -- Use rst only if it is supported by the DSP primitive, else leave it at '0'
  p_reg : PROCESS (rst, clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF rst='1' THEN
        reg_a0     <= (OTHERS=>'0');
        reg_b0     <= (OTHERS=>'0');
        reg_a1     <= (OTHERS=>'0');
        reg_b1     <= (OTHERS=>'0');
        reg_prod0  <= (OTHERS=>'0');
        reg_prod1  <= (OTHERS=>'0');
        reg_sum    <= (OTHERS=>'0');
        reg_result <= (OTHERS=>'0');
      ELSIF clken='1' THEN
        reg_a0     <= nxt_a0;       -- inputs
        reg_b0     <= nxt_b0;
        reg_a1     <= nxt_a1;
        reg_b1     <= nxt_b1;
        reg_prod0  <= nxt_prod0;    -- products
        reg_prod1  <= nxt_prod1;
        reg_sum    <= nxt_sum;      -- sum
        reg_result <= nxt_result;   -- result sum after optional rounding
      END IF;
    END IF;
  END PROCESS;

  ------------------------------------------------------------------------------
  -- Inputs
  ------------------------------------------------------------------------------

  nxt_a0 <= SIGNED(in_a(  g_in_a_w-1 DOWNTO 0));
  nxt_b0 <= SIGNED(in_b(  g_in_b_w-1 DOWNTO 0));
  nxt_a1 <= SIGNED(in_a(2*g_in_a_w-1 DOWNTO g_in_a_w));
  nxt_b1 <= SIGNED(in_b(2*g_in_b_w-1 DOWNTO g_in_b_w));

  no_input_reg : IF g_pipeline_input=0 GENERATE   -- wired
    a0 <= nxt_a0;
    b0 <= nxt_b0;
    a1 <= nxt_a1;
    b1 <= nxt_b1;
  END GENERATE;

  gen_input_reg : IF g_pipeline_input>0 GENERATE  -- register input
    a0 <= reg_a0;
    b0 <= reg_b0;
    a1 <= reg_a1;
    b1 <= reg_b1;
  END GENERATE;

  ------------------------------------------------------------------------------
  -- Products
  ------------------------------------------------------------------------------

  nxt_prod0 <= a0 * b0;
  nxt_prod1 <= a1 * b1;

  no_product_reg : IF g_pipeline_product=0 GENERATE   -- wired
    prod0 <= nxt_prod0;
    prod1 <= nxt_prod1;
  END GENERATE;
  gen_product_reg : IF g_pipeline_product>0 GENERATE  -- register
    prod0 <= reg_prod0;
    prod1 <= reg_prod1;
  END GENERATE;

  ------------------------------------------------------------------------------
  -- Sum
  ------------------------------------------------------------------------------
  gen_add : IF g_add_sub = "ADD" GENERATE
    nxt_sum <= RESIZE_NUM(prod0, c_sum_w) + prod1;
  END GENERATE;
  gen_sub : IF g_add_sub = "SUB" GENERATE
    nxt_sum <= RESIZE_NUM(prod0, c_sum_w) - prod1;
  END GENERATE;

  no_adder_reg : IF g_pipeline_adder=0 GENERATE   -- wired
    sum <= nxt_sum;
  END GENERATE;
  gen_adder_reg : IF g_pipeline_adder>0 GENERATE  -- register
    sum <= reg_sum;
  END GENERATE;


  ------------------------------------------------------------------------------
  -- Result sum after optional rounding
  ------------------------------------------------------------------------------

  nxt_result <= RESIZE_NUM(sum, g_res_w);

  no_result_reg : IF g_pipeline_output=0 GENERATE   -- wired
    result <= nxt_result;
  END GENERATE;
  gen_result_reg : IF g_pipeline_output>0 GENERATE  -- register
    result <= reg_result;
  END GENERATE;

  res <= STD_LOGIC_VECTOR(result);

END str;
