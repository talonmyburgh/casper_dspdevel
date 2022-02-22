--------------------------------------------------------------------------------------------------------------
--Modification of the wpfb_unit_dev module by Talon Myburgh
--------------------------------------------------------------------------------------------------------------

library ieee, common_pkg_lib,r2sdf_fft_lib,casper_filter_lib,wb_fft_lib,casper_diagnostics_lib,casper_ram_lib;
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

entity wbpfb_unit_dev is
  generic (
    g_big_endian_wb_in  : boolean          := true;
    g_wpfb              : t_wpfb           := c_wpfb;
    g_dont_flip_channels: boolean          := false;   -- True preserves channel interleaving for pipelined FFT
    g_use_prefilter     : boolean          := TRUE;
    g_coefs_file_prefix : string           := c_coefs_file; -- File prefix for the coefficients files.
    g_fil_ram_primitive : string           := "block";
    g_use_variant       : string  		    := "4DSP";        										--! = "4DSP" or "3DSP" for 3 or 4 mult cmult.
    g_use_dsp           : string  		    := "yes";        										--! = "yes" or "no"
    g_ovflw_behav       : string  		    := "WRAP";        										--! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
    g_use_round         : string  		    := "ROUND";        										--! = "ROUND" or "TRUNCATE" will default to TRUNCATE if invalid option used
    g_fft_ram_primitive : string  		    := "block";        										--! = "auto", "distributed", "block" or "ultra" for RAM architecture
    g_fifo_primitive    : string  		    := "block";        										--! = "auto", "distributed", "block" or "ultra" for RAM architecture
    g_twid_file_stem    : string          := c_twid_file_stem                   --! file stem for the twiddle coefficients                  
   );
  port (
    rst                	: in  std_logic := '0';
    clk                	: in  std_logic := '0';
    ce                 	: in  std_logic := '1';
    shiftreg           	: in  std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0) := (others=>'1');			--! Shift register
    in_sosi_arr        	: in  t_fil_sosi_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_fil_sosi_rst_in);
    fil_sosi_arr       	: out t_fil_sosi_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
    ovflw              	: out std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0);			--! Ovflw register
    out_sosi_arr       	: out t_fft_sosi_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) 
  );
end entity wbpfb_unit_dev;

architecture str of wbpfb_unit_dev is

  constant c_nof_channels          : natural := 2**g_wpfb.nof_chan;
  
  constant c_nof_data_per_block    : natural := c_nof_channels * g_wpfb.nof_points;
  constant c_nof_valid_per_block   : natural := c_nof_data_per_block / g_wpfb.wb_factor;
  
  constant c_nof_stats             : natural := c_nof_valid_per_block;
  
  constant c_fil_ppf         : t_fil_ppf := (g_wpfb.wb_factor,
                                             g_wpfb.nof_chan,
                                             g_wpfb.nof_points,
                                             g_wpfb.nof_taps,
                                             c_nof_complex*g_wpfb.nof_wb_streams,  -- Complex FFT always requires 2 filter streams: real and imaginary
                                             g_wpfb.fil_backoff_w,
                                             g_wpfb.fil_in_dat_w,
                                             g_wpfb.fil_out_dat_w,
                                             g_wpfb.coef_dat_w);

  constant c_fft             : t_fft     := (g_wpfb.use_reorder,
                                             g_wpfb.use_fft_shift,
                                             g_wpfb.use_separate,
                                             g_wpfb.nof_chan,
                                             g_wpfb.wb_factor,
                                             0,
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

  constant c_fft_r2_check           : boolean := fft_r2_parameter_asserts(c_fft);
  
  constant c_bg_buf_adr_w           : natural := ceil_log2(g_wpfb.nof_points/g_wpfb.wb_factor);
  constant c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, g_wpfb.nof_wb_streams*g_wpfb.wb_factor, 1);
  constant c_bg_data_file_prefix    : string  := "UNUSED";

  signal fil_in_arr          : t_fil_slv_arr_in(c_nof_complex*g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fil_in_val          : std_logic;
  signal fil_out_arr         : t_fil_slv_arr_out(c_nof_complex*g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => (others => '0'));
  signal fil_out_val         : std_logic;
  
  signal fft_in_re_arr       : t_fft_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_in_im_arr       : t_fft_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_in_val          : std_logic;

  signal fft_out_re_arr      : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_im_arr      : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_re_arr_pipe : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_im_arr_pipe : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_val_arr     : std_logic_vector(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);

  signal fft_out_sosi        : t_fft_sosi_out;
  signal fft_out_sosi_arr    : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_fft_sosi_rst_out);
  
  signal pfb_out_sosi_arr    : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_fft_sosi_rst_out);
  
  type reg_type is record
    in_sosi_arr : t_fil_sosi_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  end record;

  signal r, rin : reg_type;

