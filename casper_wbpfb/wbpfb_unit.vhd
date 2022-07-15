--------------------------------------------------------------------------------
-- Author: Harm Jan Pepping : HJP at astron.nl: April 2012
--------------------------------------------------------------------------------
--
-- Copyright (C) 2012
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--------------------------------------------------------------------------------
-- Purpose: Wideband FFT with Subband Statistics and streaming interfaces.
--
-- Description: This unit connects an incoming array of streaming interfaces
--              to the wideband fft. The output of the wideband fft is
--              connected to a set of subband statistics units. The statistics
--              can be read via the memory mapped interface.
--              A control unit takes care of the correct composition of the
--              output streams(sop,eop,sync,bsn,err).
--
-- Remarks:   . The unit can handle only one sync at a time. Therfor the
--              sync interval should be larger than the total pipeline
--              stages of the wideband fft.
--
--            . The g_coefs_file_prefix points to the location where the files
--              with the initial content for the coefficients memories are located.
--              These files can be created using the python script: create_mifs.py
--              create_mifs.py is located in $UNB/Firmware/dsp/filter/src/python/
--              It is possible to create the mif files based on every possible
--              configuration of the filterbank in terms of:
--                 * wb_factor
--                 * nof points
--                 * nof_taps
--            . The wbfb unit can handle a wideband factor > 1 (g_wpfb.wb_factor) or
--              a narrowband factor > 1 (g_wpfb.nof_chan). Both factors can NOT be
--              used at the same time.

library ieee, common_pkg_lib, r2sdf_fft_lib, casper_filter_lib, wb_fft_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use casper_filter_lib.all;
use casper_filter_lib.fil_pkg.all;
use wb_fft_lib.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use work.wbpfb_gnrcs_intrfcs_pkg.all;

entity wbpfb_unit is
    generic(
        g_big_endian_wb_in  : boolean := true;
        g_wpfb              : t_wpfb  := c_wpfb;
        g_use_prefilter     : boolean := TRUE;
        g_coefs_file_prefix : string  := c_coefs_file; -- File prefix for the coefficients files.
        g_use_variant       : string  := "4DSP"; --! = "4DSP" or "3DSP" for 3 or 4 mult cmult.
        g_use_dsp           : string  := "yes"; --! = "yes" or "no"
        g_ovflw_behav       : string  := "WRAP"; --! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
        g_use_round         : string  := "ROUND"; --! = "ROUND" or "TRUNCATE" will default to TRUNCATE if invalid option used
        g_fft_ram_primitive : string  := "auto"; --! = "auto", "distributed", "block" or "ultra" for RAM architecture
        g_fifo_primitive    : string  := "auto"; --! = "auto", "distributed", "block" or "ultra" for RAM architecture
        g_fil_ram_primitive : string  := "auto"
    );
    port(
        rst          : in  std_logic := '0';
        clk          : in  std_logic;
        ce           : in  std_logic;
        shiftreg     : in  std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0);
        in_sosi_arr  : in  t_fil_sosi_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
        ovflw        : out std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0);
        out_sosi_arr : out t_fft_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0)
    );
end entity wbpfb_unit;

