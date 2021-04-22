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
-- Purpose: Verify different architectures of common_complex_mult
-- Description:
--   p_verify verifies that the instances of common_complex_mult all yield the
--   expected results and ASSERTs an ERROR in case they differ.
-- Usage:
-- > as 10
-- > run -all  -- signal tb_end will stop the simulation by stopping the clk

LIBRARY IEEE, common_pkg_lib, common_components_lib; --, ip_stratixiv_mult_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
--USE technology_lib.technology_select_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;


ENTITY tb_common_complex_mult IS
  GENERIC (
    g_in_dat_w         : NATURAL := 4;
    g_out_dat_w        : NATURAL := 8;       -- g_in_dat_w*2 for multiply and +1 for adder
    g_conjugate_b      : BOOLEAN := FALSE;   -- When FALSE p = a * b, else p = a * conj(b)
    g_pipeline_input   : NATURAL := 1;
    g_pipeline_product : NATURAL := 0;
    g_pipeline_adder   : NATURAL := 1;
    g_pipeline_output  : NATURAL := 1
  );
END tb_common_complex_mult;


ARCHITECTURE tb OF tb_common_complex_mult IS

  CONSTANT clk_period        : TIME := 10 ns;
  CONSTANT c_pipeline        : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_adder + g_pipeline_output;

  CONSTANT c_max             : INTEGER :=  2**(g_in_dat_w-1)-1;
  CONSTANT c_min             : INTEGER := -2**(g_in_dat_w-1);

  CONSTANT c_technology      : NATURAL := 0;

  SIGNAL tb_end              : STD_LOGIC := '0';
  SIGNAL rst                 : STD_LOGIC;
  SIGNAL clk                 : STD_LOGIC := '0';

  SIGNAL random              : STD_LOGIC_VECTOR(14 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  SIGNAL in_ar               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_ai               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_br               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_bi               : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);

  SIGNAL in_val              : STD_LOGIC;  -- in_val is only passed on to out_val
  SIGNAL result_val_expected : STD_LOGIC;
  SIGNAL result_val_rtl      : STD_LOGIC;
  SIGNAL result_val_ip       : STD_LOGIC;

  SIGNAL out_result_re       : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- combinatorial result
  SIGNAL out_result_im       : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL result_re_expected  : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);  -- pipelined results
  SIGNAL result_re_rtl       : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL result_re_ip        : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL result_im_expected  : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL result_im_rtl       : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL result_im_ip        : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);


