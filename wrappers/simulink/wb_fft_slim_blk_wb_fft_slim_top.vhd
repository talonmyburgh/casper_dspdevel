library ieee,casper_wb_barebones_lib, r2sdf_fft_lib, common_pkg_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_wb_barebones_lib.fft_gnrcs_intrfcs_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually.
entity wideband_fft_slim_top is
	generic(
use_reorder    : boolean := use_reorder;       -- = false for bit-reversed output, true for normal output
use_fft_shift  : boolean := use_fft_shift;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
use_separate   : boolean := use_separate;       -- = false for complex input, true for two real inputs
nof_chan       : natural := nof_chan;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
wb_factor      : natural := wb_factor;       -- = default 1, wideband factor
twiddle_offset : natural := twiddle_offset;       -- = default 0, twiddle offset for PFT sections in a wideband FFT
nof_points     : natural := nof_points;       -- = 1024, N point FFT
in_dat_w       : natural := in_dat_w;       -- = 8,  number of input bits
out_dat_w      : natural := out_dat_w;       -- = 13, number of output bits
out_gain_w     : natural := out_gain_w;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
stage_dat_w    : natural := stage_dat_w;       -- = 18, data width used between the stages(= DSP multiplier-width)
guard_w        : natural := guard_w;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
--   12.3.2], therefore use input guard_w = 2.
guard_enable   : boolean := guard_enable       -- = true when input needs guarding, false when input requires no guarding but scaling must be
--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
--   doing the input guard and par fft section doing the output compensation)
);
port(
clk : in std_logic;
ce : in std_logic;
rst : in std_logic;
in_sync : in std_logic;
in_valid : in std_logic;
out_sync : out std_logic;
out_valid : out std_logic;
in_im_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
in_re_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
out_im_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);
out_re_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0));
end entity wideband_fft_slim_top;
architecture RTL of wideband_fft_slim_top is
constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,nof_chan,wb_factor,twiddle_offset,
nof_points, in_dat_w,out_dat_w,out_gain_w,stage_dat_w,guard_w,guard_enable,56,2);
signal in_bb_sosi_arr : t_bb_sosi_arr_in(wb_factor - 1 downto 0);
signal out_bb_sosi_arr : t_bb_sosi_arr_out(wb_factor - 1 downto 0);
constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;
constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;
begin
fft_wide_unit : entity casper_wb_barebones_lib.fft_wide_unit
generic map(
g_fft          => cc_fft,
g_pft_pipeline => c_pft_pipeline,
g_fft_pipeline => c_fft_pipeline)
port map (
clken        => ce,
rst       => rst,
clk       => clk,
in_bb_sosi_arr  => in_bb_sosi_arr,
out_bb_sosi_arr => out_bb_sosi_arr);
otherinprtmap: for j in 0 to wb_factor-1 generate
in_bb_sosi_arr(j).sync <= in_sync;
in_bb_sosi_arr(j).valid <= in_valid;
end generate;
otheroutprtmap: for k in 0 to wb_factor-1 generate
out_sync<=out_bb_sosi_arr(k).sync;
out_valid<=out_bb_sosi_arr(k).valid;
end generate;
in_bb_sosi_arr(0).re <= RESIZE_SVEC(in_re_0, in_bb_sosi_arr(0).re'length);
in_bb_sosi_arr(0).im <= RESIZE_SVEC(in_im_0, in_bb_sosi_arr(0).im'length);
out_re_0 <= RESIZE_SVEC(out_bb_sosi_arr(0).re,out_dat_w);
out_im_0 <= RESIZE_SVEC(out_bb_sosi_arr(0).im,out_dat_w);
end architecture RTL;