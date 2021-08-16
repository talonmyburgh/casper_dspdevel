----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/10/2021 04:06:21 PM
-- Design Name: 
-- Module Name: wbpfb_unit_top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library ieee, common_pkg_lib,r2sdf_fft_lib,casper_filter_lib,wb_fft_lib,casper_diagnostics_lib,casper_ram_lib,wpfb_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use casper_filter_lib.all;
use casper_filter_lib.fil_pkg.all;
use wb_fft_lib.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use work.wbpfb_gnrcs_intrfcs_pkg.all;
use wpfb_lib.all;

entity wbpfb_unit_top is
 generic (
    g_big_endian_wb_in  : boolean          := true;
    g_wb_factor         : natural          := 4;       -- = default 4, wideband factor
    g_nof_points        : natural          := 1024;    -- = 1024, N point FFT (Also the number of subbands for the filter part)
    g_nof_chan          : natural          := 0;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     
    g_nof_wb_streams    : natural          := 1;       -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream.
    g_nof_taps          : natural          := 16;      -- = 16, the number of FIR taps per subband
    g_fil_backoff_w     : natural          := 0;       -- = 0, number of bits for input backoff to avoid output overflow
    g_fil_in_dat_w      : natural          := 8;       -- = 8, number of input bits
    g_fil_out_dat_w     : natural          := 16;      -- = 16, number of output bits
    g_coef_dat_w        : natural          := 16;      -- = 16, data width of the FIR coefficients
    g_use_reorder       : boolean          := false;   -- = false for bit-reversed output, true for normal output
    g_use_fft_shift     : boolean          := false;   -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    g_use_separate      : boolean          := false;   -- = false for complex input, true for two real inputs
    g_fft_in_dat_w      : natural          := 16;      -- = 16, number of input bits
    g_fft_out_dat_w     : natural          := 16;      -- = 16, number of output bits >= (fil_in_dat_w=8) + log2(nof_points=1024)/2 = 13
    g_fft_out_gain_w    : natural          := 0;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    g_stage_dat_w       : natural          := 18;      -- = 18, number of bits that are used inter-stage
    g_guard_w           : natural          := 2;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
                                                      --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
                                                      --   12.3.2], therefore use input guard_w = 2.
    g_guard_enable      : boolean          := true;    -- = true when input needs guarding, false when input requires no guarding but scaling must be
                                                      --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
                                                      --   doing the input guard and par fft section doing the output compensation)
    g_dont_flip_channels: boolean          := false; -- True preserves channel interleaving for pipelined FFT
    g_use_prefilter     : boolean          := TRUE;
    g_coefs_file_prefix : string           := c_coefs_file; -- File prefix for the coefficients files.
    g_fil_ram_primitive : string           := "block";
    g_use_variant       : string  		     := "4DSP";       -- = "4DSP" or "3DSP" for 3 or 4 mult cmult.
    g_use_dsp           : string  		     := "yes";        -- = "yes" or "no"
    g_ovflw_behav       : string  		     := "WRAP";       -- = "WRAP" or "SATURATE" will default to WRAP if invalid option used
    g_use_round         : string  		     := "ROUND";      -- = "ROUND" or "TRUNCATE" will default to TRUNCATE if invalid option used
    g_fft_ram_primitive : string  		     := "block";      -- = "auto", "distributed", "block" or "ultra" for RAM architecture
    g_fifo_primitive    : string  		     := "block"       -- = "auto", "distributed", "block" or "ultra" for RAM architecture
   );
   port
   (
    rst                 : in  std_logic := '0';
    clk                 : in  std_logic := '0';
    ce                  : in  std_logic := '1';
    shiftreg            : in  std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'1');			--! Shift register
    ovflw               : out std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'0');
    in_sync             : in std_logic;
    in_valid            : in std_logic;
    out_sync            : out std_logic := '0';
    out_valid           : out std_logic := '0';
    fil_sync            : out std_logic := '0';
    fil_valid           : out std_logic := '0';
    in_bsn              : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
    in_sop              : in std_logic;
    in_eop              : in std_logic;
    in_empty            : in STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);
    in_err              : in STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);
    in_channel          : in STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);
    out_bsn             : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := (others=>'0');
    out_sop             : out std_logic := '0';
    out_eop             : out std_logic := '0';
    out_empty           : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0) := (others=>'0');
    out_err             : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0) := (others=>'0');
    out_channel         : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0) := (others=>'0');
    fil_bsn             : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
    fil_sop             : out std_logic;
    fil_eop             : out std_logic;
    fil_empty           : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);
    fil_err             : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);
    fil_channel         : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);
   -- Data signals
    in_im_0             : in STD_LOGIC_VECTOR(g_fil_in_dat_w -1 DOWNTO 0);
    in_re_0             : in STD_LOGIC_VECTOR(g_fil_in_dat_w -1 DOWNTO 0);
    fil_im_0            : out STD_LOGIC_VECTOR(g_fil_out_dat_w -1 DOWNTO 0);
    fil_re_0            : out STD_LOGIC_VECTOR(g_fft_out_dat_w -1 DOWNTO 0);
    out_re_0            : out STD_LOGIC_VECTOR(g_fft_out_dat_w -1 DOWNTO 0);
    out_im_0            : out STD_LOGIC_VECTOR(g_fft_out_dat_w -1 DOWNTO 0)
    
   );
