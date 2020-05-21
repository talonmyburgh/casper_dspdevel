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

LIBRARY IEEE, common_components_lib;
USE IEEE.std_logic_1164.all;

-- Purpose:
--   Hold hld_ctrl active until next ready high when in_ctrl is active while
--   ready went low
-- Description:
--   When ready goes low there may still arrive one new valid data. The control
--   information for this data can then be held with this component. When ready
--   goes high again the held data can then be output and the hld_ctrl is 
--   released. After that the subsequent data output can come directly from the
--   up stream source, until ready goes low again.
-- Remarks:
-- . Ready latency RL = 1
-- . The in_ctrl is typically in_valid, in_sop or in_eop
-- . Typically used together with dp_hold_data

ENTITY dp_hold_ctrl IS
  PORT (
    rst      : IN  STD_LOGIC;
    clk      : IN  STD_LOGIC;
    ready    : IN  STD_LOGIC;
    in_ctrl  : IN  STD_LOGIC;
    hld_ctrl : OUT STD_LOGIC
  );
END dp_hold_ctrl;


ARCHITECTURE rtl OF dp_hold_ctrl IS
  
  SIGNAL hi_ctrl : STD_LOGIC;
  SIGNAL lo_ctrl : STD_LOGIC;

BEGIN

  hi_ctrl <=     in_ctrl AND NOT ready;  -- capture
  lo_ctrl <= NOT in_ctrl AND     ready;  -- release
  
  u_hld_ctrl : ENTITY common_components_lib.common_switch
  PORT MAP (
    rst         => rst,
    clk         => clk,
    switch_high => hi_ctrl,
    switch_low  => lo_ctrl,
    out_level   => hld_ctrl
  );
  
END rtl;
