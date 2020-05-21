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

LIBRARY IEEE, common_pkg_lib, common_components_lib, casper_ram_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;

-- Purpose: Get in_dat from in_clk to out_clk domain when in_new is asserted.
-- Remarks:
-- . If in_new is a pulse, then new in_dat is available after g_in_new_latency.
-- . It is also allowed to hold in_new high, then out_new will pulse once for
--   every 24 out_clk cycles.
-- . Use in_done to be sure that in_dat due to in_new has crossed the clock
--   domain, in case of multiple in_new pulses in a row the in_done will only
--   pulse when this state remains s_idle, so after the last in_new.
-- . If the in_dat remains unchanged during the crossing of in_new to out_en
--   then g_input_buf=FALSE may be used to save some flipflops

ENTITY common_reg_cross_domain IS
  GENERIC (
    g_input_buf      : BOOLEAN := TRUE;
    g_in_new_latency : NATURAL := 0;  -- >= 0
    g_out_dat_init   : STD_LOGIC_VECTOR(c_mem_reg_init_w-1 DOWNTO 0) := (OTHERS => '0')
  );
  PORT (
    in_rst      : IN  STD_LOGIC;
    in_clk      : IN  STD_LOGIC;
    in_new      : IN  STD_LOGIC := '1';  -- when '1' then new in_dat is available after g_in_new_latency
    in_dat      : IN  STD_LOGIC_VECTOR;
    in_done     : OUT STD_LOGIC;         -- pulses when no more pending in_new
    out_rst     : IN  STD_LOGIC;
    out_clk     : IN  STD_LOGIC;
    out_dat     : OUT STD_LOGIC_VECTOR;
    out_new     : OUT STD_LOGIC          -- when '1' then the out_dat was updated with in_dat due to in_new
  );
END common_reg_cross_domain;


