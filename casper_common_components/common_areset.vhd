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


-- Purpose: Immediately apply reset and synchronously release it at rising clk
-- Description:
--   Using common_areset is equivalent to using common_async with same signal
--   applied to rst and din.

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;

ENTITY common_areset IS
  GENERIC (
    g_rst_level : STD_LOGIC := '1';
    g_delay_len : NATURAL   := c_meta_delay_len
  );
  PORT (
    in_rst    : IN  STD_LOGIC;
    clk       : IN  STD_LOGIC;
    out_rst   : OUT STD_LOGIC
  );
END;


ARCHITECTURE str OF common_areset IS
 
  CONSTANT c_rst_level_n : STD_LOGIC := NOT g_rst_level;
  
BEGIN

  -- When in_rst becomes g_rst_level then out_rst follows immediately (asynchronous reset apply).
  -- When in_rst becomes NOT g_rst_level then out_rst follows after g_delay_len cycles (synchronous reset release).
  
  -- This block can also synchronise other signals than reset:
  -- . g_rst_level = '0': output asynchronoulsy follows the falling edge input and synchronises the rising edge input.
  -- . g_rst_level = '1': output asynchronoulsy follows the rising edge input and synchronises the falling edge input.
  
  u_async : ENTITY work.common_async
  GENERIC MAP (
    g_rst_level => g_rst_level,
    g_delay_len => g_delay_len
  )
  PORT MAP (
    rst  => in_rst,
    clk  => clk,
    din  => c_rst_level_n,
    dout => out_rst
  );
  
END str;