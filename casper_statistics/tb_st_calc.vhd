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
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;


ENTITY tb_st_calc IS
  GENERIC (
    g_in_dat_w     : NATURAL := 16;
    g_out_dat_w    : NATURAL := 32
  );
END tb_st_calc;


ARCHITECTURE tb OF tb_st_calc IS

  CONSTANT clk_period             : TIME := 10 ns;
  
  CONSTANT c_nof_sync             : NATURAL := 3;
  CONSTANT c_nof_stat             : NATURAL := 100;
  CONSTANT c_out_adr_w            : NATURAL := ceil_log2(c_nof_stat);
  CONSTANT c_gap_size             : NATURAL := 2**c_out_adr_w - c_nof_stat;
  
  CONSTANT c_nof_accum_per_sync   : NATURAL := 5;  -- integration time
  
  SIGNAL tb_end          : STD_LOGIC := '0';
  SIGNAL clk             : STD_LOGIC := '0';
  SIGNAL rst             : STD_LOGIC;
  
  SIGNAL in_sync         : STD_LOGIC;
  SIGNAL in_val          : STD_LOGIC;
  SIGNAL in_dat          : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    
  SIGNAL in_a_re         : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_a_im         : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b_re         : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL in_b_im         : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  
  SIGNAL out_adr         : STD_LOGIC_VECTOR(c_out_adr_w-1 DOWNTO 0);
  SIGNAL out_re          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL out_im          : STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
  SIGNAL out_val         : STD_LOGIC;
  
BEGIN

  clk  <= NOT clk OR tb_end AFTER clk_period/2;
  
  in_a_re <= in_dat;
  in_a_im <= in_dat;
  in_b_re <= in_dat;
  in_b_im <= in_dat;
  
  in_dat <= (OTHERS=>'0') WHEN rst='1' ELSE INCR_UVEC(in_dat, 1) WHEN rising_edge(clk) AND in_val='1';
  
  -- run 1 us
  p_stimuli : PROCESS
  BEGIN
    rst <= '1';
    in_sync <= '0';
    in_val <= '0';
    WAIT UNTIL rising_edge(clk);
    FOR I IN 0 TO 9 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
    rst <= '0';
    FOR I IN 0 TO 9 LOOP WAIT UNTIL rising_edge(clk); END LOOP;

    FOR I IN 0 TO c_nof_sync-1 LOOP
      in_sync <= '1';
      WAIT UNTIL rising_edge(clk);
      in_sync <= '0';
      
      FOR J IN 0 TO c_nof_accum_per_sync-1 LOOP
        in_val <= '1';
        FOR I IN 0 TO c_nof_stat-1 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
        in_val <= '0';
        FOR I IN 0 TO c_gap_size-1 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
      END LOOP;
    END LOOP;
    FOR I IN 0 TO 9 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
    tb_end <= '1';
    WAIT;
  END PROCESS;
  
  u_dut : ENTITY work.st_calc
  GENERIC MAP (
    g_nof_mux       => 1,
    g_nof_stat      => c_nof_stat,
    g_in_dat_w      => g_in_dat_w,
    g_out_dat_w     => g_out_dat_w,
    g_out_adr_w     => c_out_adr_w,
    g_complex       => FALSE
  )
  PORT MAP (
    rst        => rst,
    clk        => clk,
    clken      => '1',
    in_ar      => in_a_re,
    in_ai      => in_a_im,
    in_br      => in_b_re,
    in_bi      => in_b_im,
    in_val     => in_val,
    in_sync    => in_sync,
    out_adr    => out_adr,
    out_re     => out_re,
    out_im     => out_im,
    out_val    => out_val,
    out_val_m  => OPEN
  );
      
END tb;
