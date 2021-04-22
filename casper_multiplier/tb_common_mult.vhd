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
    g_nof_mult         : NATURAL := 2;
    g_pipeline_input   : NATURAL := 1;
    g_pipeline_product : NATURAL := 1;
    g_pipeline_output  : NATURAL := 1
  );
END tb_common_mult;

ARCHITECTURE tb OF tb_common_mult IS

  CONSTANT clk_period    : TIME := 10 ns;
  CONSTANT c_pipeline    : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_output;
  CONSTANT c_nof_mult    : NATURAL := 2;  -- fixed

  CONSTANT c_max_p       : INTEGER :=  2**(g_in_dat_w-1)-1;
  CONSTANT c_min         : INTEGER := -c_max_p;
  CONSTANT c_max_n       : INTEGER := -2**(g_in_dat_w-1);

  CONSTANT c_technology  : NATURAL := 0;

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

  FUNCTION func_uresult(in_a, in_b : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_res_w  : NATURAL := 2*g_in_dat_w;  -- use sufficiently large result width
    VARIABLE v_a      : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    VARIABLE v_b      : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    VARIABLE v_result : UNSIGNED(c_res_w-1 DOWNTO 0);
  BEGIN
    -- Calculate expected result
    v_a      := RESIZE_UVEC(in_a, g_in_dat_w);
    v_b      := RESIZE_UVEC(in_b, g_in_dat_w);
    v_result := RESIZE_NUM(UNSIGNED(v_a)*UNSIGNED(v_b), c_res_w);
    RETURN RESIZE_UVEC(STD_LOGIC_VECTOR(v_result), g_out_dat_w);  -- Truncate MSbits or zero extend MSBits
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
  SIGNAL sresult_ip           : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL uresult_expected     : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- pipelined expected result
  SIGNAL uresult_rtl          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL uresult_ip           : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);

  -- auxiliary signals
  SIGNAL in_a_arr             : STD_LOGIC_VECTOR(g_nof_mult*g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b_arr             : STD_LOGIC_VECTOR(g_nof_mult*g_in_dat_w-1 DOWNTO 0);
  SIGNAL out_sresult          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- combinatorial expected result
  SIGNAL out_uresult          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- combinatorial expected result
  SIGNAL sresult_arr_expected : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);
  SIGNAL uresult_arr_expected : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);
  SIGNAL sresult_arr_rtl      : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);
  SIGNAL uresult_arr_rtl      : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);
  SIGNAL sresult_arr_ip       : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);
  SIGNAL uresult_arr_ip       : STD_LOGIC_VECTOR(g_nof_mult*g_out_dat_w-1 DOWNTO 0);

BEGIN

  clk  <= NOT clk OR tb_end AFTER clk_period/2;

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
    FOR I IN -2**(g_in_dat_w-1) TO 2**(g_in_dat_w-1)-1 LOOP
      FOR J IN -2**(g_in_dat_w-1) TO 2**(g_in_dat_w-1)-1 LOOP
        in_a <= TO_SVEC(I, g_in_dat_w);
        in_b <= TO_SVEC(J, g_in_dat_w);
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

  gen_wires : FOR I IN 0 TO g_nof_mult-1 GENERATE
    -- use same input for all multipliers
    in_a_arr((I+1)*g_in_dat_w-1 DOWNTO I*g_in_dat_w) <= in_a;
    in_b_arr((I+1)*g_in_dat_w-1 DOWNTO I*g_in_dat_w) <= in_b;
    -- calculate expected output only for one multiplier
    out_sresult <= func_sresult(in_a, in_b);
    out_uresult <= func_uresult(in_a, in_b);
    -- copy the expected result for all multipliers
    sresult_arr_expected((I+1)*g_out_dat_w-1 DOWNTO I*g_out_dat_w) <= sresult_expected;
    uresult_arr_expected((I+1)*g_out_dat_w-1 DOWNTO I*g_out_dat_w) <= uresult_expected;
  END GENERATE;

  -- use mult(0) to observe result in Wave window
  sresult_rtl <= sresult_arr_rtl(g_out_dat_w-1 DOWNTO 0);
  uresult_rtl <= uresult_arr_rtl(g_out_dat_w-1 DOWNTO 0);
  sresult_ip  <= sresult_arr_ip(g_out_dat_w-1 DOWNTO 0);
  uresult_ip  <= uresult_arr_ip(g_out_dat_w-1 DOWNTO 0);

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

  u_uresult : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "UNSIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => g_out_dat_w,
    g_out_dat_w      => g_out_dat_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => out_uresult,
    out_dat => uresult_expected
  );

  u_sdut_rtl : ENTITY work.common_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "RTL",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_nof_mult         => g_nof_mult,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output,
    g_representation   => "SIGNED"
  )
  PORT MAP (
    rst     => '0',
    clk     => clk,
    clken   => '1',
    in_a    => in_a_arr,
    in_b    => in_b_arr,
    out_p   => sresult_arr_rtl
  );

  u_udut_rtl : ENTITY work.common_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "RTL",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_nof_mult         => g_nof_mult,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output,
    g_representation   => "UNSIGNED"
  )
  PORT MAP (
    rst     => '0',
    clk     => clk,
    clken   => '1',
    in_a    => in_a_arr,
    in_b    => in_b_arr,
    out_p   => uresult_arr_rtl
  );

  u_sdut_ip : ENTITY work.common_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "IP",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_nof_mult         => g_nof_mult,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output,
    g_representation   => "SIGNED"
  )
  PORT MAP (
    rst     => '0',
    clk     => clk,
    clken   => '1',
    in_a    => in_a_arr,
    in_b    => in_b_arr,
    out_p   => sresult_arr_ip
  );

  u_udut_ip : ENTITY work.common_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "IP",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_nof_mult         => g_nof_mult,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_output  => g_pipeline_output,
    g_representation   => "UNSIGNED"
  )
  PORT MAP (
    rst     => '0',
    clk     => clk,
    clken   => '1',
    in_a    => in_a_arr,
    in_b    => in_b_arr,
    out_p   => uresult_arr_ip
  );

  p_verify : PROCESS(rst, clk)
  BEGIN
    IF rst='0' THEN
      IF rising_edge(clk) THEN
        -- verify all multipliers in parallel
        ASSERT sresult_arr_rtl = sresult_arr_expected REPORT "Error: wrong Signed RTL result" SEVERITY ERROR;
        ASSERT uresult_arr_rtl = uresult_arr_expected REPORT "Error: wrong Unsigned RTL result" SEVERITY ERROR;
        ASSERT sresult_arr_ip  = sresult_arr_expected REPORT "Error: wrong Signed IP result" SEVERITY ERROR;
        ASSERT uresult_arr_ip  = uresult_arr_expected REPORT "Error: wrong Unsigned IP result" SEVERITY ERROR;
      END IF;
    END IF;
  END PROCESS;

END tb;