BEGIN

  clk <= (NOT clk) OR tb_end AFTER clk_period/2;

  random <= func_common_random(random) WHEN rising_edge(clk);

  in_val <= random(random'HIGH);

  -- run -all
  p_in_stimuli : PROCESS
  BEGIN
    rst <= '1';
    in_ar <= TO_SVEC(0, g_in_dat_w);
    in_br <= TO_SVEC(0, g_in_dat_w);
    in_ai <= TO_SVEC(0, g_in_dat_w);
    in_bi <= TO_SVEC(0, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    FOR I IN 0 TO 9 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;
    rst <= '0';
    FOR I IN 0 TO 9 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;

    -- Some special combinations
    in_ar <= TO_SVEC(2, g_in_dat_w);
    in_ai <= TO_SVEC(4, g_in_dat_w);
    in_br <= TO_SVEC(3, g_in_dat_w);
    in_bi <= TO_SVEC(5, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_ar <= TO_SVEC( c_max, g_in_dat_w);  -- p*p - p*p + j ( p*p + p*p) = 0 + j 2pp  or  p*p + p*p + j (-p*p + p*p) = 2pp + j 0
    in_ai <= TO_SVEC( c_max, g_in_dat_w);
    in_br <= TO_SVEC( c_max, g_in_dat_w);
    in_bi <= TO_SVEC( c_max, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_ar <= TO_SVEC( c_min, g_in_dat_w);
    in_ai <= TO_SVEC( c_min, g_in_dat_w);
    in_br <= TO_SVEC( c_min, g_in_dat_w);
    in_bi <= TO_SVEC( c_min, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_ar <= TO_SVEC( c_max, g_in_dat_w);
    in_ai <= TO_SVEC( c_max, g_in_dat_w);
    in_br <= TO_SVEC( c_min, g_in_dat_w);
    in_bi <= TO_SVEC( c_min, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_ar <= TO_SVEC( c_max, g_in_dat_w);
    in_ai <= TO_SVEC( c_max, g_in_dat_w);
    in_br <= TO_SVEC(-c_max, g_in_dat_w);
    in_bi <= TO_SVEC(-c_max, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);
    in_ar <= TO_SVEC( c_min, g_in_dat_w);
    in_ai <= TO_SVEC( c_min, g_in_dat_w);
    in_br <= TO_SVEC(-c_max, g_in_dat_w);
    in_bi <= TO_SVEC(-c_max, g_in_dat_w);
    WAIT UNTIL rising_edge(clk);

    FOR I IN 0 TO 49 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;

    -- All combinations
    FOR I IN -c_max TO c_max LOOP
      FOR J IN -c_max TO c_max LOOP
        FOR K IN -c_max TO c_max LOOP
          FOR L IN -c_max TO c_max LOOP
            in_ar <= TO_SVEC(I, g_in_dat_w);
            in_ai <= TO_SVEC(K, g_in_dat_w);
            in_br <= TO_SVEC(J, g_in_dat_w);
            in_bi <= TO_SVEC(L, g_in_dat_w);
            WAIT UNTIL rising_edge(clk);
          END LOOP;
        END LOOP;
      END LOOP;
    END LOOP;

    FOR I IN 0 TO 49 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;

    tb_end <= '1';
    WAIT;
  END PROCESS;

  -- Expected combinatorial complex multiply out_result
  out_result_re <= func_complex_multiply(in_ar, in_ai, in_br, in_bi, g_conjugate_b, "RE", g_out_dat_w);
  out_result_im <= func_complex_multiply(in_ar, in_ai, in_br, in_bi, g_conjugate_b, "IM", g_out_dat_w);

  u_result_re : ENTITY common_components_lib.common_pipeline
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
    in_dat  => out_result_re,
    out_dat => result_re_expected
  );

  u_result_im : ENTITY common_components_lib.common_pipeline
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
    in_dat  => out_result_im,
    out_dat => result_im_expected
  );

  u_result_val_expected : ENTITY common_components_lib.common_pipeline_sl
  GENERIC MAP (
    g_pipeline    => c_pipeline,
    g_reset_value => 0
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => in_val,
    out_dat => result_val_expected
  );

  u_dut_rtl : ENTITY work.common_complex_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "RTL",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_conjugate_b      => g_conjugate_b,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_adder   => g_pipeline_adder,
    g_pipeline_output  => g_pipeline_output
  )
  PORT MAP (
    rst        => rst,
    clk        => clk,
    clken      => '1',
    in_ar      => in_ar,
    in_ai      => in_ai,
    in_br      => in_br,
    in_bi      => in_bi,
    in_val     => in_val,
    out_pr     => result_re_rtl,
    out_pi     => result_im_rtl,
    out_val    => result_val_rtl
  );

  u_dut_ip : ENTITY work.common_complex_mult
  GENERIC MAP (
    g_technology       => c_technology,
    g_variant          => "IP",
    g_in_a_w           => g_in_dat_w,
    g_in_b_w           => g_in_dat_w,
    g_out_p_w          => g_out_dat_w,
    g_conjugate_b      => g_conjugate_b,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_product => g_pipeline_product,
    g_pipeline_adder   => g_pipeline_adder,
    g_pipeline_output  => g_pipeline_output
  )
  PORT MAP (
    rst        => rst,
    clk        => clk,
    clken      => '1',
    in_ar      => in_ar,
    in_ai      => in_ai,
    in_br      => in_br,
    in_bi      => in_bi,
    in_val     => in_val,
    out_pr     => result_re_ip,
    out_pi     => result_im_ip,
    out_val    => result_val_ip
  );

  p_verify : PROCESS(rst, clk)
  BEGIN
    IF rst='0' THEN
      IF rising_edge(clk) THEN
        ASSERT result_re_rtl  = result_re_expected  REPORT "Error: RE wrong RTL result"  SEVERITY ERROR;
        ASSERT result_im_rtl  = result_im_expected  REPORT "Error: IM wrong RTL result"  SEVERITY ERROR;
        ASSERT result_val_rtl = result_val_expected REPORT "Error: VAL wrong RTL result" SEVERITY ERROR;

        ASSERT result_re_ip   = result_re_expected  REPORT "Error: RE wrong IP result"  SEVERITY ERROR;
        ASSERT result_im_ip   = result_im_expected  REPORT "Error: IM wrong IP result"  SEVERITY ERROR;
        ASSERT result_val_ip  = result_val_expected REPORT "Error: VAL wrong IP result" SEVERITY ERROR;

      END IF;
    END IF;
  END PROCESS;

END tb;
