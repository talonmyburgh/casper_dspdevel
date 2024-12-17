library ieee,casper_wb_fft_lib, r2sdf_fft_lib, common_pkg_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually.
entity wideband_fft_top is
	generic(
use_reorder    : boolean; -- = false for bit-reversed output, true for normal output
use_fft_shift  : boolean; -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
use_separate   : boolean; -- = false for complex input, true for two real inputs
alt_output     : boolean;
wb_factor      : natural; -- = default 1, wideband factor
nof_points     : natural; -- = 1024, N point FFT
in_dat_w       : natural; -- = 8,  number of input bits
out_dat_w      : natural; -- = 13, number of output bits
out_gain_w     : natural; -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
stage_dat_w    : natural; -- = 18, data width used between the stages(= DSP multiplier-width)
twiddle_dat_w  : natural;  -- = 18, the twiddle coefficient data width
max_addr_w     : natural;  -- = 8, ceoff address widths above which to implement in bram/ultraram
guard_w        : natural; -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
                          --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
                          --   12.3.2], therefore use input guard_w = 2.
guard_enable   : boolean; -- = true when input needs guarding, false when input requires no guarding but scaling must be
                          --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
                          --   doing the input guard and par fft section doing the output compensation)
pipe_reo_in_place : boolean;
use_variant    : string;  -- = "4DSP" or "3DSP" for 3 or 4 mult cmult.
use_dsp        : string;  -- = "yes" or "no"
ovflw_behav    : string;  -- = "WRAP" or "SATURATE" will default to WRAP if invalid option used
use_round      : natural;  -- = 0, 1, 2 - indices corresponding to the rounding modes in the common_pkg_lib
ram_primitive  : string  -- = "auto", "distributed", "block" or "ultra" for RAM architecture
);
port(
clk            : in std_logic;
ce             : in std_logic;
in_sync        : in std_logic:='0';
in_valid       : in std_logic:='0';
in_shiftreg    : in std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0);
out_ovflw      : out std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0) := (others=>'0');
out_sync       : out std_logic:='0';
out_valid      : out std_logic:='0';
in_im_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
in_re_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
out_im_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);
out_re_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0));
end entity wideband_fft_top;
architecture RTL of wideband_fft_top is
constant round_mode : t_rounding_mode := t_rounding_mode'val(use_round);
constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,0,wb_factor,nof_points,
in_dat_w,out_dat_w,out_gain_w,stage_dat_w,twiddle_dat_w,max_addr_w,guard_w,guard_enable, 56, 2, pipe_reo_in_place);
signal in_fft_sosi_arr : t_fft_sosi_arr_in(wb_factor - 1 downto 0);
signal out_fft_sosi_arr : t_fft_sosi_arr_out(wb_factor - 1 downto 0);
constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;
constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;
begin
fft_wide_unit : entity casper_wb_fft_lib.fft_wide_unit
generic map(
g_fft          => cc_fft,
g_pft_pipeline => c_pft_pipeline,
g_fft_pipeline => c_fft_pipeline,
g_alt_output => alt_output,
g_use_variant => use_variant,
g_use_dsp   => use_dsp,
g_ovflw_behav => ovflw_behav,
g_round => round_mode,
g_ram_primitive => ram_primitive
)
port map (
clken        => ce,
clk       => clk,
shiftreg  => in_shiftreg,
ovflw     => out_ovflw,
in_fft_sosi_arr  => in_fft_sosi_arr,
out_fft_sosi_arr => out_fft_sosi_arr);
otherinprtmap: for j in 0 to wb_factor-1 generate
in_fft_sosi_arr(j).sync <= in_sync;
in_fft_sosi_arr(j).valid <= in_valid;
end generate;
otheroutprtmap: for k in 0 to wb_factor-1 generate
out_sync<=out_fft_sosi_arr(k).sync;
out_valid<=out_fft_sosi_arr(k).valid;
end generate;
in_fft_sosi_arr(0).re <= RESIZE_SVEC(in_re_0, in_fft_sosi_arr(0).re'length);
in_fft_sosi_arr(0).im <= RESIZE_SVEC(in_im_0, in_fft_sosi_arr(0).im'length);
out_re_0 <= RESIZE_SVEC(out_fft_sosi_arr(0).re,out_dat_w);
out_im_0 <= RESIZE_SVEC(out_fft_sosi_arr(0).im,out_dat_w);
end architecture RTL;