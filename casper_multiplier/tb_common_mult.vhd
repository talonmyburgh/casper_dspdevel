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

-- Purpose: Tb for common_mult architectures
-- Description:
--   The tb is self verifying.
-- Usage:
--   > as 10
--   > run -all

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
--USE technology_lib.technology_select_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;


ENTITY tb_common_mult IS
  GENERIC (
    g_in_dat_w         : NATURAL := 7;
    g_out_dat_w        : NATURAL := 11;  -- = 2*g_in_dat_w, or smaller to truncate MSbits, or larger to extend MSbits
    g_pipeline_input   : NATURAL := 1;
    g_pipeline_product : NATURAL := 1;
    g_pipeline_output  : NATURAL := 1;
    g_a_val_min        : INTEGER := 0;            
		g_a_val_max        : INTEGER := 0;            
		g_b_val_min        : INTEGER := 0;            
		g_b_val_max        : INTEGER := 0            
  );
  PORT(
    o_rst				       : OUT STD_LOGIC;
		o_clk				       : OUT STD_LOGIC;
		o_tb_end		       : OUT STD_LOGIC;
		o_test_msg	       : OUT STRING(1 to 80);
		o_test_pass	       : OUT BOOLEAN
  );
END tb_common_mult;

ARCHITECTURE tb OF tb_common_mult IS

  CONSTANT clk_period    : TIME := 10 ns;
  CONSTANT c_pipeline    : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_output;
  CONSTANT c_nof_mult    : NATURAL := 2;  -- fixed

  CONSTANT c_max_p       : INTEGER :=  2**(g_in_dat_w-1)-1;
  CONSTANT c_min         : INTEGER := -c_max_p;
  CONSTANT c_max_n       : INTEGER := -2**(g_in_dat_w-1);

  FUNCTION func_sresult(in_a, in_b : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_res_w  : NATURAL := 2*g_in_dat_w;  -- use sufficiently large result width
    VARIABLE v_a      : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    VARIABLE v_b      : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    VARIABLE v_result : SIGNED(c_res_w-1 DOWNTO 0);
  BEGIN
    -- Calculate expected result
    v_a      := RESIZE_SVEC(in_a, g_in_dat_w);
    v_b      := RESIZE_SVEC(in_b, g_in_dat_w);
    v_result := RESIZE_NUM(SIGNED(v_a)*SIGNED(v_b), c_res_w);
    RETURN RESIZE_SVEC(STD_LOGIC_VECTOR(v_result), g_out_dat_w);  -- Truncate MSbits or sign extend MSBits
  END;

  SIGNAL rst                  : STD_LOGIC;
  SIGNAL clk                  : STD_LOGIC := '0';
  SIGNAL tb_end               : STD_LOGIC := '0';

  -- Input signals
  SIGNAL in_a                 : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b                 : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_a_p               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b_p               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);

  -- Product signals
  SIGNAL sresult_expected     : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- pipelined expected result
  SIGNAL sresult_rtl          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);

  -- auxiliary signals
  SIGNAL in_a_arr             : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b_arr             : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL out_sresult          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- combinatorial expected result

  SIGNAL s_test_count : NATURAL := 0;
BEGIN

  clk  <= NOT clk OR tb_end AFTER clk_period/2;
  o_tb_end <= tb_end;
  o_clk <= clk;
  o_rst <= rst;

  -- run 1 us
  p_in_stimuli : PROCESS
  BEGIN
    rst <= '1';
    in_a <= TO_SVEC(0, g_in_dat_w);
    in_b <= TO_SVEC(0, g_in_dat_w);
    proc_common_wait_some_cycles(clk, 10);
    rst <= '0';
    proc_common_wait_some_cycles(clk, 10);

    -- Some special combinations
    in_a <= TO_SVEC(2, g_in_dat_w);
    in_b <= TO_SVEC(3, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_a <= TO_SVEC(c_max_p, g_in_dat_w);  -- p*p = pp
    in_b <= TO_SVEC(c_max_p, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_a <= TO_SVEC(c_max_n, g_in_dat_w);  -- -p*-p = pp
    in_b <= TO_SVEC(c_max_n, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_a <= TO_SVEC(c_max_p, g_in_dat_w);  -- p*-p =  = -pp
    in_b <= TO_SVEC(c_max_n, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_a <= TO_SVEC(c_max_p, g_in_dat_w);  -- p*(-p-1) = -pp - p
    in_b <= TO_SVEC(c_min, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_a <= TO_SVEC(c_max_n, g_in_dat_w);  -- -p*(-p-1) = pp + p
    in_b <= TO_SVEC(c_min, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);

    proc_common_wait_some_cycles(clk, 50);

    -- All combinations
    FOR I IN g_a_val_min TO g_a_val_max LOOP
      FOR J IN g_b_val_min TO g_b_val_max LOOP
        in_a <= TO_SVEC(I, g_in_dat_w);
        in_b <= TO_SVEC(J, g_in_dat_w);
        s_test_count <= s_test_count + 1;
        WAIT UNTIL rising_edge(clk);
      END LOOP;
    END LOOP;

    proc_common_wait_some_cycles(clk, 50);
    tb_end <= '1';
    WAIT;
  END PROCESS;

  -- pipeline inputs to ease comparison in the Wave window
  u_in_a_pipeline : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => g_in_dat_w,
    g_out_dat_w      => g_in_dat_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => in_a,
    out_dat => in_a_p
  );

  u_in_b_pipeline : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => g_in_dat_w,
    g_out_dat_w      => g_in_dat_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => in_b,
    out_dat => in_b_p
  );

  -- calculate expected output only for one multiplier
  out_sresult <= func_sresult(in_a, in_b);

  u_sresult : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => g_out_dat_w,
    g_out_dat_w      => g_out_dat_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => out_sresult,
    out_dat => sresult_expected
  );

  u_sdut_rtl : ENTITY work.common_mult
  GENERIC MAP (
    g_use_dsp          => "YES",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output
  )
  PORT MAP (
    rst     => '0',
    clk     => clk,
    clken   => '1',
    in_a    => in_a,
    in_b    => in_b,
    result  => sresult_rtl
  );

  p_verify : PROCESS(rst, clk)
  VARIABLE v_test_pass : BOOLEAN := TRUE;
  BEGIN
    IF rst='0' THEN
      IF rising_edge(clk) THEN
        v_test_pass := sresult_rtl = sresult_expected;
        IF sresult_rtl /= sresult_expected THEN
          o_test_msg <= pad("wrong RTL result#" & integer'image(s_test_count) & ", expected: " & to_hstring(sresult_expected) & " but got: " & to_hstring(sresult_rtl), o_test_msg'length, '.');
          report "Error" & o_test_msg severity failure;
        END IF;
      END IF;
    END IF;
    o_test_pass <= v_test_pass;
  END PROCESS;

END tb;