end wbpfb_unit_top;

architecture Behavioral of wbpfb_unit_top is
   constant cc_wpfb : t_wpfb := (g_wb_factor, g_nof_points, g_nof_chan, g_nof_wb_streams, g_nof_taps, g_fil_backoff_w, g_fil_in_dat_w, g_fil_out_dat_w,
                                 g_coef_dat_w, g_use_reorder, g_use_fft_shift, g_use_separate, g_fft_in_dat_w, g_fft_out_dat_w, g_fft_out_gain_w, g_stage_dat_w,
                                 g_guard_w, g_guard_enable, 56, 2, 800000, c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);
   signal in_fil_sosi_arr  : t_fil_sosi_arr_in(g_wb_factor*g_nof_wb_streams - 1 downto 0);
   signal out_fil_sosi_arr : t_fil_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0);
   signal out_fft_sosi_arr : t_fft_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0);

begin

 wbpfb_unit : entity wpfb_lib.wbpfb_unit_dev
 generic map (
   g_big_endian_wb_in   => g_big_endian_wb_in,
   g_wpfb               => cc_wpfb,
   g_dont_flip_channels => g_dont_flip_channels,
   g_use_prefilter      => g_use_prefilter,
   g_coefs_file_prefix  => g_coefs_file_prefix,
   g_fil_ram_primitive  => g_fil_ram_primitive,
   g_use_variant        => g_use_variant,
   g_use_dsp            => g_use_dsp,
   g_ovflw_behav        => g_ovflw_behav,
   g_use_round          => g_use_round,
   g_fft_ram_primitive  => g_fft_ram_primitive,
   g_fifo_primitive     => g_fifo_primitive
)
 port map(
   rst                  => rst,
   clk                  => clk,
   ce                   => ce,
   shiftreg             => shiftreg,
   in_sosi_arr          => in_fil_sosi_arr,
   fil_sosi_arr         => out_fil_sosi_arr,
   ovflw                => ovflw,
   out_sosi_arr         => out_fft_sosi_arr
 );

 otherinprtmap: for j in 0 to g_wb_factor-1 generate
 in_fil_sosi_arr(j).sync <= in_sync;
 in_fil_sosi_arr(j).bsn <= in_bsn;
 in_fil_sosi_arr(j).valid <= in_valid;
 in_fil_sosi_arr(j).sop <= in_sop;
 in_fil_sosi_arr(j).eop <= in_eop;
 in_fil_sosi_arr(j).empty <= in_empty;
 in_fil_sosi_arr(j).channel <= in_channel;
 in_fil_sosi_arr(j).err <= in_err;
 end generate;
 otheroutprtmap: for k in 0 to g_wb_factor-1 generate
 out_sync <= out_fft_sosi_arr(k).sync;
 out_bsn <= out_fft_sosi_arr(k).bsn;
 out_valid <= out_fft_sosi_arr(k).valid ;
 out_sop <= out_fft_sosi_arr(k).sop;
 out_eop <= out_fft_sosi_arr(k).eop;
 out_empty <= out_fft_sosi_arr(k).empty;
 out_channel <= out_fft_sosi_arr(k).channel;
 out_err <= out_fft_sosi_arr(k).err;
 end generate;
 otherfilprtmap: for k in 0 to g_wb_factor-1 generate
 fil_sync <= out_fil_sosi_arr(k).sync;
 fil_bsn <= out_fil_sosi_arr(k).bsn;
 fil_valid <= out_fil_sosi_arr(k).valid ;
 fil_sop <= out_fil_sosi_arr(k).sop;
 fil_eop <= out_fil_sosi_arr(k).eop;
 fil_empty <= out_fil_sosi_arr(k).empty;
 fil_channel <= out_fil_sosi_arr(k).channel;
 fil_err <= out_fil_sosi_arr(k).err;
 end generate;

in_fil_sosi_arr(0).re <= in_re_0;
in_fil_sosi_arr(0).im <= in_im_0;
fil_re_0 <= out_fil_sosi_arr(0).re;
fil_im_0 <= out_fil_sosi_arr(0).im;
out_re_0 <= out_fft_sosi_arr(0).re;
out_im_0 <= out_fft_sosi_arr(0).im;
end Behavioral;
