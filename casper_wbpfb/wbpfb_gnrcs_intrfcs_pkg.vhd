library ieee, common_pkg_lib, r2sdf_fft_lib, wb_fft_lib, casper_pfb_fir_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use casper_pfb_fir_lib.pfb_fir_pkg.all;

PACKAGE wbpfb_gnrcs_intrfcs_pkg IS

  CONSTANT c_wbpfb_nof_wb_streams : natural := 1;
  -- Parameters for the (wideband) poly phase filter. 
  type t_wpfb is record
    -- General parameters for the wideband poly phase filter
    wb_factor         : natural;        -- = default 4, wideband factor
    nof_points        : natural;        -- = 1024, N point FFT (Also the number of subbands for the filter part)
    nof_chan          : natural;        -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     
    nof_wb_streams    : natural;        -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream.

    -- Parameters for the poly phase filter
    nof_taps          : natural;        -- = 16, the number of FIR taps per subband
    fil_backoff_w     : natural;        -- = 0, number of bits for input backoff to avoid output overflow
    fil_in_dat_w      : natural;        -- = 8, number of input bits
    fil_out_dat_w     : natural;        -- = 16, number of output bits
    coef_dat_w        : natural;        -- = 16, data width of the FIR coefficients

    -- Parameters for the FFT         
    use_reorder       : boolean;        -- = false for bit-reversed output, true for normal output
    use_fft_shift     : boolean;        -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    use_separate      : boolean;        -- = false for complex input, true for two real inputs
    fft_in_dat_w      : natural;        -- = 16, number of input bits
    fft_out_dat_w     : natural;        -- = 16, number of output bits >= (fil_in_dat_w=8) + log2(nof_points=1024)/2 = 13
    fft_out_gain_w    : natural;        -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    stage_dat_w       : natural;        -- = 18, number of bits that are used inter-stage
    twiddle_dat_w     : natural;        -- twiddle coefficient data width
    max_addr_w        : natural;        -- address above which to store coefficients in BRAM/URAM
    guard_w           : natural;        -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
    --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
    --   12.3.2], therefore use input guard_w = 2.
    guard_enable      : boolean;        -- = true when input needs guarding, false when input requires no guarding but scaling must be
    --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
    --   doing the input guard and par fft section doing the output compensation)
    pipe_reo_in_place : boolean;        -- = false for pipelined FFT reorder double buffer, true for single
    -- Statistics information
    stat_data_w       : positive;       -- = 56
    stat_data_sz      : positive;       -- = 2
    nof_blk_per_sync  : natural;        -- = 800000, number of FFT output blocks per sync interval, used to pass on BSN

    -- Pipeline parameters for both poly phase filter and FFT. These are heritaged from the filter and fft libraries.  
    pft_pipeline      : t_fft_pipeline; -- Pipeline settings for the pipelined FFT
    fft_pipeline      : t_fft_pipeline; -- Pipeline settings for the parallel FFT
    pfb_fir_pipeline  : t_pfb_fir_pipeline; -- Pipeline settings for the filter units 
  end record;

  constant c_wpfb : t_wpfb := (c_fft_wb_factor, c_fft_nof_points, c_fft_nof_chan,
                               c_wbpfb_nof_wb_streams, c_pfb_fir_n_taps, c_pfb_fir_padding,
                               c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w,
                               c_fft_use_reorder, c_fft_use_fft_shift, c_fft_use_separate,
                               c_fft_in_dat_w, c_fft_out_dat_w, c_fft_out_gain_w, c_fft_stage_dat_w,
                               c_fft_twiddle_dat_w, c_max_addr_w, c_fft_guard_w, c_fft_guard_enable,
                               c_pipe_reo_in_place, 56, 2, 800000, c_fft_pipeline, c_fft_pipeline, c_pfb_fir_pipeline);

  ----------------------------------------------------------------------------------------------------------
  -- SOSI/SISO Arrays
  ----------------------------------------------------------------------------------------------------------
  TYPE t_dp_siso IS RECORD              -- Source In or Sink Out
    ready : STD_LOGIC;                  -- fine cycle based flow control using ready latency RL >= 0
    xon   : STD_LOGIC;                  -- coarse typically block based flow control using xon/xoff
  END RECORD;
  CONSTANT c_dp_siso_rdy : t_dp_siso := ('1', '1');

  TYPE t_dp_siso_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_siso;

  --t_dp_sosi record in. Since this always goes into the filterbank first, its bitwidth is the fil_in_dat_w
  TYPE t_fil_sosi_in IS RECORD          -- Source Out or Sink In
    sync  : STD_LOGIC;
    re    : STD_LOGIC_VECTOR(c_pfb_fir_din_w - 1 DOWNTO 0); -- data
    im    : STD_LOGIC_VECTOR(c_pfb_fir_din_w - 1 DOWNTO 0); -- data
    valid : STD_LOGIC;                  -- ctrl
  END RECORD;
  CONSTANT c_fil_sosi_rst_in : t_fil_sosi_in := ('0', (OTHERS => '0'), (OTHERS => '0'), '0');

  TYPE t_fil_sosi_arr_in IS ARRAY (INTEGER RANGE <>) OF t_fil_sosi_in;

  --t_dp_sosi record in. Since this always goes into the filterbank first, its bitwidth is the fil_in_dat_w
  TYPE t_fil_sosi_out IS RECORD         -- Source Out or Sink In
    sync  : STD_LOGIC;
    re    : STD_LOGIC_VECTOR(c_pfb_fir_dout_w - 1 DOWNTO 0); -- data
    im    : STD_LOGIC_VECTOR(c_pfb_fir_dout_w - 1 DOWNTO 0); -- data
    valid : STD_LOGIC;                  -- ctrl
  END RECORD;
  CONSTANT c_fil_sosi_rst_out : t_fil_sosi_out := ('0', (OTHERS => '0'), (OTHERS => '0'), '0');

  TYPE t_fil_sosi_arr_out IS ARRAY (INTEGER RANGE <>) OF t_fil_sosi_out;

  ----------------------------------------------------------------------------------------------------------
  -- Function declarations
  ----------------------------------------------------------------------------------------------------------
  -- function func_wpfb_maximum_sop_latency(wpfb : t_wpfb) return natural;
  -- function func_wpfb_set_nof_block_per_sync(wpfb : t_wpfb; nof_block_per_sync : NATURAL) return t_wpfb;
  -- FUNCTION func_dp_stream_bsn_set(st_sosi : t_fft_sosi_out; bsn : STD_LOGIC_VECTOR) RETURN t_fft_sosi_out;
  -- FUNCTION func_dp_stream_arr_combine_data_info_ctrl(dp : t_fft_sosi_arr_out; info, ctrl : t_fft_sosi_out) RETURN t_fft_sosi_arr_out;

