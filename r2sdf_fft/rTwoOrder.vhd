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
library ieee, common_pkg_lib, casper_counter_lib, casper_ram_lib, common_components_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use common_components_lib.common_bit_delay;

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
        g_nof_points    : natural := 1024; --! Number of FFT points
        g_bit_flip      : boolean := true; --! Flip bits
        g_nof_chan      : natural := 0; --! Number of FFT channels
        g_dat_w         : natural := 36; --! Data width
        g_ram_primitive : string  := "auto" --! Which RAMs to use
    );
    port(
        clk      : in  std_logic;       --! Input clock source
        ce       : in  std_logic := '1'; --! Clock enable
        in_sync  : in  std_logic := '0'; --! Input sync pulse
        in_dat   : in  std_logic_vector(g_dat_w - 1 DOWNTO 0); --! Input data signal
        in_val   : in  std_logic;       --! In val (for delay)
        out_dat  : out std_logic_vector(g_dat_w - 1 DOWNTO 0); --! Output data
        out_sync : out std_logic;       --! Output sync pulse
        out_val  : out std_logic        --! Out value valid
    );
end entity rTwoOrder;

architecture rtl of rTwoOrder is

    constant c_nof_channels : natural := 2 ** g_nof_chan;
    constant c_dat_w        : natural := in_dat'length;
    constant c_page_size    : natural := g_nof_points * c_nof_channels;
    constant c_adr_points_w : natural := ceil_log2(g_nof_points);
    constant c_adr_chan_w   : natural := g_nof_chan;
    constant c_adr_tot_w    : natural := c_adr_points_w + c_adr_chan_w;
    constant c_count_lat    : natural := 1;
    constant c_ram_read_lat : natural := 1;
    constant c_nof_pages    : natural := 2;

    signal adr_points_cnt : std_logic_vector(c_adr_points_w - 1 downto 0);
    signal adr_chan_cnt   : std_logic_vector(c_adr_chan_w - 1 downto 0);
    signal adr_tot_cnt    : std_logic_vector(c_adr_tot_w - 1 downto 0);

    signal in_init     : STD_LOGIC := '1';
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

    p_clk : process(clk, in_sync)
    begin
        if in_sync = '1' and in_val = '1' then
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
            g_latency => c_count_lat,
            g_init    => 0,
            g_width   => ceil_log2(g_nof_points)
        )
        PORT MAP(
            rst    => in_sync,          --counters are reset by sync pulse
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
            g_latency => c_count_lat,
            g_init    => 0,
            g_width   => g_nof_chan
        )
        PORT MAP(
            clken  => ce,
            rst    => in_sync,
            clk    => clk,
            cnt_en => in_val,
            count  => adr_chan_cnt
        );
    u_buff : ENTITY casper_ram_lib.common_paged_ram_r_w
        GENERIC MAP(
            g_str           => "use_adr",
            g_data_w        => c_dat_w,
            g_nof_pages     => c_nof_pages,
            g_page_sz       => c_page_size,
            g_wr_start_page => 0,
            g_rd_start_page => 1,
            g_rd_latency    => c_ram_read_lat,
            g_ram_primitive => g_ram_primitive
        )
        PORT MAP(
            rst          => in_sync,
            clk          => clk,
            clken        => ce,
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

    --Delay sync out
    u_delay_sync : entity common_components_lib.common_bit_delay
        generic map(
            g_depth => c_page_size + c_ram_read_lat
        )
        port map(
            clk     => clk,
            rst     => '0',
            in_clr  => '0',
            in_bit  => in_sync,
            in_val  => in_val,
            out_bit => out_sync
        );

end rtl;
