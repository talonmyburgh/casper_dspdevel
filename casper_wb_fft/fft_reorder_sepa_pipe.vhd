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
--
-- Purpose: This unit performs the reordering and the separation for the two real
--          input option of the complex fft.
--          It can also perform only one of the two functions(specified via generics).
--
-- Description: The incoming data is written (normal or reordered, based on g_bit_flip)
--              to the first page of a dual page memory. When the first page is full, 
--              the write process will continue on the second page. Meanwhile the read 
--              process will start to read the first page. The read process can include 
--              the separation function or not(based on g_separate). 
--              The size of the dual page memory is determined by g_nof_points. 
--
-- Remarks: . This unit is only suitable for the pipelined fft (fft_r2_pipe).
-- 

library ieee, common_components_lib, common_pkg_lib, casper_counter_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use common_components_lib.common_bit_delay;
use work.fft_gnrcs_intrfcs_pkg.all;

entity fft_reorder_sepa_pipe is
    generic(
        g_nof_points         : natural := 8;
        g_bit_flip           : boolean := true; -- apply index flip to have bins in incrementing frequency order
        g_fft_shift          : boolean := false; -- apply fft_shift to have negative bin frequencies first for complex input
        g_dont_flip_channels : boolean := false; -- set true to preserve the channel interleaving when g_bit_flip is true, otherwise the channels get separated in time when g_bit_flip is true
        g_separate           : boolean := true; -- apply separation bins for two real inputs
        g_nof_chan           : natural := 0; -- Exponent of nr of subbands (0 means 1 subband, 1 => 2 sb, 2 => 4 sb, etc )
        g_ram_primitive      : string  := "auto";
        g_in_place           : boolean := false -- use single page buffer (out_val will not be a contiguous pulse though so NOT guaranteed backwards compatible)
    );
    port(
        clken    : in  std_logic := '1';
        clk      : in  std_logic;
        rst      : in  std_logic;
        in_dat   : in  std_logic_vector;
        in_sync  : in  std_logic;
        in_val   : in  std_logic;
        out_dat  : out std_logic_vector;
        out_sync : out std_logic;
        out_val  : out std_logic
    );
end entity fft_reorder_sepa_pipe;

