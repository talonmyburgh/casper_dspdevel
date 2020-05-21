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
--
-- Purpose: Test bench for common_zip
-- Features:
--
-- Usage:
-- > as 10
-- > run -all
-- Observe manually in Wave Window that the values of the in_dat_arr are zipped
-- to the out_dat vector. 

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;


ENTITY tb_common_zip IS
  GENERIC (
    g_nof_streams : natural := 3;  -- Number of input streams to be zipped
    g_dat_w       : natural := 8
  );
END tb_common_zip;


ARCHITECTURE tb OF tb_common_zip IS

  CONSTANT clk_period   : TIME      := 10 ns;
  CONSTANT c_rl         : NATURAL   := 1;     -- Read Latency = 1

  SIGNAL rst         : STD_LOGIC;
  SIGNAL clk         : STD_LOGIC := '0';
  SIGNAL tb_end      : STD_LOGIC := '0';

  SIGNAL ready       : STD_LOGIC := '1';       -- Ready is always '1'
  SIGNAL in_dat_arr  : t_slv_64_arr(g_nof_streams-1 DOWNTO 0);  
  SIGNAL in_val      : STD_LOGIC := '1';
  SIGNAL out_dat     : std_logic_vector(g_dat_w-1 DOWNTO 0); 
  SIGNAL out_val     : std_logic;                            
  SIGNAL ena         : STD_LOGIC := '1';
  SIGNAL ena_mask    : STD_LOGIC := '1';
  SIGNAL enable      : STD_LOGIC := '1';
BEGIN

  clk    <= NOT clk OR tb_end AFTER clk_period/2;
  rst    <= '1', '0' AFTER 7 * clk_period;
  tb_end <= '0', '1' AFTER 1 us;
  
  gen_data : FOR I IN 0 TO g_nof_streams-1 GENERATE
    proc_common_gen_data(c_rl, I*10, rst, clk, enable, ready, in_dat_arr(I), in_val);
  END GENERATE;
  
  -- The "ena" forms the dutu cycle for the in_val signal
  proc_common_gen_pulse(1, g_nof_streams, '1', clk, ena); 
   
  -- The "ena_mask" creates a gap between series of incoming packets in order
  -- to simulate the starting and stopping of the incoming streams. 
  proc_common_gen_pulse(g_nof_streams*10, g_nof_streams*15, '1', clk, ena_mask);  
  enable <= ena and ena_mask;
  
  u_dut : ENTITY work.common_zip
  GENERIC MAP (
    g_nof_streams => g_nof_streams, 
    g_dat_w       => g_dat_w       
  )
  PORT MAP (
    rst        => rst,
    clk        => clk,
    in_val     => in_val,
    in_dat_arr => in_dat_arr,
    out_val    => out_val,   
    out_dat    => out_dat   
  );
  
END tb;