ARCHITECTURE rtl OF common_reg_cross_domain IS

  CONSTANT c_dat : STD_LOGIC_VECTOR(in_dat'RANGE) := g_out_dat_init(in_dat'RANGE);

  ------------------------------------------------------------------------------
  -- in_clk domain
  ------------------------------------------------------------------------------
  SIGNAL reg_new          : STD_LOGIC_VECTOR(0 TO g_in_new_latency) := (OTHERS=>'0');
  SIGNAL nxt_reg_new      : STD_LOGIC_VECTOR(reg_new'RANGE);
  
  SIGNAL in_buf           : STD_LOGIC_VECTOR(c_dat'RANGE) := c_dat;
  SIGNAL in_buf_reg       : STD_LOGIC_VECTOR(c_dat'RANGE) := c_dat;
  SIGNAL nxt_in_buf_reg   : STD_LOGIC_VECTOR(c_dat'RANGE);
  
  -- Register access clock domain crossing
  TYPE t_state_enum IS (s_idle, s_busy);
  
  SIGNAL cross_req        : STD_LOGIC;
  SIGNAL cross_busy       : STD_LOGIC;
  SIGNAL nxt_in_done      : STD_LOGIC;
  SIGNAL state            : t_state_enum;
  SIGNAL nxt_state        : t_state_enum;
  SIGNAL prev_state       : t_state_enum;
  SIGNAL in_new_hold      : STD_LOGIC;
  SIGNAL nxt_in_new_hold  : STD_LOGIC;
  
  ------------------------------------------------------------------------------
  -- out_clk domain
  ------------------------------------------------------------------------------
  SIGNAL out_en           : STD_LOGIC;
  SIGNAL i_out_dat        : STD_LOGIC_VECTOR(c_dat'RANGE) := c_dat;  -- register init without physical reset
  SIGNAL nxt_out_dat      : STD_LOGIC_VECTOR(c_dat'RANGE);
  
BEGIN

  out_dat <= i_out_dat;
  
  ------------------------------------------------------------------------------
  -- in_clk domain
  ------------------------------------------------------------------------------
  
  reg_new(0) <= in_new;
  
  gen_latency : IF g_in_new_latency>0 GENERATE
    p_reg_new : PROCESS(in_rst, in_clk)
    BEGIN
      IF in_rst='1' THEN
        reg_new(1 TO g_in_new_latency) <= (OTHERS=>'0');
      ELSIF rising_edge(in_clk) THEN
        reg_new(1 TO g_in_new_latency) <= nxt_reg_new(1 TO g_in_new_latency);
      END IF;
    END PROCESS;
    
    nxt_reg_new(1 TO g_in_new_latency) <= reg_new(0 TO g_in_new_latency-1);
  END GENERATE;
  
  p_in_clk : PROCESS(in_rst, in_clk)
  BEGIN
    IF in_rst='1' THEN
      in_new_hold <= '0';
      in_done     <= '0';
      state       <= s_idle;
      prev_state  <= s_idle;
    ELSIF rising_edge(in_clk) THEN
      in_buf_reg  <= nxt_in_buf_reg;
      in_new_hold <= nxt_in_new_hold;
      in_done     <= nxt_in_done;
      state       <= nxt_state;
      prev_state  <= state;
    END IF;
  END PROCESS;
  
  -- capture the new register data
  no_in_buf : IF g_input_buf=FALSE GENERATE
    in_buf <= in_dat;  -- assumes that in_dat remains unchanged during the crossing of in_new to out_en
  END GENERATE;
  
  gen_in_buf : IF g_input_buf=TRUE GENERATE
    nxt_in_buf_reg <= in_dat WHEN cross_req='1' ELSE in_buf_reg;
    in_buf         <= in_buf_reg;
  END GENERATE;

  
  -- handshake control of the clock domain crossing by u_cross_req
  -- hold any subsequent in_new during cross domain busy to ensure that the out_dat will get the latest value of in_dat
  p_state : PROCESS(state, prev_state, reg_new, in_new_hold, cross_busy)
  BEGIN
    cross_req <= '0';
    nxt_in_done <= '0';
    nxt_in_new_hold <= in_new_hold;
    nxt_state <= state;
    CASE state IS
      WHEN s_idle =>
        nxt_in_new_hold <= '0';
        IF reg_new(g_in_new_latency)='1' OR in_new_hold='1' THEN
          cross_req <= '1';
          nxt_state <= s_busy;
        ELSIF UNSIGNED(reg_new)=0 AND prev_state=s_busy THEN
          nxt_in_done <= '1';  -- no pending in_new at input or in shift register and just left s_busy, so signal in_done
        END IF;
      WHEN OTHERS => -- s_busy
        IF reg_new(g_in_new_latency)='1' THEN
          nxt_in_new_hold <= '1';
        END IF;
        IF cross_busy='0' THEN
          nxt_state <= s_idle;
        END IF;
    END CASE;
  END PROCESS;
  
  ------------------------------------------------------------------------------
  -- cross clock domain
  ------------------------------------------------------------------------------
  u_cross_req : ENTITY common_components_lib.common_spulse
  PORT MAP (
    in_rst     => in_rst,
    in_clk     => in_clk,
    in_pulse   => cross_req,
    in_busy    => cross_busy,
    out_rst    => out_rst,
    out_clk    => out_clk,
    out_pulse  => out_en
  );
  
  ------------------------------------------------------------------------------
  -- out_clk domain
  ------------------------------------------------------------------------------
  p_out_clk : PROCESS(out_rst, out_clk)
  BEGIN
    IF out_rst='1' THEN
      out_new   <= '0';
    ELSIF rising_edge(out_clk) THEN
      i_out_dat <= nxt_out_dat;
      out_new   <= out_en;
    END IF;
  END PROCESS;

  -- some clock cycles after the cross_req the in_buf data is stable for sure
  nxt_out_dat <= in_buf WHEN out_en='1' ELSE i_out_dat;
  
END rtl;