architecture rtl of fft_reorder_sepa_pipe is

    constant c_nof_channels : natural := 2 ** g_nof_chan;
    constant c_dat_w        : natural := in_dat'length;
    constant c_page_size    : natural := g_nof_points * c_nof_channels;
    constant c_adr_points_w : natural := ceil_log2(g_nof_points);
    constant c_adr_chan_w   : natural := g_nof_chan;
    constant c_adr_tot_w    : natural := c_adr_points_w + c_adr_chan_w;

    constant c_buf_latency : natural := 1;

    -- goodness VHDL is verbose
    function f_number_pages(in_place_reorder : boolean)
    return natural is
    begin
        if in_place_reorder = true then
            return 1;
        else
            return 2;
        end if;
    end function;
    constant c_nof_pages : natural := f_number_pages(g_in_place);

    function f_rd_start_page(in_place_reorder : boolean)
    return natural is
    begin
        if in_place_reorder = true then
            return 0;
        else
            return 1;
        end if;
    end function;
    constant c_rd_start_page : natural := f_rd_start_page(g_in_place);

    signal adr_points_cnt : std_logic_vector(c_adr_points_w - 1 downto 0);
    signal adr_chan_cnt   : std_logic_vector(c_adr_chan_w - 1 downto 0);
    signal adr_tot_cnt    : std_logic_vector(c_adr_tot_w - 1 downto 0);

    signal sync_bram_delay : std_logic := '0';

    -- buffer write addressing
    signal base_counter, out_counter        : std_logic_vector(c_adr_points_w downto 0); -- counter which serves as a base
    signal linear_counter                   : std_logic; --when doing in place reorder every second spectrum 
    signal down, down_d                     : std_logic; --housekeeping for in place buffer
    signal first_down, first_down_d         : std_logic; --first down address is special
    signal adr_up, adr_down                 : std_logic_vector(c_adr_points_w - 1 downto 0); -- base for in place buffer
    -- we build up the write address depending on whether we are separating, reordering, shifting
    signal adr_sep, adr_reo, adr_shift, adr : std_logic_vector(c_adr_points_w - 1 downto 0);

    -- the buffer ports
    signal buf_wr_next_page, buf_rd_next_page : std_logic;
    signal buf_wr_adr, buf_rd_adr             : std_logic_vector(c_adr_tot_w - 1 downto 0);
    signal buf_wr_dat                         : std_logic_vector(c_dat_w - 1 downto 0); -- buffer input
    signal buf_wr_en, buf_rd_en               : std_logic;

    -- buffer outputs (and house-keeping for in place separation)   
    signal buf_rd_dat, buf_rd_dat_d1, buf_rd_dat_d2 : std_logic_vector(c_dat_w - 1 downto 0); -- buffer output
    signal buf_rd_val, buf_rd_val_d1                : std_logic;

    -- separate ports
    signal sep_in_dat              : std_logic_vector(c_dat_w - 1 downto 0);
    signal sep_in_val, sep_in_sync, sep_out_sync : std_logic;

    signal sep_out_dat_i : std_logic_vector(c_dat_w - 1 downto 0);
    signal sep_out_val_i : std_logic;

    signal not_first_spectrum : std_logic := '0';
    signal count_out_en       : std_logic;

    signal next_page : std_logic;

    signal cnt_ena : std_logic;

    signal rd_en       : std_logic;
    signal rd_adr_up   : std_logic_vector(c_adr_points_w downto 0);
    signal rd_adr_down : std_logic_vector(c_adr_points_w downto 0); -- use intermediate rd_adr_down that has 1 bit extra to avoid truncation warning with TO_UVEC()
    signal rd_adr      : std_logic_vector(c_adr_tot_w - 1 downto 0);

    type state_type is (s_idle, s_run_separate, s_run_normal);

    type reg_type is record
        rd_en      : std_logic;         -- The read enable signal to read out the data from the dp memory
        switch     : std_logic;         -- Toggel register used for separate functionalilty
        count_up   : natural;           -- An upwards counter for read addressing
        count_down : natural;           -- A downwards counter for read addressing
        count_chan : natural;           -- Counter that holds the number of channels for reading. 
        state      : state_type;        -- The state machine. 
    end record;

    signal r, rin : reg_type;

