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
use IEEE.numeric_std.all;
library common_pkg_lib;
use common_pkg_lib.common_pkg.all;
entity common_delay is
	generic(
		g_dat_w : NATURAL := 8;         --! need g_dat_w to be able to use (others=>'') assignments for two dimensional unconstraint vector arrays
		g_depth : NATURAL := 16         --! Delay depth
	);
	port(
		clk     : in  STD_LOGIC;        --! Clock input
		in_val  : in  STD_LOGIC := '1'; --! Select input value
		in_dat  : in  STD_LOGIC_VECTOR(g_dat_w - 1 downto 0); --! Input value
		out_dat : out STD_LOGIC_VECTOR(g_dat_w - 1 downto 0) --! Output value
	);
end entity common_delay;

architecture rtl of common_delay is

	-- Use index (0) as combinatorial input and index(1:g_depth) for the shift
	-- delay, in this way the t_dly_arr type can support all g_depth >= 0
	type t_dly_arr is array (0 to g_depth) of STD_LOGIC_VECTOR(g_dat_w - 1 downto 0);

	
    type t_mem_arr is array (0 to g_depth-2) of STD_LOGIC_VECTOR(g_dat_w - 1 downto 0);
    --signal shift_reg : t_dly_arr := (others => (others => '0'));
begin

    gen_zero : if g_depth = 0 generate 
    signal shift_reg : t_dly_arr := (others => (others => '0'));
    begin
        shift_reg(0) <= in_dat;
	    out_dat <= shift_reg(g_depth);
	end generate;
	gen_regSR : if g_depth > 0 and g_depth<128 generate -- Use a shift register implementation
        signal shift_reg : t_dly_arr := (others => (others => '0'));
    begin
    
		shift_reg(0) <= in_dat;
	    out_dat <= shift_reg(g_depth);
		p_clk : process(clk)
		begin
			if rising_edge(clk) then
				if in_val = '1' then
					shift_reg(1 to g_depth) <= shift_reg(0 to g_depth - 1);
				end if;
			end if;
		end process;
	end generate;
	gen_regMEM : if g_depth >= 128 generate -- Use a Memory implementation
	--signal mem_addr_rd : unsigned(ceil_log2(g_depth-1)-1 downto 0) := to_unsigned(g_depth-2,ceil_log2(g_depth-1));
	signal mem_addr_wr : unsigned(ceil_log2(g_depth-1)-1 downto 0) := to_unsigned(0,ceil_log2(g_depth-1));
	signal memory : t_mem_arr := (others => (others => '0'));
    attribute ram_style: string;
    attribute ram_style of memory: signal is "block";
	signal out_datmem  : STD_LOGIC_VECTOR(g_dat_w - 1 downto 0) := (others => '0'); --! Output value
    begin
        out_dat <= out_datmem;
        --assert out_datmem = shift_reg(g_depth) report "non matching data" severity failure;
		p_clk : process(clk)
		begin
			if rising_edge(clk) then
			    
				if in_val = '1' then
				    out_datmem <= memory(to_integer(mem_addr_wr));
					memory(to_integer(mem_addr_wr)) <= in_dat;
					--mem_addr_rd <= mem_addr_wr;
					if mem_addr_wr=(g_depth-2) then
					   mem_addr_wr <= to_unsigned(0,mem_addr_wr'length);
					else
					   mem_addr_wr <= mem_addr_wr + 1;
					end if;

					--shift_reg(1 to g_depth) <= shift_reg(0 to g_depth - 1);
				end if;
			end if;
		end process;
	end generate;
end rtl;
