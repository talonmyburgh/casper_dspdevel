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
-- Purpose: Composition of the SOSI output streams for the fft_wide_unit. 
--
-- Description: This unit monitors the in_val signal. Based on the assertion of the 
--              in_val signal it will compose the output sosi streams. The packet-
--              size equals g_fft.nof_points/g_fft.wb_factor. 
--              Both the incoming bsn and err fields are written to a fifo. When 
--              the output is composed the bsn and err field will be read from the 
--              fifo's. 
--              Incoming syncs will be detected and the bsn that accompanies the sync
--              will be stored. When the bsn that is read from the fifo is the same 
--              as the stored one, the sync will be asserted to the output. 
--
-- Remarks:    .The sync interval must be larger that the total amount of pipeline
--              stages in the FFT. In other words: the fft_wide_unit_control unit 
--              is not capable of handling more than one sync pulse at a time. 
--              
--

library IEEE, common_pkg_lib, casper_ram_lib, casper_fifo_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;
use casper_ram_lib.common_ram_pkg.ALL;
use work.fft_gnrcs_intrfcs_pkg.ALL;

entity fft_wide_unit_control is
    generic(
        g_fft      : t_fft   := c_fft;
        g_nof_ffts : natural := 1
    );
    port(
        rst          : in  std_logic := '0';
        clk          : in  std_logic;
        in_re_arr    : in  t_slv_64_arr(g_nof_ffts * g_fft.wb_factor - 1 downto 0); -- note only g_fft.out_dat_w bits used!
        in_im_arr    : in  t_slv_64_arr(g_nof_ffts * g_fft.wb_factor - 1 downto 0);
        in_val       : in  std_logic;
        ctrl_sosi    : in  t_fft_sosi_in; -- Inputrecord for tapping off the sync, bsn and err.              
        out_sosi_arr : out t_fft_sosi_arr_out(g_nof_ffts * g_fft.wb_factor - 1 downto 0) -- Streaming output interface    
    );
end fft_wide_unit_control;

architecture rtl of fft_wide_unit_control is

    constant c_pipe_data       : natural := 3; -- Delay depth for the data 
    constant c_pipe_ctrl       : natural := c_pipe_data - 1; -- Delay depth for the control signals
    constant c_packet_size     : natural := (2 ** g_fft.nof_chan) * g_fft.nof_points / g_fft.wb_factor; -- Definition of the packet size
    constant c_ctrl_fifo_depth : natural := 16; -- Depth of the bsn and err fifo.  
    type t_fft_slv_arr_outl is array(g_nof_ffts * g_fft.wb_factor - 1 downto 0) of std_logic_vector(g_fft.out_dat_w-1 downto 0);
    type t_fft_slv_arr2 is array (integer range <>) of t_fft_slv_arr_outl;

    type state_type is (s_idle, s_run, s_hold);

    type reg_type is record
        out_sosi_arr   : t_fft_sosi_arr_out(g_nof_ffts * g_fft.wb_factor - 1 downto 0); -- Register that holds the streaming interface          
        in_re_arr2_dly : t_fft_slv_arr2(c_pipe_data - 1 downto 0); -- Input registers for the real data 
        in_im_arr2_dly : t_fft_slv_arr2(c_pipe_data - 1 downto 0); -- Input registers for the imag data
        val_dly        : std_logic_vector(c_pipe_ctrl - 1 downto 0); -- Delay-register for the valid signal
        sop_dly        : std_logic_vector(c_pipe_ctrl - 1 downto 0); -- Delay-register for the sop signal
        eop_dly        : std_logic_vector(c_pipe_ctrl - 1 downto 0); -- Delay-register for the eop signal
        sync_detected  : std_logic;     -- Register used to detect and pass the sync pulse.
        packet_cnt     : integer;       -- Counter to create the packets. 
        state          : state_type;    -- The state machine. 
    end record;

    constant reg_default : reg_type := ((others => c_fft_sosi_rst_out), (others => (others => (others => '0'))), (others => (others => (others => '0'))), (others => '0'), (others => '0'), (others => '0'), '0', 0, s_idle);

    signal r, rin   : reg_type := reg_default;
    signal bsn      : std_logic_vector(c_dp_stream_bsn_w - 1 downto 0);
    signal sync_bsn : std_logic_vector(c_dp_stream_bsn_w - 1 downto 0);
    signal err      : std_logic_vector(c_dp_stream_error_w - 1 downto 0);
    signal rd_req   : std_logic;
    signal rd_req_i : std_logic;
    signal rd_dat_i : std_logic_vector(c_dp_stream_bsn_w - 1 downto 0);
    signal rd_val_i : std_logic;

