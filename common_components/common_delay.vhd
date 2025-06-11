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
library casper_ram_lib;
use casper_ram_lib.common_ram_pkg.all;
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

	
    type t_mem_arr is array (0 to (((2**ceil_log2(g_depth))-1))) of STD_LOGIC_VECTOR(g_dat_w - 1 downto 0);
    --signal shift_reg : t_dly_arr := (others => (others => '0'));
begin

    gen_zero : if g_depth = 0 generate 
    signal shift_reg : t_dly_arr; -- := (others => (others => '0'));
    begin
        shift_reg(0) <= in_dat;
	    out_dat <= shift_reg(g_depth);
	end generate;
	gen_regSR : if g_depth > 0 and g_depth<128 generate -- Use a shift register implementation
        signal shift_reg : t_dly_arr; -- := (others => (others => '0'));
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
	signal mem_addr_wr 		: unsigned(ceil_log2(g_depth-1)-1 downto 0) := to_unsigned(g_depth-5,ceil_log2(g_depth));
	signal mem_addr_rd 		: unsigned(ceil_log2(g_depth-1)-1 downto 0) := to_unsigned(0,ceil_log2(g_depth));
	signal out_datmem  		: STD_LOGIC_VECTOR(g_dat_w - 1 downto 0); --:= (others => '0'); --! Output value
	signal out_dat_p 		: STD_LOGIC_VECTOR(g_dat_w - 1 downto 0); --:= (others => '0'); --! Output value
	signal in_dat_d1		: STD_LOGIC_VECTOR(g_dat_w - 1 downto 0); --:= (others => '0'); --! Output value
	signal in_dat_d2		: STD_LOGIC_VECTOR(g_dat_w - 1 downto 0); --:= (others => '0'); --! Output value
	attribute DONT_TOUCH : string;
	attribute KEEP : string;
	attribute KEEP of out_dat_p : signal is "TRUE";  -- try to prevent this signal from being absorbed into the block
	attribute DONT_TOUCH of out_dat_p : signal is "TRUE"; -- try to prevent this signal from being absorbed into the block



    begin
        --out_dat <= out_datmem;
		--shift_reg(0) <= in_dat;
		--out_shift    <= shift_reg(g_depth);
        --assert out_datmem = shift_reg(g_depth-2) report "non matching data" severity failure;
		--p_clk : process(clk)
		--begin
		--	if rising_edge(clk) then
		--		if in_val = '1' then
		--		    out_datmem <= memory(to_integer(mem_addr_rd));
		--			memory(to_integer(mem_addr_wr)) <= in_dat;
		--			--shift_reg(1 to g_depth) <= shift_reg(0 to g_depth - 1);
		--		end if;
		--	end if;
		--end process;
		RamInst : entity casper_ram_lib.tech_memory_ram_cr_cw
			generic map(
				g_adr_w         => ceil_log2(g_depth-1),
				g_dat_w         => g_dat_w,
				g_nof_words     => 2**ceil_log2(g_depth),
				g_rd_latency    => 1
				--g_init_file     => g_init_file,
				--g_ram_primitive => g_ram_primitive
			)
			port map(
				data      => in_dat_d2,
				rdaddress => std_logic_vector(mem_addr_rd),
				rdclock   => clk,
				rdclocken => in_val,
				wraddress => std_logic_vector(mem_addr_wr),
				wrclock   => clk,
				wrclocken => in_val,
				wren      => in_val,
				q         => out_datmem
			);
		
		--RamInst : entity casper_ram_lib.common_ram_r_w
		--	generic map(
		--		g_ram            => c_mem_settings,
		--		--g_init_file      => g_init_file,
		--		g_true_dual_port => false
		--		--g_ram_primitive  => g_ram_primitive
		--	)
		--	port map(
		--		clk    => clk,
		--		clken  => in_val,
		--		wr_en  => in_val,
		--		wr_adr => std_logic_vector(mem_addr_wr),
		--		wr_dat => in_dat,
		--		rd_en  => in_val,
		--		rd_adr => std_logic_vector(mem_addr_rd),
		--		rd_dat => out_datmem,
		--		rd_val => open
		--	);
		
		reg_data : process (clk)
		begin
			if rising_edge(clk) then
				if in_val='1' then
					in_dat_d1 <= in_dat;
					in_dat_d2 <= in_dat_d1;
					out_dat_p <= out_datmem;
					out_dat <= out_dat_p;
					mem_addr_wr <= mem_addr_wr + 1;
					mem_addr_rd <= mem_addr_rd + 1;
				end if;
			end if;
		end process;

					
	end generate;
end rtl;
