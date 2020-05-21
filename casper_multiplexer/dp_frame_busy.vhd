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

-- Purpose: Output frame busy control signal that is active from sop to eop
-- Description:
--   The busy is active during the entire frame from sop to eop, so busy 
--   remains active in case valid goes low during a frame.
--   Default use g_pipeline=0 to have snk_in_busy in phase with sop and eop.
--   Use g_pipeline > 0 to register snk_in_busy to ease timing closure.

LIBRARY IEEE, common_pkg_lib, common_components_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ENTITY dp_frame_busy IS
  GENERIC (
    g_pipeline : NATURAL := 0
  );
  PORT (
    rst           : IN  STD_LOGIC;
    clk           : IN  STD_LOGIC;
    snk_in        : IN  t_dp_sosi;
    snk_in_busy   : OUT STD_LOGIC
  );
END dp_frame_busy;


ARCHITECTURE str OF dp_frame_busy IS

  SIGNAL busy : STD_LOGIC;
  
BEGIN

  u_common_switch : ENTITY common_components_lib.common_switch
  GENERIC MAP (
    g_rst_level    => '0',    -- Defines the output level at reset.
    g_priority_lo  => TRUE,   -- When TRUE then input switch_low has priority, else switch_high. Don't care when switch_high and switch_low are pulses that do not occur simultaneously.
    g_or_high      => TRUE,   -- When TRUE and priority hi then the registered switch_level is OR-ed with the input switch_high to get out_level, else out_level is the registered switch_level
    g_and_low      => FALSE   -- When TRUE and priority lo then the registered switch_level is AND-ed with the input switch_low to get out_level, else out_level is the registered switch_level
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,
    switch_high => snk_in.sop,    -- A pulse on switch_high makes the out_level go high
    switch_low  => snk_in.eop,    -- A pulse on switch_low makes the out_level go low
    out_level   => busy
  );
  
  u_common_pipeline_sl : ENTITY common_components_lib.common_pipeline_sl
  GENERIC MAP (
    g_pipeline       => g_pipeline,  -- 0 for wires, > 0 for registers, 
    g_reset_value    => 0,           -- 0 or 1, bit reset value,
    g_out_invert     => FALSE
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    in_dat  => busy,
    out_dat => snk_in_busy
  );
  
END str;
