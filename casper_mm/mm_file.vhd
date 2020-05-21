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

-- Author:
--   D. van der Schuur May 2012  Initial
--   E. Kooistra       Jan 2018  Removed unused generics and added remarks.
-- Purpose: Provide access to an MM slave via file IO
-- Description:
--   See mm_file_pkg.
--
-- * Optional MM file IO throttle via g_mm_timeout, g_mm_pause:
--   Default g_mm_timeout=0 ns for full speed MM file IO rate. Optional use
--   g_mm_timeout>0 ns to throttle MM file IO rate. The mm_master_out wr and
--   rd strobes are monitored. As long as a strobe occurs within
--   g_mm_timeout then the MM file IO operates at full speed. When no strobe
--   occurs within g_mm_timeout, then a delay of g_mm_pause is inserted
--   until the next MM file IO access will be done. This throttling reduces
--   the file IO rate when the MM slave is idle and picks up again at full
--   speed when MM slave accesses appear again.
--
--   The g_mm_timeout is in ns, and not defined in number of mm_clk cycles,
--   to make it independent of the simulation mm_clk period. This is
--   important to be able to handle clock domain crossings between a fast
--   simulation mm_clk and a relatively slow internal dp_clk. If the
--   g_mm_timeout is too short then it will occur for every MM access that
--   needs a MM-DP clock domain crossing. A dp_clk typically runs at
--   about 100 or 200 MHz, so period < about 10 ns. A clock domain crossing
--   takes about 25 clock cycles in both clock domains (see
--   common_reg_cross_domain.vhd). Hence a suitable default value for 
--   g_mm_timeout is about 250 ns. With some margin use 1000 ns. 
--   The g_mm_pause is defined in ns, but could as well have been defined
--   in number mm_clk cycle. Use g_mm_pause default 100 ns to have a factor
--   1000 reduction in file IO rate witk c_mmf_mm_clk_period = 100 ps, while
--   not introducing too much delay in case a new MM access is pending.
--
-- Remarks:
-- * Positional mapping of generics and port:
--   If necessary new generics or ports should be added after the existing
--   generics or ports, because then existing mm_file instances that use 
--   positional mapping instead of explicit name mapping (with =>) still 
--   compile ok.
--
-- * Default g_mm_rd_latency=2:
--   The default g_mm_rd_latency=2 to fit both MM reg (which typically have rd
--   latency 1) and MM ram (for which some have rd latency 2). This works
--   because the mm_master_out.rd strobes have gaps. The maximum rd strobe 
--   rate appears to be 1 strobe in every 4 cycles. By using default 
--   g_mm_rd_latency=2 the mm_file instances do not explicitly have to map the
--   actual MM slave rd latency, because using 2 fits all. This ensures 
--   that all existing mm_file instances that do not map g_mm_rd_latency still
--   work and for new mm_file instances it avoids the need to know whether the
--   MM slave actually has rd latency 1 or 2.
--
-- * Default g_file_enable='1':
--   Default the mm_file instance will open the files. However if the MM slave
--   will not be used in a test, then it can be good to use g_file_enable='0'
--   to avoid these files. For multi tb or tb with many mm_file instances this 
--   limits the number of file handlers and may help to improve the simulation
--   speed (and stability).
--
LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE work.tb_common_mem_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE work.mm_file_pkg.ALL;
USE IEEE.std_logic_textio.ALL;
USE std.textio.ALL;

ENTITY mm_file IS
  GENERIC (
    g_file_prefix       : STRING;            -- e.g. "ppsh" will create i/o files ppsh_stat.txt and ppsh_ctrl.txt
    g_file_enable       : STD_LOGIC := '1';  -- default use '1' to enable file IO, use '0' to disable file IO and force mm_master_out to c_mem_mosi_rst
    g_mm_rd_latency     : NATURAL := 2;      -- default use 2 to fit 0, 1 or 2, must be >= read latency of the MM slave
    g_mm_timeout        : TIME := c_mmf_mm_timeout;  -- use 0 ns for full speed MM, use > 0 ns to define time without MM access after which the MM file IO is paused
    g_mm_pause          : TIME := c_mmf_mm_pause     -- defines time for which MM file IO is paused to reduce the file IO rate when the MM slave is idle
  );                                          
  PORT (
    mm_rst        : IN  STD_LOGIC;
    mm_clk        : IN  STD_LOGIC;

    mm_master_out : OUT t_mem_mosi := c_mem_mosi_rst;
    mm_master_in  : IN  t_mem_miso := c_mem_miso_rst
  );
END mm_file;


ARCHITECTURE str OF mm_file IS

  CONSTANT c_rd_file_name : STRING :=  g_file_prefix & ".ctrl";
  CONSTANT c_wr_file_name : STRING :=  g_file_prefix & ".stat";

  SIGNAL i_mm_master_out : t_mem_mosi;
  
  -- Optional file IO throttle control
  SIGNAL strobe          : STD_LOGIC;
  SIGNAL pause           : STD_LOGIC;
  SIGNAL polling         : STD_LOGIC := '0';  -- monitor signal to view in Wave window when mmf_mm_from_file() is busy
  SIGNAL timebegin       : TIME := 0 ns;
  SIGNAL timeout         : TIME := 0 ns;
  
BEGIN

  mm_master_out <= i_mm_master_out;
  
  no_file : IF g_file_enable='0' GENERATE
    i_mm_master_out <= c_mem_mosi_rst;
  END GENERATE;
  
  gen_file : IF g_file_enable='1' GENERATE

    p_file_to_mm : PROCESS
    BEGIN
      i_mm_master_out <= c_mem_mosi_rst;   
  
      -- Create the ctrl file that we're going to read from
      print_str("[" & time_to_str(NOW) & "] " & c_rd_file_name & ": Created" );
      mmf_file_create(c_rd_file_name);
  
      WHILE TRUE LOOP
        mmf_mm_from_file(mm_clk, mm_rst, i_mm_master_out, mm_master_in, c_rd_file_name, c_wr_file_name, g_mm_rd_latency);
        
        -- Optional file IO throttle control
        IF g_mm_timeout>0 ns AND pause='1' THEN
          polling <= '0';
          WAIT FOR g_mm_pause;  -- Pause the file IO when MM timeout is enabled and no strobes appeared for g_mm_timeout
          
          proc_common_wait_some_cycles(mm_clk, 1);  -- Realign to mm_clk, not needed but done to resemble return from mmf_mm_from_file()
          polling <= '1';
        END IF;
      END LOOP;
  
      WAIT;
    END PROCESS;
  
    -- Optional file IO throttle control
    gen_mm_timeout_control : IF g_mm_timeout>0 ns GENERATE
      strobe <= i_mm_master_out.wr OR i_mm_master_out.rd;  -- detect MM access
      
      pause <= NOT strobe WHEN timeout>g_mm_timeout ELSE '0';  -- issue MM file IO pause after strobe timeout
      
      -- Use mm_clk event to update time based on NOW, without event it does not update
      p_mm_now : PROCESS(mm_rst, mm_clk)
      BEGIN
        IF mm_rst='1' THEN
          -- during reset no timeouts
          timebegin <= NOW;
          timeout <= 0 ns;
        ELSE
          -- use MM access to restart timeout
          IF strobe='1' THEN
            timebegin <= NOW;
          END IF;
          timeout <= NOW - timebegin;
        END IF;          
      END PROCESS;
    END GENERATE;

  END GENERATE;

END str;