begin
    u_adr_chan_cnt : entity casper_counter_lib.common_counter
        generic map(
            g_latency => 1,
            g_init    => 0,
            g_width   => g_nof_chan
        )
        PORT MAP(
            rst    => in_sync,
            clk    => clk,
            cnt_en => in_val,
            count  => adr_chan_cnt
        );
    -- Generate on c_nof_channels to avoid simulation warnings on TO_UINT(adr_chan_cnt) when adr_chan_cnt is a NULL array
    one_chan : if c_nof_channels = 1 generate
        cnt_ena <= '1' when in_val = '1' else '0';
    end generate;
    more_chan : if c_nof_channels > 1 generate
        cnt_ena <= '1' when in_val = '1' and TO_UINT(adr_chan_cnt) = c_nof_channels - 1 else '0';
    end generate;

    base_cnt : entity casper_counter_lib.common_counter
        generic map(
            g_latency => 1,
            g_init    => 0,
            g_width   => c_adr_points_w + 1
        )
        PORT MAP(
            rst    => in_sync,
            clk    => clk,
            cnt_en => cnt_ena,
            count  => base_counter
        );

    -- if separating and/or reordering address alternates between
    -- simple linear counter and mangled counter    
    linear_counter <= base_counter(c_adr_points_w);

    down <= base_counter(0);            -- are we using the down counter or up when separating

    -- delay down signal till separate unit as need it to choose data
    u_down_d : entity common_components_lib.common_pipeline_sl
        generic map(
            g_pipeline => c_buf_latency
        )
        port map(
            rst     => '0',
            clk     => clk,
            in_dat  => down,
            out_dat => down_d
        );

    adr_up <= '0' & base_counter(c_adr_points_w - 1 downto 1);
    proc_adr_down : process(clk)
    begin
        if rising_edge(clk) then
            -- simple inversion has less timing implications than another counter
            -- we delay up counter by one clock cycle for down counter as
            -- up is always first (this is also better for timing)
            adr_down <= not (adr_up);
        end if;
    end process;

    -- the first time we use the down address is special when separating two real streams 
    -- so we keep track of it through the buffer
    first_down <= '1' when base_counter(c_adr_points_w - 1 downto 0) = TO_UVEC(1, c_adr_points_w) else '0';
    u_first_down_d : entity common_components_lib.common_pipeline_sl
        generic map(
            g_pipeline => c_buf_latency
        )
        port map(
            rst     => '0',
            clk     => clk,
            in_dat  => first_down,
            out_dat => first_down_d
        );

    adr_points_cnt <= base_counter(c_adr_points_w - 1 downto 0);

    gen_in_place_adr_sep : if g_in_place = true generate
        gen_complex : if g_separate = false generate
            adr_sep <= adr_points_cnt;
        end generate;
        gen_two_real : if g_separate = true generate
            adr_sep <= adr_down when down = '1' else
                       adr_up;
        end generate;

        -- all in place reorder addressing schemes start with a linear base counter
        -- and then have a different base for the next spectrum
        adr <= adr_points_cnt when linear_counter = '0' else
               adr_shift;
    end generate;
    gen_not_in_place_adr_sep : if g_in_place = false generate
        adr_sep <= adr_points_cnt;
        adr     <= adr_shift;
    end generate;

    -- if we are reordering the spectrum then bit reverse the separation address
    gen_bit_flip_adr_reo : if g_bit_flip = true generate
        adr_reo <= flip(adr_sep);
    end generate;
    gen_no_bit_flip_adr_reo : if g_bit_flip = false generate
        adr_reo <= adr_sep;
    end generate;

    -- rotate the output spectrum by half
    gen_shifts_adr_shift : if g_separate = false generate
        gen_no_fft_shift_sac : if g_fft_shift = false generate
            adr_shift <= adr_reo;
        end generate;
        gen_fft_shift_sac : if g_fft_shift = true generate
            adr_shift <= fft_shift(adr_reo);
        end generate;
    end generate;
    gen_no_shifts_adr_shift : if g_separate = true generate
        adr_shift <= adr_reo;
    end generate;

    -- final write address depends on whether we are outputting channels as they came in
    -- or separating them in time    
    gen_bit_flip_spectrum_and_channels : if g_dont_flip_channels = false generate
        buf_wr_adr <= adr_chan_cnt & adr;
    end generate;
    gen_bit_flip_spectrum_only : if g_dont_flip_channels = true generate
        buf_wr_adr <= adr & adr_chan_cnt;
    end generate;

    -- we never turn pages when doing in place
    gen_in_place_buf_next_page : if g_in_place = true generate
        buf_wr_next_page <= '0';
        buf_rd_next_page <= '0';
    end generate;

    adr_tot_cnt <= adr_points_cnt & adr_chan_cnt;
    next_page   <= '1' when unsigned(adr_tot_cnt) = c_page_size - 1 and in_val = '1' else '0';
    gen_not_in_place_buf_next_page : if g_in_place = false generate
        buf_wr_next_page <= next_page;
        buf_rd_next_page <= next_page;
    end generate;

    buf_wr_dat <= in_dat;
    buf_wr_en  <= in_val;

    u_bram_sync_delay : entity common_components_lib.common_bit_delay
        generic map(
            g_depth => c_buf_latency
        )
        port map(
            clk     => clk,
            rst     => rst,
            in_clr  => '0',
            in_bit  => in_sync,
            in_val  => '1',
            out_bit => sync_bram_delay
        );

    u_buff_inplace : entity casper_ram_lib.common_paged_ram_r_w
        generic map(
            g_str           => "use_adr",
            g_data_w        => c_dat_w,
            g_nof_pages     => c_nof_pages,
            g_page_sz       => c_page_size,
            g_wr_start_page => 0,
            g_rd_start_page => c_rd_start_page,
            g_rd_latency    => c_buf_latency,
            g_ram_primitive => g_ram_primitive
        )
        port map(
            rst          => rst,
            clk          => clk,
            wr_next_page => buf_wr_next_page,
            wr_adr       => buf_wr_adr,
            wr_en        => buf_wr_en,
            wr_dat       => buf_wr_dat,
            rd_next_page => buf_rd_next_page,
            rd_adr       => buf_rd_adr,
            rd_en        => buf_rd_en,
            rd_dat       => buf_rd_dat,
            rd_val       => buf_rd_val
        );

    -- If the separate functionality is enabled the read address will 
    -- be composed of an up and down counter that are interleaved. This is
    -- reflected in the s_run_separate state. 
    -- The process facilitates the first stage of the separate function
    -- It generates the read address in order to 
    -- create the data stream that is required for the separate
    -- block. The order for a 1024 ponit FFT is:
    -- X(0), X(1024), X(1), X(1023), X(2), X(1022), etc...              
    --          |
    --          |
    --       This value is X(0), because modulo N addressing is used. 
    --
    -- If separate functionality is disbaled a "normal" coun ter is used 
    -- to read out the dual page memory. State: s_run_normal

    comb : process(r, rst, next_page)
        variable v : reg_type;
    begin
        v       := r;
        v.rd_en := '0';

        case r.state is
            when s_idle =>
                if (next_page = '1') then -- Both counters are reset on page turn. 
                    v.rd_en    := '1';
                    v.switch   := '0';
                    v.count_up := 0;
                    if (g_separate = true) then -- Choose the appropriate run state 
                        v.count_chan := 0;
                        v.count_down := g_nof_points;
                        v.state      := s_run_separate;
                    else
                        v.state := s_run_normal;
                    end if;
                end if;

            when s_run_separate =>
                v.rd_en := '1';
                if (r.switch = '0') then
                    v.switch   := '1';
                    v.count_up := r.count_up + 1;
                end if;

                if (r.switch = '1') then
                    v.switch     := '0';
                    v.count_down := r.count_down - 1;
                end if;

                if (next_page = '1') then -- Both counters are reset on page turn. 
                    v.count_up   := 0;
                    v.count_down := g_nof_points;
                    v.count_chan := 0;
                elsif (r.count_up = g_nof_points / 2 and r.count_chan < c_nof_channels - 1) then -- 
                    v.count_up   := 0;
                    v.count_down := g_nof_points;
                    v.count_chan := r.count_chan + 1;
                elsif (r.count_up = g_nof_points / 2) then -- Pagereading is done, but there is not yet new data available
                    v.rd_en := '0';
                    v.state := s_idle;
                end if;

            when s_run_normal =>
                v.rd_en := '1';
                if (next_page = '1') then -- Counters is reset on page turn.         
                    v.count_up := 0;
                elsif (r.count_up = c_page_size - 1) then -- Pagereading is done, but there is not yet new data available 
                    v.rd_en := '0';
                    v.state := s_idle;
                else
                    v.count_up := r.count_up + 1;
                end if;

            when others =>
                v.state := s_idle;

        end case;

        if (rst = '1') then
            v.switch     := '0';
            v.rd_en      := '0';
            v.count_up   := 0;
            v.count_down := 0;
            v.count_chan := 0;
            v.state      := s_idle;
        end if;

        rin <= v;

    end process comb;

    regs : process(clk)
    begin
        if rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    rd_en <= r.rd_en;

    gen_separate : if g_separate = true generate
        -- The read address toggles between the upcounter and the downcounter.
        -- Modulo N addressing is done with the TO_UVEC function.
        rd_adr_up   <= TO_UVEC(r.count_up, c_adr_points_w + 1); -- eg.    0 .. 512
        rd_adr_down <= TO_UVEC(r.count_down, c_adr_points_w + 1); -- eg. 1024 .. 513, use 1 bit more to avoid truncation warning on 1024 ^= 0
        rd_adr      <= TO_UVEC(r.count_chan, c_adr_chan_w) & rd_adr_up(c_adr_points_w - 1 DOWNTO 0) when r.switch = '0' else
                       TO_UVEC(r.count_chan, c_adr_chan_w) & rd_adr_down(c_adr_points_w - 1 DOWNTO 0);

        -- if not in place reorder take the input directly from output of buffer
        gen_not_in_place_reorder : if g_in_place = false generate
            sep_in_dat  <= buf_rd_dat;
            sep_in_val  <= buf_rd_val;
            sep_in_sync <= sync_bram_delay;
        end generate;

        -- if inplace reorder, if we read a 'down' address, it is offset by one value
        -- and the first 'down' value is also special, reads from 'up' addresses are
        -- not delayed though 
        gen_in_place_reorder : if g_in_place = true generate

            -- When separating two real streams we need to combine the output data
            -- from the address counter going up, with the data from the down address counter
            -- offset by 1 (except for the first down counter value) 
            proc_buffer_outputs : process(clk)
            begin
                if rising_edge(clk) then

                    -- delay buffer output to be used to feed to separate
                    if (buf_rd_val = '1') then
                        buf_rd_dat_d1 <= buf_rd_dat;
                    end if;
                    if (buf_rd_val_d1 = '1') then
                        buf_rd_dat_d2 <= buf_rd_dat_d1;
                    end if;

                    buf_rd_val_d1 <= buf_rd_val;
                end if;
            end process;

            sep_in_dat <= buf_rd_dat_d1 when down_d = '1' and first_down_d = '1' else
                          buf_rd_dat_d2 when down_d = '1' and first_down_d = '0' else
                          buf_rd_dat;

            sep_in_val <= buf_rd_val_d1 when down_d = '1' else
                          buf_rd_val;

            sep_in_sync <= sync_bram_delay;
        end generate;

        -- The data that is read from the memory is fed to the separate block
        -- that performs the 2nd stage of separation. The output of the 
        -- separate unit is connected to the output of rtwo_order_separate unit. 
        -- The 2nd stage of the separate funtion is performed:
        u_separate : entity work.fft_sepa
            port map(
                clk      => clk,
                clken    => clken,
                rst      => rst,
                in_dat   => sep_in_dat,
                in_sync  => sep_in_sync,
                in_val   => sep_in_val,
                out_dat  => sep_out_dat_i,
                out_sync => sep_out_sync,
                out_val  => sep_out_val_i
            );
    end generate;                       --gen_separate

    -- If the separate functionality is disabled the 
    -- read address is received from the address counter and
    -- the output signals are directly driven. 
    gen_no_separate : if g_separate = false generate
        rd_adr <= TO_UVEC(r.count_up, c_adr_tot_w);

        -- Taking data directly from Block ram is not advisable add a pipeline stage here to improve place and route timing into the pipeline sum block will improve performance.

        sep_out_dat_i <= buf_rd_dat;    -- when rising_edge(clk);
        sep_out_val_i <= buf_rd_val;    -- when rising_edge(clk);
    end generate;

    -- when doing things in place, read transaction is same as write
    -- except for possibly channel order if reading channels out differently
    gen_in_place_rd_adr : if g_in_place = true generate
        buf_rd_adr <= buf_wr_adr;
        buf_rd_en  <= buf_wr_en;
    end generate;
    gen_not_in_place_rd_adr : if g_in_place = false generate
        buf_rd_adr <= rd_adr;
        buf_rd_en  <= rd_en;
    end generate;

    out_cnt : entity casper_counter_lib.common_counter
        generic map(
            g_latency => 1,
            g_init    => 0,
            g_width   => c_adr_points_w + 1
        )
        PORT MAP(
            rst    => sep_out_sync,
            clk    => clk,
            cnt_en => count_out_en,
            count  => out_counter
        );
    count_out_en <= not (not_first_spectrum) and sep_out_val_i;

    not_first_spectrum <= out_counter(c_adr_points_w);
    gen_in_place_reorder : if g_in_place = true generate
        out_val <= sep_out_val_i and not_first_spectrum;
    end generate;

    gen_not_in_place_reorder : if g_in_place = false generate
        out_val <= sep_out_val_i;
    end generate;
    
    out_sync <= sep_out_sync;
    out_dat <= sep_out_dat_i;
end rtl;

