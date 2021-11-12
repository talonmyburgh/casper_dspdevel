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

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

ENTITY tb_common_counter IS
  PORT(
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_pass : out boolean;
    o_test_msg  : out string(1 to 80)
  );
END tb_common_counter;

ARCHITECTURE tb OF tb_common_counter IS

  CONSTANT clk_period   : TIME := 10 ns;
  
  CONSTANT c_cnt_init   : NATURAL := 3;
  CONSTANT c_cnt_w      : NATURAL := 5;

  SIGNAL tb_end   : STD_LOGIC := '0';
  SIGNAL rst      : STD_LOGIC;
  SIGNAL clk      : STD_LOGIC := '0';
  
  SIGNAL cnt_clr  : STD_LOGIC := '0';    -- synchronous cnt_clr is only interpreted when clken is active
  SIGNAL cnt_ld   : STD_LOGIC := '0';    -- cnt_ld loads the output count with the input load value, independent of cnt_en
  SIGNAL cnt_en   : STD_LOGIC := '1';
  SIGNAL load     : STD_LOGIC_VECTOR(c_cnt_w-1 DOWNTO 0) := TO_UVEC(c_cnt_init, c_cnt_w);
  SIGNAL count    : STD_LOGIC_VECTOR(c_cnt_w-1 DOWNTO 0);
  SIGNAL cnt_max  : STD_LOGIC_VECTOR(c_cnt_w-1 DOWNTO 0);
  SIGNAL stdcheck : STD_LOGIC_VECTOR(c_cnt_w - 1 downto 0) := "01100";

BEGIN

  clk <= (NOT clk) OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*3;
  o_clk <= clk;
  o_rst <= rst;
  o_tb_end <= tb_end;
  
  -- run 1 us
  p_in_stimuli : PROCESS
  VARIABLE v_test_pass : BOOLEAN := TRUE;
  VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
  BEGIN
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
    cnt_clr <= '0';
    cnt_ld  <= '0';
    cnt_en  <= '0';
    cnt_max <= (OTHERS => '0');
    WAIT UNTIL rst = '0';
    WAIT UNTIL rising_edge(clk);
    
    -- Start counting
    cnt_en  <= '1';
    FOR I IN 0 TO 9 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;
    
    v_test_pass := count = stdcheck;
    if not v_test_pass then
      v_test_msg := pad("Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count),o_test_msg'length,'.');
      REPORT "Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count) severity failure;
    end if;
    
    -- Reload counter
    cnt_ld  <= '1';
    WAIT UNTIL rising_edge(clk);
    cnt_ld  <= '0';
    FOR I IN 0 TO 9 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;

    v_test_pass := count = stdcheck;
    if not v_test_pass then
      v_test_msg := pad("Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count),o_test_msg'length,'.');
      REPORT "Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count) severity failure;
    end if;
    
    -- briefly stop counting
    cnt_en  <= '0';
    WAIT UNTIL rising_edge(clk);
    -- countine counting    
    cnt_en  <= '1';
    FOR I IN 0 TO 9 LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;

    -- set the cnt_max
    cnt_max <= TO_UVEC(2**(c_cnt_w-1), c_cnt_w);    
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
    tb_end <= '1';
    WAIT;
  END PROCESS;

  -- device under test
  u_dut : ENTITY work.common_counter
  GENERIC MAP (
    g_init      => c_cnt_init,
    g_width     => c_cnt_w,
    g_step_size => 1
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    cnt_clr => cnt_clr,
    cnt_ld  => cnt_ld,
    cnt_en  => cnt_en,
    cnt_max => cnt_max,
    load    => load,
    count   => count
  );
      
END tb;