begin

    ---------------------------------------------------------------
    -- INPUT FIFO FOR BSN
    ---------------------------------------------------------------
    u_bsn_fifo : entity casper_fifo_lib.common_fifo_sc
        generic map(
            g_use_lut        => TRUE,   -- Make this FIFO in logic, since it's only 4 words deep. 
            g_reset          => FALSE,
            g_init           => FALSE,
            g_dat_w          => c_dp_stream_bsn_w,
            g_nof_words      => c_ctrl_fifo_depth,
            g_fifo_primitive => "distributed"
        )
        port map(
            rst    => rst,
            clk    => clk,
            wr_dat => ctrl_sosi.bsn,
            wr_req => ctrl_sosi.sop,
            wr_ful => open,
            rd_dat => bsn,
            rd_req => r.sop_dly(0),
            rd_emp => open,
            rd_val => open,
            usedw  => open
        );

    ---------------------------------------------------------------
    -- INPUT FIFO FOR ERR
    ---------------------------------------------------------------
    u_error_fifo : entity casper_fifo_lib.common_fifo_sc
        generic map(
            g_use_lut        => TRUE,   -- Make this FIFO in logic, since it's only 4 words deep. 
            g_reset          => FALSE,
            g_init           => FALSE,
            g_dat_w          => c_dp_stream_error_w,
            g_nof_words      => c_ctrl_fifo_depth,
            g_fifo_primitive => "distributed"
        )
        port map(
            rst    => rst,
            clk    => clk,
            wr_dat => ctrl_sosi.err,
            wr_req => ctrl_sosi.sop,
            wr_ful => open,
            rd_dat => err,
            rd_req => r.sop_dly(1),
            rd_emp => open,
            rd_val => open,
            usedw  => open
        );

    ---------------------------------------------------------------
    -- FIFO FOR SYNC-BSN
    ---------------------------------------------------------------
    u_sync_bsn_fifo : entity casper_fifo_lib.common_fifo_sc
        generic map(
            g_use_lut        => TRUE,   -- Make this FIFO in logic, since it's only 4 words deep. 
            g_reset          => FALSE,
            g_init           => FALSE,
            g_dat_w          => c_dp_stream_bsn_w,
            g_nof_words      => 16,
            g_fifo_primitive => "distributed"
        )
        port map(
            rst    => rst,
            clk    => clk,
            wr_dat => ctrl_sosi.bsn,
            wr_req => ctrl_sosi.sync,
            wr_ful => open,
            rd_dat => rd_dat_i,
            rd_req => rd_req_i,
            rd_emp => open,
            rd_val => rd_val_i,
            usedw  => open
        );

    ---------------------------------------------------------------
    -- CREATE READ-AHEAD FIFO INTERFACE FOR SYNC-BSN
    ---------------------------------------------------------------
    u_fifo_adapter : entity casper_fifo_lib.common_fifo_rd
        generic map(
            g_dat_w => c_dp_stream_bsn_w
        )
        port map(
            rst      => rst,
            clk      => clk,
            -- ST sink: RL = 1
            fifo_req => rd_req_i,
            fifo_dat => rd_dat_i,
            fifo_val => rd_val_i,
            -- ST source: RL = 0
            rd_req   => rd_req,
            rd_dat   => sync_bsn,
            rd_val   => open
        );

    rd_req <= r.out_sosi_arr(0).sync;   --  (r.sync_detected and not(rd_emp)) or r.rd_first; 

    ---------------------------------------------------------------
    -- PROCESS THAT COMPOSES THE SOSI OUTPUT ARRAYS
    ---------------------------------------------------------------
    comb : process(r, rst, ctrl_sosi, in_re_arr, in_im_arr, in_val, sync_bsn, bsn, err)
        variable v : reg_type;
    begin
        v := r;

        v.val_dly(0) := '0';            -- Some defaults, before entering the state machine.              
        v.sop_dly(0) := '0';
        v.eop_dly(0) := '0';

        for I in g_nof_ffts * g_fft.wb_factor - 1 downto 0 loop
            v.out_sosi_arr(I).sync := '0';
            v.in_re_arr2_dly(0)(I) := in_re_arr(I)(g_fft.out_dat_w-1 downto 0); -- Latch the data into the input registers. 
            v.in_im_arr2_dly(0)(I) := in_im_arr(I)(g_fft.out_dat_w-1 downto 0); -- Latch the data into the input registers
        end loop;

        v.in_re_arr2_dly(c_pipe_data - 1 downto 1) := r.in_re_arr2_dly(c_pipe_data - 2 downto 0); -- Shift the delay registers
        v.in_im_arr2_dly(c_pipe_data - 1 downto 1) := r.in_im_arr2_dly(c_pipe_data - 2 downto 0); -- Shift the delay registers
        v.val_dly(c_pipe_ctrl - 1 downto 1)        := r.val_dly(c_pipe_ctrl - 2 downto 0); -- Shift the delay registers
        v.sop_dly(c_pipe_ctrl - 1 downto 1)        := r.sop_dly(c_pipe_ctrl - 2 downto 0); -- Shift the delay registers
        v.eop_dly(c_pipe_ctrl - 1 downto 1)        := r.eop_dly(c_pipe_ctrl - 2 downto 0); -- Shift the delay registers

        for I in g_nof_ffts * g_fft.wb_factor - 1 downto 0 loop
            v.out_sosi_arr(I).sop   := r.sop_dly(c_pipe_ctrl - 1); -- Assign the output of the shiftregisters to the "real" signals
            v.out_sosi_arr(I).eop   := r.eop_dly(c_pipe_ctrl - 1); -- Assign the output of the shiftregisters to the "real" signals
            v.out_sosi_arr(I).valid := r.val_dly(c_pipe_ctrl - 1); -- Assign the output of the shiftregisters to the "real" signals
            v.out_sosi_arr(I).bsn   := bsn; -- The bsn is read from the FIFO
            v.out_sosi_arr(I).err   := err; -- The err is read from the FIFO
            v.out_sosi_arr(I).re    := r.in_re_arr2_dly(c_pipe_data - 1)(I); -- Data input is latched-in 
            v.out_sosi_arr(I).im    := r.in_im_arr2_dly(c_pipe_data - 1)(I); -- Data input is latched-in
        end loop;

        if (ctrl_sosi.sync = '1') then  -- Check which bsn accompanies the sync
            v.sync_detected := '1';
        end if;

        if (sync_bsn = bsn and r.sop_dly(1) = '1' and r.sync_detected = '1') then -- When the next bsn equals the stored bsn 
            for I in g_fft.wb_factor - 1 downto 0 loop -- a sync pulse will be generated that 
                v.out_sosi_arr(I).sync := '1'; -- preceeds the sop
            end loop;
            v.sync_detected := '0';
        end if;

        case r.state is
            when s_idle =>
                if (in_val = '1') then  -- Wait for the first data to arrive
                    v.packet_cnt := 0;  -- Reset the packet counter
                    v.state      := s_run;
                end if;

            when s_run =>
                v.val_dly(0) := '1';    -- Assert the valid signal (Stream starts)
                v.packet_cnt := r.packet_cnt + 1; -- Increment the packet-counter when in s_run-state

                if (r.packet_cnt = 0) then -- First sample marks
                    v.sop_dly(0) := '1'; -- the start of a packet
                elsif (r.packet_cnt = c_packet_size - 1) then -- Last address marks  
                    v.eop_dly(0) := '1'; -- the end of a packet
                    v.packet_cnt := 0;  -- Reset the counter
                end if;

                if (in_val = '0') then  -- If there is no more data:
                    v.state := s_hold;  -- go wait in the s_hold state
                end if;

            when s_hold =>
                if (in_val = '1') then  -- Wait until new valid data arrives
                    v.state := s_run;
                end if;
        end case;

        if (rst = '1') then
            v.out_sosi_arr  := (others => c_fft_sosi_rst_out);
            v.val_dly       := (others => '0');
            v.sop_dly       := (others => '0');
            v.eop_dly       := (others => '0');
            v.sync_detected := '0';
            v.packet_cnt    := 0;
            v.state         := s_idle;
        end if;

        rin <= v;

    end process comb;

    regs : process(clk)
    begin
        if rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    -- Connect to the outside world  
    gen_output : for I in g_nof_ffts * g_fft.wb_factor - 1 downto 0 generate
        out_sosi_arr(I) <= r.out_sosi_arr(I);
    end generate;

end rtl;

