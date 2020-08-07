--! @file
--! @brief Pipelined FFT reorder module

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

--! Libraries: IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib
library ieee, common_pkg_lib, casper_counter_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;

--! @dot 
--! digraph rTwoOrder {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! rTwoOrder;
--! node [shape=plaintext];
--! clk;
--! rst;
--! in_dat;
--! in_val;
--! out_dat;
--! out_val;
--! clk -> rTwoOrder;
--! rst -> rTwoOrder;
--! in_dat -> rTwoOrder;
--! in_val -> rTwoOrder;
--! rTwoOrder -> out_dat;
--! rTwoOrder -> out_val;
--!}
--! @enddot

entity rTwoOrder is
	generic(
		g_device     : string  := "7SERIES"; --! Specify product series, 7SERIES is default
		g_technology : natural := 0;    --! 0 for Xilinx products, 1 for Alterra 
		g_nof_points : natural := 1024; --! Number of FFT points
		g_bit_flip   : boolean := true; --! Flip bits
		g_nof_chan   : natural := 0;    --! Number of FFT channels
		g_dat_w      : natural := 36    --! Data width
	);
	port(
		clk     : in  std_logic;        --! Input clock source
		rst     : in  std_logic;        --! Reset signal
		in_dat  : in  std_logic_vector(g_dat_w - 1 DOWNTO 0); --! Input data signal
		in_val  : in  std_logic;        --! In val (for delay)
		out_dat : out std_logic_vector(g_dat_w - 1 DOWNTO 0); --! Output data
		out_val : out std_logic         --! Out value valid
	);
end entity rTwoOrder;

architecture rtl of rTwoOrder is

	constant c_nof_channels : natural := 2**g_nof_chan;
	constant c_dat_w        : natural := in_dat'length;
	constant c_page_size    : natural := g_nof_points * c_nof_channels;
	constant c_adr_points_w : natural := ceil_log2(g_nof_points);
	constant c_adr_chan_w   : natural := g_nof_chan;
	constant c_adr_tot_w    : natural := c_adr_points_w + c_adr_chan_w;

	signal adr_points_cnt : std_logic_vector(c_adr_points_w - 1 downto 0);
	signal adr_chan_cnt   : std_logic_vector(c_adr_chan_w - 1 downto 0);
	signal adr_tot_cnt    : std_logic_vector(c_adr_tot_w - 1 downto 0);

	signal in_init     : STD_LOGIC;
	signal nxt_in_init : STD_LOGIC;
	signal in_en       : STD_LOGIC;

	signal cnt_ena : std_logic;

	signal next_page : STD_LOGIC;

	signal wr_en  : STD_LOGIC;
	signal wr_adr : STD_LOGIC_VECTOR(c_adr_tot_w - 1 DOWNTO 0);
	signal wr_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);

	signal rd_en  : STD_LOGIC;
	signal rd_adr : STD_LOGIC_VECTOR(c_adr_tot_w - 1 DOWNTO 0);
	signal rd_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);
	signal rd_val : STD_LOGIC;