architecture str of wbpfb_unit is

    constant c_fil_ppf : t_fil_ppf := (g_wpfb.wb_factor,
                                       g_wpfb.nof_chan,
                                       g_wpfb.nof_points,
                                       g_wpfb.nof_taps,
                                       c_nof_complex * g_wpfb.nof_wb_streams, -- Complex FFT always requires 2 filter streams: real and imaginary
                                       g_wpfb.fil_backoff_w,
                                       g_wpfb.fil_in_dat_w,
                                       g_wpfb.fil_out_dat_w,
                                       g_wpfb.coef_dat_w);

    constant c_fft : t_fft := (g_wpfb.use_reorder,
                               g_wpfb.use_fft_shift,
                               g_wpfb.use_separate,
                               g_wpfb.nof_chan,
                               g_wpfb.wb_factor,
                               g_wpfb.nof_points,
                               g_wpfb.fft_in_dat_w,
                               g_wpfb.fft_out_dat_w,
                               g_wpfb.fft_out_gain_w,
                               g_wpfb.stage_dat_w,
                               g_wpfb.twiddle_dat_w,
                               g_wpfb.max_addr_w,
                               g_wpfb.guard_w,
                               g_wpfb.guard_enable,
                               g_wpfb.stat_data_w,
                               g_wpfb.stat_data_sz);

    signal fil_in_arr  : t_fil_slv_arr_in(c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fil_out_arr : t_fil_slv_arr_out(c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0); -- output of the filterbank is the fft input 
    signal fil_out_val : std_logic;

    signal fft_in_re_arr : t_fft_slv_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_in_im_arr : t_fft_slv_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_in_val    : std_logic;

    signal fft_in_sosi : t_fft_sosi_in;

    signal fft_out_re_arr_i : t_fft_slv_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_out_im_arr_i : t_fft_slv_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_out_re_arr   : t_fft_slv_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_out_im_arr   : t_fft_slv_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_out_val      : std_logic_vector(g_wpfb.nof_wb_streams - 1 downto 0);

    signal fft_out_sosi_arr : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0) := (others => c_fft_sosi_rst_out);

    type reg_type is record
        in_sosi_arr : t_fil_sosi_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    end record;

    signal r, rin : reg_type;

