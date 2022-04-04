library ieee, wb_fft_lib, r2sdf_fft_lib, common_pkg_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually.
entity wideband_fft_top is
	generic(
		use_reorder    : boolean := c_fft_use_reorder;       -- = false for bit-reversed output, true for normal output
		use_fft_shift  : boolean := c_fft_use_fft_shift;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
		use_separate   : boolean := c_fft_use_separate;       -- = false for complex input, true for two real inputs
		nof_chan       : natural := c_fft_nof_chan;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
		wb_factor      : natural := c_fft_wb_factor;       -- = default 1, wideband factor
		nof_points     : natural := c_fft_nof_points;       -- = 1024, N point FFT
		in_dat_w       : natural := c_fft_in_dat_w;       -- = 8,  number of input bits
		out_dat_w      : natural := c_fft_out_dat_w;       -- = 13, number of output bits
		out_gain_w     : natural := c_fft_out_gain_w;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
		stage_dat_w    : natural := c_fft_stage_dat_w;       -- = 18, data width used between the stages(= DSP multiplier-width)
                twiddle_dat_w  : natural := c_fft_twiddle_dat_w;
                max_addr_w     : natural := c_max_addr_w;
		guard_w        : natural := c_fft_guard_w;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
                                                    --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
                                                    --   12.3.2], therefore use input guard_w = 2.
		guard_enable   : boolean := c_fft_guard_enable       -- = true when input needs guarding, false when input requires no guarding but scaling must be
                                                    --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
                                                    --   doing the input guard and par fft section doing the output compensation)
    );
	port(
		clk : in std_logic := '1';
		ce : in std_logic := '1';
		rst : in std_logic := '0';
		in_sync : in std_logic := '1';
		in_valid : in std_logic := '1';
		in_shiftreg : in std_logic_vector(ceil_log2(nof_points) -1 DOWNTO 0) := (others=>'1');
                out_sync : out std_logic;
                out_valid : out std_logic;
                out_ovflw : out STD_LOGIC_VECTOR(ceil_log2(nof_points) -1 DOWNTO 0);
                in_bsn : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := (others=>'0');
		in_sop : in std_logic :='1';
		in_eop : in std_logic :='1';
		in_empty : in STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0) := (others=>'0');
		in_err : in STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0) := (others=>'0');
		in_channel : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0) := (others=>'0');
		out_bsn : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
		out_sop : out std_logic;
		out_eop : out std_logic;
		out_empty : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);
		out_err : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);
		out_channel : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);
		in_im_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0) := (others=>'0');
                in_re_0 : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0) := (others=>'0');
                out_im_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);
                out_re_0 : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0));
        
end entity wideband_fft_top;

architecture RTL of wideband_fft_top is
        constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,nof_chan,wb_factor,
        nof_points, in_dat_w,out_dat_w,out_gain_w,stage_dat_w,twiddle_dat_w,max_addr_w,guard_w,guard_enable, 56, 2);
        signal in_fft_sosi_arr : t_fft_sosi_arr_in(wb_factor - 1 downto 0);
        signal out_fft_sosi_arr : t_fft_sosi_arr_out(wb_factor - 1 downto 0);
        constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;
        constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;
        begin
        fft_wide_unit : entity work.fft_wide_unit
        generic map(
        g_fft          => cc_fft,
        g_pft_pipeline => c_pft_pipeline,
        g_fft_pipeline => c_fft_pipeline)
        port map (
        clken        => ce,
        rst       => rst,
        clk       => clk,
        shiftreg => in_shiftreg,
        in_fft_sosi_arr  => in_fft_sosi_arr,
        ovflw => out_ovflw,
        out_fft_sosi_arr => out_fft_sosi_arr);
        
        otherinprtmap: for j in 0 to wb_factor-1 generate
        in_fft_sosi_arr(j).sync <= in_sync;
        in_fft_sosi_arr(j).bsn <= in_bsn;
        in_fft_sosi_arr(j).valid <= in_valid;
        in_fft_sosi_arr(j).sop <= in_sop;
        in_fft_sosi_arr(j).eop <= in_eop;
        in_fft_sosi_arr(j).empty <= in_empty;
        in_fft_sosi_arr(j).channel <= in_channel;
        in_fft_sosi_arr(j).err <= in_err;
        end generate;
        otheroutprtmap: for k in 0 to wb_factor-1 generate
        out_sync <= out_fft_sosi_arr(k).sync;
        out_bsn <= out_fft_sosi_arr(k).bsn;
        out_valid <= out_fft_sosi_arr(k).valid ;
        out_sop <= out_fft_sosi_arr(k).sop;
        out_eop <= out_fft_sosi_arr(k).eop;
        out_empty <= out_fft_sosi_arr(k).empty;
        out_channel <= out_fft_sosi_arr(k).channel;
        out_err <= out_fft_sosi_arr(k).err;
        end generate;
        
        in_fft_sosi_arr(0).re <= RESIZE_SVEC(in_re_0, in_fft_sosi_arr(0).re'length);
        in_fft_sosi_arr(0).im <= RESIZE_SVEC(in_im_0, in_fft_sosi_arr(0).im'length);
        out_re_0 <= RESIZE_SVEC(out_fft_sosi_arr(0).re,out_dat_w);
        out_im_0 <= RESIZE_SVEC(out_fft_sosi_arr(0).im,out_dat_w);
end architecture RTL;