begin

  -- The complete input sosi arry is registered.
  comb : process(r, in_sosi_arr)
    variable v : reg_type;
  begin
    v             := r;
    v.in_sosi_arr := in_sosi_arr;
    rin           <= v;
  end process comb;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;

    ---------------------------------------------------------------
    -- REWIRE THE DATA FOR WIDEBAND POLY PHASE FILTER
    ---------------------------------------------------------------

    -- Wire in_sosi_arr --> fil_in_arr
    wire_fil_in_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
      wire_fil_in_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        fil_in_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex)   <= r.in_sosi_arr(S*g_wpfb.wb_factor+P).re(g_wpfb.fil_in_dat_w-1 downto 0);
        fil_in_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1) <= r.in_sosi_arr(S*g_wpfb.wb_factor+P).im(g_wpfb.fil_in_dat_w-1 downto 0);
      end generate;
    end generate;
    fil_in_val <= r.in_sosi_arr(0).valid;

    -- Wire fil_out_arr --> fil_sosi_arr
    wire_fil_sosi_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
      wire_fil_sosi_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
        fil_sosi_arr(S*g_wpfb.wb_factor+P).valid <= fil_out_val;
        fil_sosi_arr(S*g_wpfb.wb_factor+P).re    <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex  );
        fil_sosi_arr(S*g_wpfb.wb_factor+P).im    <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1);
      end generate;
    end generate; 
    
    -- Wire fil_out_arr --> fft_in_re_arr, fft_in_im_arr
    wire_fft_in_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
      wire_fft_in_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
        fft_in_re_arr(S*g_wpfb.wb_factor + P) <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex);
        fft_in_im_arr(S*g_wpfb.wb_factor + P) <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1);
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE POLY PHASE FILTER
    ---------------------------------------------------------------
    gen_prefilter : IF g_use_prefilter = TRUE generate
      u_filter : entity casper_filter_lib.fil_ppf_wide
      generic map (
        g_big_endian_wb_in  => g_big_endian_wb_in,
        g_big_endian_wb_out => false,  -- reverse wideband order from big-endian [3:0] = [t0,t1,t2,t3] in fil_ppf_wide to little-endian [3:0] = [t3,t2,t1,t0] in fft_r2_wide
        g_fil_ppf           => c_fil_ppf,
        g_fil_ppf_pipeline  => g_wpfb.fil_pipeline,
        g_coefs_file_prefix => g_coefs_file_prefix,
        g_ram_primitive     => g_fil_ram_primitive
      )
      port map (
        clk            => clk,
        ce             => ce,
        rst            => rst,
        in_dat_arr     => fil_in_arr,
        in_val         => fil_in_val,
        out_dat_arr    => fil_out_arr,
        out_val        => fil_out_val
      );
    end generate;

    -- Bypass filter
    no_prefilter : if g_use_prefilter = FALSE generate
      resize_fil_arr : for I in 0 TO c_nof_complex*g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 generate
          fil_out_arr(I) <= RESIZE_SVEC(fil_in_arr(I), g_wpfb.fil_out_dat_w);
      end generate;
      fil_out_val <= fil_in_val;
    end generate;

    fft_in_val <= fil_out_val;

    ---------------------------------------------------------------
    -- THE WIDEBAND FFT
    ---------------------------------------------------------------
    gen_wideband_fft: if g_wpfb.wb_factor > 1  generate
      gen_fft_r2_wide_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        u_fft_r2_wide : entity wb_fft_lib.fft_r2_wide
        generic map(
          g_fft            => c_fft,         -- generics for the WFFT
          g_pft_pipeline   => g_wpfb.pft_pipeline,
          g_fft_pipeline   => g_wpfb.fft_pipeline,
          g_use_variant    => g_use_variant,
          g_use_dsp        => g_use_dsp,
          g_ovflw_behav    => g_ovflw_behav,
          g_use_round      => g_use_round,
          g_ram_primitive  => g_fft_ram_primitive,
          g_fifo_primitive => g_fifo_primitive,
          g_twid_file_stem => g_twid_file_stem
        )
        port map(
          clk        => clk,
          rst        => rst,
          clken      => ce,
          in_re_arr  => fft_in_re_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          in_im_arr  => fft_in_im_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          shiftreg   => shiftreg,
          in_val     => fft_in_val,
          out_re_arr => fft_out_re_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          out_im_arr => fft_out_im_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          ovflw      => ovflw,
          out_val    => fft_out_val_arr(S)
        );
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE PIPELINED FFT
    ---------------------------------------------------------------
    gen_pipeline_fft: if g_wpfb.wb_factor = 1  generate
      gen_fft_r2_pipe_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        u_fft_r2_pipe : entity wb_fft_lib.fft_r2_pipe
        generic map(
          g_fft                => c_fft,
          g_dont_flip_channels => g_dont_flip_channels,
          g_pipeline           => g_wpfb.fft_pipeline,
          g_use_variant        => g_use_variant,
          g_use_dsp            => g_use_dsp,
          g_ovflw_behav        => g_ovflw_behav,
          g_use_round          => g_use_round,
          g_ram_primitive      => g_fft_ram_primitive,
          g_twid_file_stem     => g_twid_file_stem
        )
        port map(
          clk       => clk,
          rst       => rst,
          clken     => ce,
          shiftreg  => shiftreg,
          in_re     => fft_in_re_arr(S),
          in_im     => fft_in_im_arr(S),
          in_val    => fft_in_val,
          out_re    => fft_out_re_arr(S),
          out_im    => fft_out_im_arr(S),
          ovflw     => ovflw,
          out_val   => fft_out_val_arr(S)
        );
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- FFT CONTROL UNIT
    ---------------------------------------------------------------
    
    -- Capture input BSN at input sync and pass the captured input BSN it on to PFB output sync.
    -- The FFT output valid defines PFB output sync, sop, eop.

    fft_out_sosi.sync  <= r.in_sosi_arr(0).sync;  
    fft_out_sosi.bsn   <= r.in_sosi_arr(0).bsn;   
    fft_out_sosi.valid <= fft_out_val_arr(0);     
    
    wire_fft_out_sosi_arr : for I in 0 to g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 generate
      fft_out_sosi_arr(I).re    <= fft_out_re_arr(I);
      fft_out_sosi_arr(I).im    <= fft_out_im_arr(I);
      fft_out_sosi_arr(I).valid <= fft_out_val_arr(I);
    end generate;
    
    u_dp_block_gen_valid_arr : ENTITY work.dp_block_gen_valid_arr
    GENERIC MAP (
      g_nof_streams         => g_wpfb.nof_wb_streams*g_wpfb.wb_factor,
      g_nof_data_per_block  => c_nof_valid_per_block,
      g_nof_blk_per_sync    => g_wpfb.nof_blk_per_sync,
      g_check_input_sync    => false,
      g_nof_pages_bsn       => 1,
      g_restore_global_bsn  => true
    )
    PORT MAP (
      rst         => rst,
      clk         => clk,
      -- Streaming sink
      snk_in      => fft_out_sosi,
      snk_in_arr  => fft_out_sosi_arr,
      -- Streaming source
      src_out_arr => pfb_out_sosi_arr,
      -- Control
      enable      => '1'
    );

  -- Connect to the outside world
  out_sosi_arr <= pfb_out_sosi_arr;

end str;