begin

    ---------------------------------------------------------------
    -- CHECK IF PROVIDED GENERICS ARE ALLOWED.
    ---------------------------------------------------------------
    assert not (g_wpfb.nof_chan /= 0 and g_wpfb.wb_factor /= 1 and rising_edge(clk)) report "nof_chan must be 0 when wb_factor > 1" severity FAILURE;

    ---------------------------------------------------------------
    -- INPUT REGISTER FOR THE SOSI ARRAY
    ---------------------------------------------------------------
    -- The complete input sosi arry is registered.
    comb : process(r, in_sosi_arr)
        variable v : reg_type;
    begin
        v             := r;
        v.in_sosi_arr := in_sosi_arr;
        rin           <= v;
        fft_in_sosi   <= (in_sosi_arr(0).sync, in_sosi_arr(0).bsn, (others => '0'), (others => '0'), in_sosi_arr(0).valid, in_sosi_arr(0).sop, in_sosi_arr(0).eop, in_sosi_arr(0).empty, in_sosi_arr(0).channel, in_sosi_arr(0).err);
    end process comb;

    regs : process(clk)
    begin
        if rising_edge(clk) then
            r <= rin;
        end if;
    end process;
    ---------------------------------------------------------------
    -- PREPARE INPUT DATA FOR WIDEBAND POLY PHASE FILTER
    ---------------------------------------------------------------
    -- Extract the data from the in_sosi_arr records and resize it
    -- to fit the format for the fil_ppf_wide unit. The reordering
    -- is done in such a way that the filtercoeficients are reused.
    -- Note that both the real part and the imaginary part have
    -- their own filterchannel.
    -- When wb_factor = 4 and nof_wb_streams = 2 the mapping is as
    -- follows (S = wb stream number, W = wideband stream number):
    --
    -- in_sosi_arr       | fil_in_arr          |  fft_in_re_arr    |  fft_in_im_arr
    --              S W  |            S W      |           S W     |           S W
    --     0        0 0  |     0      0 0 RE   |0   0      0 0 RE  |1   0      0 0 IM
    --     1        0 1  |     1      0 0 IM   |4   1      0 1 RE  |5   1      0 1 IM
    --     2        0 2  |     2      1 0 RE   |8   2      0 2 RE  |9   2      0 2 IM
    --     3        0 3  |     3      1 0 IM   |12  3      0 3 RE  |13  3      0 3 IM
    --     4        1 0  |     4      0 1 RE   |2   4      1 0 RE  |3   4      1 0 IM
    --     5        1 1  |     5      0 1 IM   |6   5      1 1 RE  |7   5      1 1 IM
    --     6        1 2  |     6      1 1 RE   |10  6      1 2 RE  |11  6      1 2 IM
    --     7        1 3  |     7      1 1 IM   |14  7      1 3 RE  |15  7      1 3 IM
    --                   |     8      0 2 RE   |                   |
    --                   |     9      0 2 IM   |                   |
    --                   |    10      1 2 RE   |                   |
    --                   |    11      1 2 IM   |                   |
    --                   |    12      0 3 RE   |                   |
    --                   |    13      0 3 IM   |                   |
    --                   |    14      1 3 RE   |                   |
    --                   |    15      1 3 IM   |                   |
    --
    gen_prep_filter_wb_factor : for I in 0 to g_wpfb.wb_factor - 1 generate
        gen_prep_filter_streams : for J in 0 to g_wpfb.nof_wb_streams - 1 generate
            fil_in_arr(2 * J + I * g_wpfb.nof_wb_streams * c_nof_complex)     <= r.in_sosi_arr(I + J * g_wpfb.wb_factor).re(g_wpfb.fil_in_dat_w - 1 downto 0);
            fil_in_arr(2 * J + I * g_wpfb.nof_wb_streams * c_nof_complex + 1) <= r.in_sosi_arr(I + J * g_wpfb.wb_factor).im(g_wpfb.fil_in_dat_w - 1 downto 0);
        end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE POLY PHASE FILTER
    ---------------------------------------------------------------
    gen_prefilter : IF g_use_prefilter = TRUE generate
        u_filter : entity casper_filter_lib.fil_ppf_wide
            generic map(
                g_big_endian_wb_in  => g_big_endian_wb_in,
                g_big_endian_wb_out => false,
                g_fil_ppf           => c_fil_ppf,
                g_fil_ppf_pipeline  => g_wpfb.fil_pipeline,
                g_coefs_file_prefix => g_coefs_file_prefix,
                g_ram_primitive     => g_fil_ram_primitive
            )
            port map(
                clk         => clk,
                ce          => ce,
                rst         => rst,
                -- mm_clk         => mm_clk,
                -- mm_rst         => mm_rst,
                -- ram_coefs_mosi => ram_fil_coefs_mosi,
                -- ram_coefs_miso => ram_fil_coefs_miso,
                in_dat_arr  => fil_in_arr,
                in_val      => r.in_sosi_arr(0).valid,
                out_dat_arr => fil_out_arr,
                out_val     => fil_out_val
            );
    end generate;

    -- Bypass filter
    gen_no_prefilter : if g_use_prefilter = FALSE generate
        gen_no_prefilter_signalmap : for I in c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0 generate
            fil_out_arr(I) <= RESIZE_SVEC(fil_in_arr(I), g_wpfb.fil_out_dat_w);
        end generate;
        fil_out_val <= r.in_sosi_arr(0).valid;
    end generate;

    fft_in_val <= fil_out_val;

    ---------------------------------------------------------------
    -- THE WIDEBAND FFT
    ---------------------------------------------------------------
    gen_wide_band_fft : if g_wpfb.wb_factor > 1 generate
        ---------------------------------------------------------------
        -- PREPARE INPUT DATA FOR WIDEBAND FFT
        ---------------------------------------------------------------
        -----------------------------------------------------------------------------------------------------
        gen_prep_fft_streams : for I in 0 to g_wpfb.nof_wb_streams - 1 generate
            gen_prep_fft_wb_factor : for J in 0 to g_wpfb.wb_factor - 1 generate
                fft_in_re_arr(I * g_wpfb.wb_factor + J) <= fil_out_arr(J * c_nof_complex * g_wpfb.nof_wb_streams + I * c_nof_complex);
                fft_in_im_arr(I * g_wpfb.wb_factor + J) <= fil_out_arr(J * c_nof_complex * g_wpfb.nof_wb_streams + I * c_nof_complex + 1);
            end generate;
        end generate;
        -----------------------------------------------------------------------------------------------------
        gen_prep_wide_fft_streams : for I in 0 to g_wpfb.nof_wb_streams - 1 generate
            u_fft_wide : entity wb_fft_lib.fft_r2_wide
                generic map(
                    g_fft            => c_fft, -- generics for the WFFT
                    g_pft_pipeline   => g_wpfb.pft_pipeline,
                    g_fft_pipeline   => g_wpfb.fft_pipeline,
                    g_use_variant    => g_use_variant,
                    g_use_dsp        => g_use_dsp,
                    g_ovflw_behav    => g_ovflw_behav,
                    g_ram_primitive  => g_fft_ram_primitive
                )
                port map(
                    clk        => clk,
                    rst        => rst,
                    clken      => ce,
                    shiftreg   => shiftreg,
                    in_re_arr  => fft_in_re_arr((I + 1) * g_wpfb.wb_factor - 1 downto I * g_wpfb.wb_factor),
                    in_im_arr  => fft_in_im_arr((I + 1) * g_wpfb.wb_factor - 1 downto I * g_wpfb.wb_factor),
                    in_val     => fft_in_val,
                    out_re_arr => fft_out_re_arr((I + 1) * g_wpfb.wb_factor - 1 downto I * g_wpfb.wb_factor),
                    out_im_arr => fft_out_im_arr((I + 1) * g_wpfb.wb_factor - 1 downto I * g_wpfb.wb_factor),
                    ovflw      => ovflw,
                    out_val    => fft_out_val(I)
                );
        end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE PIPELINED FFT
    ---------------------------------------------------------------
    gen_pipeline_fft : if g_wpfb.wb_factor = 1 generate
        ---------------------------------------------------------------
        -- PREPARE INPUT DATA FOR WIDEBAND FFT
        ---------------------------------------------------------------
        gen_prep_fft_streams : for I in 0 to g_wpfb.nof_wb_streams - 1 generate
            fft_in_re_arr(I) <= fil_out_arr(I * c_nof_complex);
            fft_in_im_arr(I) <= fil_out_arr(I * c_nof_complex + 1);
        end generate;

        gen_prep_pipe_fft_streams : for I in 0 to g_wpfb.nof_wb_streams - 1 generate
            u_fft_pipe : entity wb_fft_lib.fft_r2_pipe
                generic map(
                    g_fft      => c_fft,
                    g_pipeline => g_wpfb.fft_pipeline,
                    g_dont_flip_channels => false,
                    g_wb_inst => 1,
                    g_use_variant => g_use_variant,
                    g_use_dsp => g_use_dsp,
                    g_ovflw_behav => g_ovflw_behav,
                    g_use_round => g_use_round
                )
                port map(
                    clk      => clk,
                    clken    => ce,
                    rst      => rst,
                    in_re    => fft_in_re_arr(I)(c_fft.in_dat_w - 1 downto 0),
                    in_im    => fft_in_im_arr(I)(c_fft.in_dat_w - 1 downto 0),
                    in_val   => fft_in_val,
                    shiftreg => shiftreg,
                    out_re   => fft_out_re_arr_i(I)(c_fft.out_dat_w - 1 downto 0),
                    out_im   => fft_out_im_arr_i(I)(c_fft.out_dat_w - 1 downto 0),
                    ovflw    => ovflw,
                    out_val  => fft_out_val(I)
                );
            fft_out_re_arr(I) <= fft_out_re_arr_i(I);
            fft_out_im_arr(I) <= fft_out_im_arr_i(I);
        end generate;
    end generate;

    ---------------------------------------------------------------
    -- FFT CONTROL UNIT
    ---------------------------------------------------------------
    -- The fft control unit composes the output array in the dp-
    -- streaming format.

    u_fft_control : entity wb_fft_lib.fft_wide_unit_control
        generic map(
            g_fft            => c_fft,
            g_nof_ffts       => g_wpfb.nof_wb_streams,
            g_use_variant    => g_use_variant,
            g_use_dsp        => g_use_dsp,
            g_ovflw_behav    => g_ovflw_behav,
            g_use_round      => g_use_round,
            g_ram_primitive  => g_fft_ram_primitive,
            g_fifo_primitive => g_fifo_primitive
        )
        port map(
            rst          => rst,
            clk          => clk,
            in_re_arr    => fft_out_re_arr,
            in_im_arr    => fft_out_im_arr,
            in_val       => fft_out_val(0),
            ctrl_sosi    => fft_in_sosi,
            out_sosi_arr => fft_out_sosi_arr
        );

    -- Connect to the outside world
    gen_output_streams : for I in 0 to g_wpfb.nof_wb_streams - 1 generate
        gen_output_wb_factor : for J in 0 to g_wpfb.wb_factor - 1 generate
            out_sosi_arr(I * g_wpfb.wb_factor + J) <= fft_out_sosi_arr(I * g_wpfb.wb_factor + J);
        end generate;
    end generate;

end str;
