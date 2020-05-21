--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
 
LIBRARY IEEE, common_pkg_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;

-- Purpose: Transmit continuous PRSG or COUNTER test sequence data.
-- Description:
--   The Tx test data can sequence data or constant value data dependent on
--   diag_dc. 
--   The Tx test sequence data can be PRSG or COUNTER dependent on diag_sel.
--   The Tx is enabled by diag_en. When the Tx is disabled then the sequence
--   data gets initialised with diag_init.
--   The out_ready acts as a data request. When the generator is enabled then
--   output is valid for every active out_ready, to support streaming flow
--   control. With g_latency=1 the out_val is active one cycle after diag_req,
--   by using g_latency=0 outval is active in the same cycle as diag_req.
--   Use diag_mod=0 for default binary wrap at 2**g_dat_w. For diag_rx_seq
--   choose diag_step = 2**g_seq_dat_w - diag_mod + g_cnt_incr to verify ok.

ENTITY diag_tx_seq IS
  GENERIC (
    g_latency  : NATURAL := 1;  -- default 1 for registered out_cnt/dat/val output, use 0 for immediate combinatorial out_cnt/dat/val output
    g_sel      : STD_LOGIC := '1';  -- '0' = PRSG, '1' = COUNTER
    g_init     : NATURAL := 0;      -- init value for out_dat when diag_en = '0'
    g_cnt_incr : INTEGER := 1;
    g_cnt_w    : NATURAL := c_word_w;
    g_dat_w    : NATURAL            -- >= 1, test data width
  );
  PORT (
    rst        : IN  STD_LOGIC;
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    -- Static control input (connect via MM or leave open to use default)
    diag_en    : IN  STD_LOGIC;           -- '0' = init and disable output sequence, '1' = enable output sequence
    diag_sel   : IN  STD_LOGIC := g_sel;  -- '0' = PRSG sequence data, '1' = COUNTER sequence data
    diag_dc    : IN  STD_LOGIC := '0';    -- '0' = output diag_sel sequence data, '1' = output constant diag_init data
    diag_init  : IN  STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := TO_UVEC(g_init, g_dat_w);  -- init value for out_dat when diag_en = '0'
    diag_mod   : IN  STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := TO_UVEC(0, g_dat_w);       -- default 0 to wrap modulo 2*g_dat_w
    -- ST output
    diag_req   : IN  STD_LOGIC := '1';   -- '1' = request output, '0' = halt output
    out_cnt    : OUT STD_LOGIC_VECTOR(g_cnt_w-1 DOWNTO 0);  -- count valid output test sequence data
    out_dat    : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);  -- output test sequence data
    out_val    : OUT STD_LOGIC                              -- '1' when out_dat is valid
  );
END diag_tx_seq;


ARCHITECTURE rtl OF diag_tx_seq IS

  CONSTANT c_lfsr_nr     : NATURAL := g_dat_w - c_common_lfsr_first;
  
  SIGNAL diag_dis        : STD_LOGIC;
  
  SIGNAL prsg            : STD_LOGIC_VECTOR(out_dat'RANGE);
  SIGNAL nxt_prsg        : STD_LOGIC_VECTOR(out_dat'RANGE);
  SIGNAL cntr            : STD_LOGIC_VECTOR(out_dat'RANGE) := (OTHERS=>'0');  -- init to avoid Warning: "NUMERIC_STD."<": metavalue detected" with UNSIGNED()
  SIGNAL next_cntr       : STD_LOGIC_VECTOR(out_dat'RANGE) := (OTHERS=>'0');  -- init to avoid Warning: "NUMERIC_STD."<": metavalue detected" with UNSIGNED()
  SIGNAL nxt_cntr        : STD_LOGIC_VECTOR(out_dat'RANGE);
  
  SIGNAL nxt_out_dat     : STD_LOGIC_VECTOR(out_dat'RANGE);
  SIGNAL nxt_out_val     : STD_LOGIC;

BEGIN

  diag_dis <= NOT diag_en;
  
  p_clk : PROCESS (rst, clk)
  BEGIN
    IF rst='1' THEN
      prsg         <= (OTHERS=>'0');
      cntr         <= (OTHERS=>'0');
    ELSIF rising_edge(clk) THEN
      IF clken='1' THEN
        prsg         <= nxt_prsg;
        cntr         <= nxt_cntr;
      END IF;
    END IF;
  END PROCESS;
  
  gen_latency : IF g_latency/=0 GENERATE
    p_clk : PROCESS (rst, clk)
    BEGIN
      IF rst='1' THEN
        out_dat      <= (OTHERS=>'0');
        out_val      <= '0';
      ELSIF rising_edge(clk) THEN
        IF clken='1' THEN
          out_dat      <= nxt_out_dat;
          out_val      <= nxt_out_val;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE;
  
  no_latency : IF g_latency=0 GENERATE
    out_dat      <= nxt_out_dat;
    out_val      <= nxt_out_val;
  END GENERATE;
  
  common_lfsr_nxt_seq(c_lfsr_nr,    -- IN
                      g_cnt_incr,   -- IN
                      diag_en,      -- IN
                      diag_req,     -- IN
                      diag_init,    -- IN
                      prsg,         -- IN
                      cntr,         -- IN
                      nxt_prsg,     -- OUT
                      next_cntr);   -- OUT
                      
  nxt_cntr <= next_cntr WHEN UNSIGNED(next_cntr) < UNSIGNED(diag_mod) ELSE SUB_UVEC(next_cntr, diag_mod);
  
  nxt_out_dat <= diag_init WHEN diag_dc='1' ELSE prsg WHEN diag_sel='0' ELSE cntr;
  nxt_out_val <= diag_en AND diag_req;  -- 'en' for entire test on/off, 'req' for dynamic invalid gaps in the stream
  
  -- Count number of valid output data
  u_common_counter : ENTITY casper_counter_lib.common_counter
  GENERIC MAP (
    g_latency   => g_latency,  -- default 1 for registered count output, use 0 for immediate combinatorial count output
    g_width     => g_cnt_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => clken,
    cnt_clr => diag_dis,    -- synchronous cnt_clr is only interpreted when clken is active
    cnt_en  => nxt_out_val,
    count   => out_cnt
  );
  
END rtl;