END wbpfb_gnrcs_intrfcs_pkg;

PACKAGE BODY wbpfb_gnrcs_intrfcs_pkg IS

  -- function func_wpfb_maximum_sop_latency(wpfb : t_wpfb) return natural is
  --     constant c_nof_channels : natural := 2**wpfb.nof_chan;
  --     constant c_block_size   : natural := c_nof_channels * wpfb.nof_points / wpfb.wb_factor;
  --     constant c_block_dly    : natural := 10;
  --   begin
  --     -- The prefilter, pipelined FFT, pipelined reorder and the wideband separate reorder
  --     -- cause block latency.
  --     -- The parallel FFT has no block latency.
  --     -- The parallel FFT reorder is merely a rewiring and causes no latency.
  --     -- ==> This yields maximim 4 block latency
  --     -- ==> Add one extra block latency to round up
  --     -- Each block in the Wideband FFT also introduces about c_block_dly clock cycles of
  --     -- pipeline latency.
  --     -- ==> This yields maximum ( 5 * c_block_dly ) / c_block_size of block latency
  --     return 4 + 1 + (5 * c_block_dly) / c_block_size;
  --   end func_wpfb_maximum_sop_latency;

  --   -- Overwrite nof_block_per_sync field in wpfb (typically for faster simulation)
  --   function func_wpfb_set_nof_block_per_sync(wpfb : t_wpfb; nof_block_per_sync : NATURAL) return t_wpfb is
  --     variable v_wpfb : t_wpfb;
  --   begin
  --     v_wpfb := wpfb;
  --     v_wpfb.nof_blk_per_sync := nof_block_per_sync;
  --     return v_wpfb;
  --   end func_wpfb_set_nof_block_per_sync;  

  --   FUNCTION func_dp_stream_bsn_set(st_sosi : t_fft_sosi_out; bsn : STD_LOGIC_VECTOR) RETURN t_fft_sosi_out IS
  --     VARIABLE v_rec : t_fft_sosi_out := st_sosi;
  --   BEGIN
  --     v_rec.bsn := RESIZE_UVEC(bsn, c_dp_stream_bsn_w);
  --     RETURN v_rec;
  --   END func_dp_stream_bsn_set;

  -- -- Functions to combinatorially hold the data fields and to set or reset the info and control fields in an sosi array
  -- FUNCTION func_dp_stream_arr_combine_data_info_ctrl(dp : t_fft_sosi_arr_out; info, ctrl : t_fft_sosi_out) RETURN t_fft_sosi_arr_out IS
  -- VARIABLE v_dp : t_fft_sosi_arr_out(dp'RANGE) := dp;       -- hold sosi data
  -- BEGIN
  -- FOR I IN dp'RANGE LOOP                          -- set sosi info
  --   v_dp(I).bsn     := info.bsn;      -- sop
  --   v_dp(I).channel := info.channel;  -- sop
  --   v_dp(I).empty   := info.empty;    -- eop
  --   v_dp(I).err     := info.err;      -- eop
  --   -- set sosi ctrl
  --   v_dp(I).valid := ctrl.valid;
  --   v_dp(I).sop   := ctrl.sop;
  --   v_dp(I).eop   := ctrl.eop;
  --   v_dp(I).sync  := ctrl.sync;
  -- END LOOP;
  -- RETURN v_dp;
  -- END func_dp_stream_arr_combine_data_info_ctrl;

END wbpfb_gnrcs_intrfcs_pkg;
