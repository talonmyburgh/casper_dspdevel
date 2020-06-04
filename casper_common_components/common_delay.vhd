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

--!   Purpose: Shift register for data
--!   Description:
--!     Delays input data by g_depth. The delay line shifts when in_val is high,
--!     indicating an active clock cycle.

library ieee;
use IEEE.STD_LOGIC_1164.all;

entity common_delay is
  generic (
    g_dat_w    : NATURAL := 8;   --! need g_dat_w to be able to use (others=>'') assignments for two dimensional unconstraint vector arrays
    g_depth    : NATURAL := 16   --! Delay depth
  );
  port (
    clk      : in  STD_LOGIC; --! Clock input
    in_val   : in  STD_LOGIC := '1'; --! Select input value
    in_dat   : in  STD_LOGIC_VECTOR(g_dat_w-1 downto 0); --! Input value
    out_dat  : out STD_LOGIC_VECTOR(g_dat_w-1 downto 0) --! Output value
  );
end entity common_delay;

architecture rtl of common_delay is

  -- Use index (0) as combinatorial input and index(1:g_depth) for the shift
  -- delay, in this way the t_dly_arr type can support all g_depth >= 0
  type t_dly_arr is array (0 to g_depth) of STD_LOGIC_VECTOR(g_dat_w-1 downto 0);

  signal shift_reg : t_dly_arr := (others=>(others=>'0'));

begin

  shift_reg(0) <= in_dat;
  
  out_dat <= shift_reg(g_depth);

  gen_reg : if g_depth>0 generate
    p_clk : process(clk)
    begin
      if rising_edge(clk) then
        if in_val='1' then
          shift_reg(1 to g_depth) <= shift_reg(0 to g_depth-1);
        end if;
      end if;
    end process;
  end generate;

end rtl;