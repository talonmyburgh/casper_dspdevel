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

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY tb_tb_common_add_sub IS
END tb_tb_common_add_sub;

ARCHITECTURE tb OF tb_tb_common_add_sub IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN
  -- g_direction    : STRING := "SUB";  -- "SUB" or "ADD"
  -- g_sel_add      : STD_LOGIC :='1';  -- '0' = sub, '1' = add, only valid for g_direction = "BOTH"
  -- g_pipeline_in  : NATURAL := 0;     -- input pipelining 0 or 1
  -- g_pipeline_out : NATURAL := 1;     -- output pipelining >= 0
  -- g_in_dat_w     : NATURAL := 5;
  -- g_out_dat_w    : NATURAL := 5;     -- g_in_dat_w or g_in_dat_w+1
    
  u_add_5_5      : ENTITY work.tb_common_add_sub GENERIC MAP ("ADD",  '1', 0, 2, 5, 5);
  u_add_5_6      : ENTITY work.tb_common_add_sub GENERIC MAP ("ADD",  '1', 0, 2, 5, 6);
  u_sub_5_5      : ENTITY work.tb_common_add_sub GENERIC MAP ("SUB",  '0', 0, 2, 5, 5);
  u_sub_5_6      : ENTITY work.tb_common_add_sub GENERIC MAP ("SUB",  '0', 0, 2, 5, 6);
  u_both_add_5_5 : ENTITY work.tb_common_add_sub GENERIC MAP ("BOTH", '1', 0, 2, 5, 5);
  u_both_add_5_6 : ENTITY work.tb_common_add_sub GENERIC MAP ("BOTH", '1', 0, 2, 5, 6);
  u_both_sub_5_5 : ENTITY work.tb_common_add_sub GENERIC MAP ("BOTH", '0', 0, 2, 5, 5);
  u_both_sub_5_6 : ENTITY work.tb_common_add_sub GENERIC MAP ("BOTH", '0', 0, 2, 5, 6);
  
END tb;
