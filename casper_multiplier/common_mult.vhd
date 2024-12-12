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

LIBRARY ieee, common_pkg_lib, common_components_lib;
USE ieee.std_logic_1164.ALL;
--USE technology_lib.technology_select_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;

-- Function: Default one or more independent products dependent on g_nof_mult
--
--   If g_nof_mult = 2 then the input vectors are
--     a = a(1) & a(0) and b = b(1) & b(0)
--   and the independent products in the product vector will be:
--     p = a(1)*b(1) & a(0)*b(0)
--
-- Remarks:
-- . When g_out_p_w < g_in_a_w+g_in_b_w then the common_mult truncates the
--   MSbit of the product.
-- . For c_prod_w = g_in_a_w+g_in_b_w the full product range is preserved. Use
--   g_out_p_w = c_prod_w-1 to skip the double sign bit that is only needed
--   when the maximum positive product -2**(g_in_a_w-1) * -2**(g_in_b_w-1) has
--   to be represented, which is typically not needed in DSP.

ENTITY common_mult IS
  GENERIC (
    g_use_dsp          : STRING   := "YES";
    g_in_a_w           : POSITIVE := 18;
    g_in_b_w           : POSITIVE := 18;
    g_out_p_w          : POSITIVE := 36;      -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
    g_pipeline_input   : NATURAL  := 1;        -- 0 or 1
    g_pipeline_product : NATURAL  := 1;        -- 0 or 1
    g_pipeline_output  : NATURAL  := 1        -- >= 0
  );
  PORT (
    rst        : IN  STD_LOGIC := '0';
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    in_a       : IN  STD_LOGIC_VECTOR(g_in_a_w-1 DOWNTO 0);
    in_b       : IN  STD_LOGIC_VECTOR(g_in_b_w-1 DOWNTO 0);
    in_val     : IN  STD_LOGIC := '1';        -- only propagate valid, not used internally
    result     : OUT STD_LOGIC_VECTOR(g_out_p_w-1 DOWNTO 0) := (others=>'0');
    out_val    : OUT STD_LOGIC
  );
END common_mult;

ARCHITECTURE str OF common_mult IS

  CONSTANT c_pipeline        : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_output;
  
  -- Extra output pipelining using common_pipeline is only needed when g_pipeline_output > 1
  CONSTANT c_pipeline_output : NATURAL := sel_a_b(g_pipeline_output>0, g_pipeline_output-1, 0);

  SIGNAL out_p        : STD_LOGIC_VECTOR(result'RANGE) := (others=>'0');                      -- stage dependent on g_pipeline_output  being 0 or 1

BEGIN

  u_mult : ENTITY work.tech_mult
  GENERIC MAP(
    g_use_dsp          => g_use_dsp,
    g_in_a_w           => g_in_a_w,
    g_in_b_w           => g_in_b_w,
    g_out_p_w          => g_out_p_w,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output
  )
  PORT MAP(
    rst        => rst,
    clk        => clk,
    clken      => clken,
    in_a       => in_a,
    in_b       => in_b,
    result     => out_p
  );     
  
  -- Propagate in_val with c_pipeline latency
  u_out_val : ENTITY common_components_lib.common_pipeline_sl
  GENERIC MAP (
    g_pipeline  => c_pipeline
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => clken,
    in_dat  => in_val,
    out_dat => out_val
  );  

  ------------------------------------------------------------------------------
  -- Extra output pipelining
  ------------------------------------------------------------------------------

  u_output_pipe : ENTITY common_components_lib.common_pipeline  -- pipeline output
  GENERIC MAP (
    g_pipeline       => c_pipeline_output,
    g_in_dat_w       => result'LENGTH,
    g_out_dat_w      => result'LENGTH
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => clken,
    in_dat  => STD_LOGIC_VECTOR(out_p),
    out_dat => result
  );

END str;