begin

	out_dat <= rd_dat;
	out_val <= rd_val;

	p_clk : process(clk, rst)
	begin
		if rst = '1' then
			in_init <= '1';
		elsif rising_edge(clk) then
			in_init <= nxt_in_init;
		end if;
	end process;

	nxt_in_init <= '0' WHEN next_page = '1' ELSE in_init; -- keep in_init active until the first block has been written

	in_en <= NOT in_init;               -- disable reading of the first block for convenience in verification, because it contains undefined values

	wr_dat <= in_dat;
	wr_en  <= in_val;
	rd_en  <= in_val AND in_en;

	next_page <= '1' when unsigned(adr_tot_cnt) = c_page_size - 1 and wr_en = '1' else '0';

	adr_tot_cnt <= adr_chan_cnt & adr_points_cnt;

	gen_bit_flip : if g_bit_flip = true generate
		wr_adr <= adr_chan_cnt & flip(adr_points_cnt); -- flip the addresses to perform the reorder
	end generate;
	no_bit_flip : if g_bit_flip = false generate
		wr_adr <= adr_tot_cnt;          -- do not flip the addresses for easier debugging with tb_rTwoOrder
	end generate;

	rd_adr <= adr_tot_cnt;

	u_adr_point_cnt : entity casper_counter_lib.common_counter
		generic map(
			g_latency => 1,
			g_init    => 0,
			g_width   => ceil_log2(g_nof_points)
		)
		PORT MAP(
			rst    => rst,
			clk    => clk,
			cnt_en => cnt_ena,
			count  => adr_points_cnt
		);

	-- Generate on c_nof_channels to avoid simulation warnings on TO_UINT(adr_chan_cnt) when adr_chan_cnt is a NULL array
	one_chan : if c_nof_channels = 1 generate
		cnt_ena <= '1' when in_val = '1' else '0';
	end generate;
	more_chan : if c_nof_channels > 1 generate
		cnt_ena <= '1' when in_val = '1' and TO_UINT(adr_chan_cnt) = c_nof_channels - 1 else '0';
	end generate;

	u_adr_chan_cnt : entity casper_counter_lib.common_counter
		generic map(
			g_latency => 1,
			g_init    => 0,
			g_width   => g_nof_chan
		)
		PORT MAP(
			rst    => rst,
			clk    => clk,
			cnt_en => in_val,
			count  => adr_chan_cnt
		);
	g36 : if ((c_dat_w <= 72) and (37 <= c_dat_w) and (c_adr_tot_w = 9)) or ((c_dat_w <= 36) and (19 <= c_dat_w) and (c_adr_tot_w = 10)) or ((c_dat_w <= 18) and (10 <= c_dat_w) and (c_adr_tot_w = 11)) or ((c_dat_w <= 9) and (5 <= c_dat_w) and (c_adr_tot_w = 12)) or (((c_dat_w = 3) or (c_dat_w = 4)) and (c_adr_tot_w = 13)) or (c_dat_w = 2 and c_adr_tot_w = 14) or (c_dat_w = 1 and c_adr_tot_w = 15) generate
	begin
		u_buff : ENTITY casper_ram_lib.common_paged_ram_r_w
			GENERIC MAP(
				g_technology    => 0,
				g_str           => "use_mux",
				g_data_w        => c_dat_w,
				g_nof_pages     => 2,
				g_page_sz       => c_page_size,
				g_wr_start_page => 0,
				g_rd_start_page => 1,
				g_rd_latency    => 1,
				g_bram_size     => "36Kb",
				g_device        => g_device
			)
			PORT MAP(
				rst          => rst,
				clk          => clk,
				clken        => '1',
				wr_next_page => next_page,
				wr_adr       => wr_adr,
				wr_en        => wr_en,
				wr_dat       => wr_dat,
				rd_next_page => next_page,
				rd_adr       => rd_adr,
				rd_en        => rd_en,
				rd_dat       => rd_dat,
				rd_val       => rd_val
			);
	end generate;

	g18 : if ((c_dat_w <= 36) and (19 <= c_dat_w) and (c_adr_tot_w = 9)) or ((c_dat_w <= 18) and (10 <= c_dat_w) and (c_adr_tot_w = 10)) or ((c_dat_w <= 9) and (5 <= c_dat_w) and (c_adr_tot_w = 11)) or (((c_dat_w = 3) or (c_dat_w = 4)) and (c_adr_tot_w = 12)) or (c_dat_w = 2 and c_adr_tot_w = 13) or (c_dat_w = 1 and c_adr_tot_w = 14) generate
	begin
		u_buff : ENTITY casper_ram_lib.common_paged_ram_r_w
			GENERIC MAP(
				g_technology    => 0,
				g_str           => "use_mux",
				g_data_w        => c_dat_w,
				g_nof_pages     => 2,
				g_page_sz       => c_page_size,
				g_wr_start_page => 0,
				g_rd_start_page => 1,
				g_rd_latency    => 1,
				g_bram_size     => "18Kb",
				g_device        => g_device
			)
			PORT MAP(
				rst          => rst,
				clk          => clk,
				clken        => '1',
				wr_next_page => next_page,
				wr_adr       => wr_adr,
				wr_en        => wr_en,
				wr_dat       => wr_dat,
				rd_next_page => next_page,
				rd_adr       => rd_adr,
				rd_en        => rd_en,
				rd_dat       => rd_dat,
				rd_val       => rd_val
			);
	end generate;

end rtl;
