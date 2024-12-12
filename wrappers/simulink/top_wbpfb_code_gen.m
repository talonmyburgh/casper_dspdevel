function vhdlfile = top_wbpfb_code_gen(wb_factor, nof_wb_streams, twid_dat_w, nof_points, nof_taps, win, fwidth... 
    ,xtra_dat_sigs, fft_in_dat_w, fft_out_dat_w, fft_stage_dat_w...
    ,fil_coef_dat_w,fil_in_dat_w, fil_out_dat_w, vendor)
    %Locate where this matlab script is
    filepathscript = fileparts(which('top_wbpfb_code_gen'));
    %where the top vhdl file will be generated
    vhdlfilefolder = [fileparts(which(bdroot)) '/tmp_dspdevel'];
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    vhdlfile = [vhdlfilefolder '/' bdroot '_wbpfb_top.vhd'];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%prtdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    lnsuptoportdec_w_xtra = ["library ieee, common_pkg_lib,r2sdf_fft_lib,casper_filter_lib,wb_fft_lib,casper_diagnostics_lib,casper_ram_lib,wpfb_lib;"
    "use IEEE.std_logic_1164.all;"
    "use common_pkg_lib.common_pkg.all;"
    "use casper_ram_lib.common_ram_pkg.all;"
    "use r2sdf_fft_lib.rTwoSDFPkg.all;"
    "use casper_filter_lib.all;"
    "use casper_filter_lib.fil_pkg.all;"
    "use wb_fft_lib.all;"
    "use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;"
    "use wpfb_lib.all;"
    "use wpfb_lib.wbpfb_gnrcs_intrfcs_pkg.all;"

    "entity wbpfb_unit_top is"
    "generic ("
    "    g_big_endian_wb_in  : boolean          := true;"
    "    g_wb_factor         : natural          := 4;       -- = default 4, wideband factor"
    "    g_nof_points        : natural          := 1024;    -- = 1024, N point FFT (Also the number of subbands for the filter part)"
    "    g_nof_chan          : natural          := 0;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     "
    "    g_nof_wb_streams    : natural          := 1;       -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream."
    "    g_nof_taps          : natural          := 16;      -- = 16, the number of FIR taps per subband"
    "    g_fil_backoff_w     : natural          := 0;       -- = 0, number of bits for input backoff to avoid output overflow"
    "    g_fil_in_dat_w      : natural          := 8;       -- = 8, number of input bits"
    "    g_fil_out_dat_w     : natural          := 16;      -- = 16, number of output bits"
    "    g_coef_dat_w        : natural          := 16;      -- = 16, data width of the FIR coefficients"
    "    g_use_reorder       : boolean          := false;   -- = false for bit-reversed output, true for normal output"
    "    g_use_fft_shift     : boolean          := false;   -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input"
    "    g_use_separate      : boolean          := false;   -- = false for complex input, true for two real inputs"
    "    g_alt_output        : boolean;"
    "    g_fft_in_dat_w      : natural          := 16;      -- = 16, number of input bits"
    "    g_fft_out_dat_w     : natural          := 16;      -- = 16, number of output bits >= (fil_in_dat_w=8) + log2(nof_points=1024)/2 = 13"
    "    g_fft_out_gain_w    : natural          := 0;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w"
    "    g_stage_dat_w       : natural          := 18;      -- = 18, number of bits that are used inter-stage"
    "    g_twiddle_dat_w     : natural;                     -- = 18, the twiddle coefficient data width"
    "    g_max_addr_w        : natural;                     -- = 8, ceoff address widths above which to implement in bram/ultraram"
    "    g_guard_w           : natural          := 2;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. "
    "                                                    --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section"
    "                                                    --   12.3.2], therefore use input guard_w = 2."
    "    g_guard_enable      : boolean          := true;    -- = true when input needs guarding, false when input requires no guarding but scaling must be"
    "                                                    --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section"
    "                                                    --   doing the input guard and par fft section doing the output compensation)"
    "    g_pipe_reo_in_place   : boolean;"
    "    g_dont_flip_channels: boolean          := false; -- True preserves channel interleaving for pipelined FFT"
    "    g_use_prefilter     : boolean          := TRUE;"
    "    g_coefs_file_prefix : string           := c_coefs_file; -- File prefix for the coefficients files."
    "    g_fil_ram_primitive : string           := ""block"";"
    "    g_use_variant       : string  		     := ""4DSP"";       -- = ""4DSP"" or ""3DSP"" for 3 or 4 mult cmult."
    "    g_use_dsp           : string  		     := ""yes"";        -- = ""yes"" or ""no"""
    "    g_ovflw_behav       : string  		     := ""WRAP"";       -- = ""WRAP"" or ""SATURATE"" will default to WRAP if invalid option used"
    "    g_use_round         : natural           := 1;  -- = 0, 1, 2 - indices corresponding to the rounding modes in the common_pkg_lib"
    "    g_fft_ram_primitive : string  		     := ""block""      -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"
    ");"
    "port"
    "("
    "    clk                 : in  std_logic := '0';"
    "    ce                  : in  std_logic := '1';"
    "    shiftreg            : in  std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'1');			--! Shift register"
    "    ovflw               : out std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'0');"
    "    in_sync             : in std_logic := '0';"
    "    in_valid            : in std_logic :=' 0';"
    "    out_sync            : out std_logic := '0';"
    "    out_valid           : out std_logic := '0';"
    "    fil_sync            : out std_logic := '0';"
    "    fil_valid           : out std_logic := '0';"
    "    in_bsn              : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);"
    "    in_sop              : in std_logic;"
    "    in_eop              : in std_logic;"
    "    in_empty            : in STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);"
    "    in_err              : in STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);"
    "    in_channel          : in STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);"
    "    out_bsn             : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := (others=>'0');"
    "    out_sop             : out std_logic := '0';"
    "    out_eop             : out std_logic := '0';"
    "    out_empty           : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0) := (others=>'0');"
    "    out_err             : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0) := (others=>'0');"
    "    out_channel         : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0) := (others=>'0');"
    "    fil_bsn             : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);"
    "    fil_sop             : out std_logic;"
    "    fil_eop             : out std_logic;"
    "    fil_empty           : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);"
    "    fil_err             : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);"
    "    fil_channel         : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);"
        ];

    lnsuptoportdec_w_o_xtra = ["library ieee, common_pkg_lib,r2sdf_fft_lib,casper_filter_lib,wb_fft_lib,casper_diagnostics_lib,casper_ram_lib,wpfb_lib;"
    "use IEEE.std_logic_1164.all;"
    "use common_pkg_lib.common_pkg.all;"
    "use casper_ram_lib.common_ram_pkg.all;"
    "use r2sdf_fft_lib.rTwoSDFPkg.all;"
    "use casper_filter_lib.all;"
    "use casper_filter_lib.fil_pkg.all;"
    "use wb_fft_lib.all;"
    "use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;"
    "use wpfb_lib.all;"
    "use wpfb_lib.wbpfb_gnrcs_intrfcs_pkg.all;"

    "entity wbpfb_unit_top is"
    "generic ("
    "    g_big_endian_wb_in  : boolean          := true;"
    "    g_wb_factor         : natural          := 4;       -- = default 4, wideband factor"
    "    g_nof_points        : natural          := 1024;    -- = 1024, N point FFT (Also the number of subbands for the filter part)"
    "    g_nof_chan          : natural          := 0;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     "
    "    g_nof_wb_streams    : natural          := 1;       -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream."
    "    g_nof_taps          : natural          := 16;      -- = 16, the number of FIR taps per subband"
    "    g_fil_backoff_w     : natural          := 0;       -- = 0, number of bits for input backoff to avoid output overflow"
    "    g_fil_in_dat_w      : natural          := 8;       -- = 8, number of input bits"
    "    g_fil_out_dat_w     : natural          := 16;      -- = 16, number of output bits"
    "    g_coef_dat_w        : natural          := 16;      -- = 16, data width of the FIR coefficients"
    "    g_use_reorder       : boolean          := false;   -- = false for bit-reversed output, true for normal output"
    "    g_use_fft_shift     : boolean          := false;   -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input"
    "    g_use_separate      : boolean          := false;   -- = false for complex input, true for two real inputs"
    "    g_alt_output        : boolean;"
    "    g_fft_in_dat_w      : natural          := 16;      -- = 16, number of input bits"
    "    g_fft_out_dat_w     : natural          := 16;      -- = 16, number of output bits >= (fil_in_dat_w=8) + log2(nof_points=1024)/2 = 13"
    "    g_fft_out_gain_w    : natural          := 0;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w"
    "    g_stage_dat_w       : natural          := 18;      -- = 18, number of bits that are used inter-stage"
    "    g_twiddle_dat_w     : natural;                     -- = 18, the twiddle coefficient data width"
    "    g_max_addr_w        : natural;                     -- = 8, ceoff address widths above which to implement in bram/ultraram"
    "    g_guard_w           : natural          := 2;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. "
    "                                                    --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section"
    "                                                    --   12.3.2], therefore use input guard_w = 2."
    "    g_guard_enable      : boolean          := true;    -- = true when input needs guarding, false when input requires no guarding but scaling must be"
    "                                                    --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section"
    "                                                    --   doing the input guard and par fft section doing the output compensation)"
    "    g_pipe_reo_in_place   : boolean;"
    "    g_dont_flip_channels: boolean          := false; -- True preserves channel interleaving for pipelined FFT"
    "    g_use_prefilter     : boolean          := TRUE;"
    "    g_coefs_file_prefix : string           := c_coefs_file; -- File prefix for the coefficients files."
    "    g_fil_ram_primitive : string           := ""block"";"
    "    g_use_variant       : string  		     := ""4DSP"";       -- = ""4DSP"" or ""3DSP"" for 3 or 4 mult cmult."
    "    g_use_dsp           : string  		     := ""yes"";        -- = ""yes"" or ""no"""
    "    g_ovflw_behav       : string  		     := ""WRAP"";       -- = ""WRAP"" or ""SATURATE"" will default to WRAP if invalid option used"
    "    g_use_round         : natural           := 1;  -- = 0, 1, 2 - indices corresponding to the rounding modes in the common_pkg_lib"
    "    g_fft_ram_primitive : string  		     := ""block""      -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"
    ");"
    "port"
    "("
    "    clk                 : in  std_logic := '0';"
    "    ce                  : in  std_logic := '1';"
    "    shiftreg            : in  std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'1');			--! Shift register"
    "    ovflw               : out std_logic_vector(ceil_log2(g_nof_points) - 1 DOWNTO 0) := (others=>'0');"
    "    in_sync             : in std_logic := '0';"
    "    in_valid            : in std_logic := '0';"
    "    out_sync            : out std_logic := '0';"
    "    out_valid           : out std_logic := '0';"
    "    fil_sync            : out std_logic := '0';"
    "    fil_valid           : out std_logic := '0';"];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    portdec = join(mknprts(wb_factor,nof_wb_streams),'\n');                               %fetch port declarations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%archdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    lnsafterarchopen_w_xtradat = [");"
        "end wbpfb_unit_top;"
        "architecture RTL of wbpfb_unit_top is"
        "constant round_mode : t_rounding_mode := t_rounding_mode'val(g_use_round);"
        "constant cc_wpfb : t_wpfb := (g_wb_factor, g_nof_points, g_nof_chan, g_nof_wb_streams, g_nof_taps, g_fil_backoff_w, g_fil_in_dat_w, g_fil_out_dat_w,"
                                 "g_coef_dat_w, g_use_reorder, g_use_fft_shift, g_use_separate, g_fft_in_dat_w, g_fft_out_dat_w, g_fft_out_gain_w, g_stage_dat_w,"
                                 "g_twiddle_dat_w, g_max_addr_w, g_guard_w, g_guard_enable, g_pipe_reo_in_place, 56, 2, 800000, c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);"
    "signal in_fil_sosi_arr  : t_fil_sosi_arr_in(g_wb_factor*g_nof_wb_streams - 1 downto 0);"
    "signal out_fil_sosi_arr : t_fil_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0) := (others => c_fil_sosi_rst_out);"
    "signal out_fft_sosi_arr : t_fft_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0) := (others => c_fft_sosi_rst_out);"
    "begin"
    " wbpfb_unit : entity wpfb_lib.wbpfb_unit_dev"
    " generic map ("
    "   g_big_endian_wb_in   => g_big_endian_wb_in,"
    "   g_wpfb               => cc_wpfb,"
    "   g_dont_flip_channels => g_dont_flip_channels,"
    "   g_use_prefilter      => g_use_prefilter,"
    "   g_coefs_file_prefix  => g_coefs_file_prefix,"
    "   g_alt_output         => g_alt_output,"
    "   g_fil_ram_primitive  => g_fil_ram_primitive,"
    "   g_use_variant        => g_use_variant,"
    "   g_use_dsp            => g_use_dsp,"
    "   g_ovflw_behav        => g_ovflw_behav,"
    "   g_round              => round_mode,"
    "   g_fft_ram_primitive  => g_fft_ram_primitive"
    ")"
    " port map("
    "   rst                  => rst,"
    "   clk                  => clk,"
    "   ce                   => ce,"
    "   shiftreg             => shiftreg,"
    "   in_sosi_arr          => in_fil_sosi_arr,"
    "   fil_sosi_arr         => out_fil_sosi_arr,"
    "   ovflw                => ovflw,"
    "   out_sosi_arr         => out_fft_sosi_arr"
    " );"
    "otherinprtmap: for j in 0 to g_wb_factor-1 generate"
    "in_fil_sosi_arr(j).sync <= in_sync;"
    "in_fil_sosi_arr(j).bsn <= in_bsn;"
    "in_fil_sosi_arr(j).valid <= in_valid;"
    "in_fil_sosi_arr(j).sop <= in_sop;"
    "in_fil_sosi_arr(j).eop <= in_eop;"
    "in_fil_sosi_arr(j).empty <= in_empty;"
    "in_fil_sosi_arr(j).channel <= in_channel;"
    "in_fil_sosi_arr(j).err <= in_err;"
    "end generate;"
    "out_sync <= out_fft_sosi_arr(0).sync;"
    "out_bsn <= out_fft_sosi_arr(0).bsn;"
    "out_valid <= out_fft_sosi_arr(0).valid ;"
    "out_sop <= out_fft_sosi_arr(0).sop;"
    "out_eop <= out_fft_sosi_arr(0).eop;"
    "out_empty <= out_fft_sosi_arr(0).empty;"
    "out_channel <= out_fft_sosi_arr(0).channel;"
    "out_err <= out_fft_sosi_arr(0).err;"
%     "otheroutprtmap: for k in 0 to g_wb_factor-1 generate"
%     "out_sync <= out_fft_sosi_arr(k).sync;"
%     "out_bsn <= out_fft_sosi_arr(k).bsn;"
%     "out_valid <= out_fft_sosi_arr(k).valid ;"
%     "out_sop <= out_fft_sosi_arr(k).sop;"
%     "out_eop <= out_fft_sosi_arr(k).eop;"
%     "out_empty <= out_fft_sosi_arr(k).empty;"
%     "out_channel <= out_fft_sosi_arr(k).channel;"
%     "out_err <= out_fft_sosi_arr(k).err;"
%     "end generate;"
    "fil_sync <= out_fil_sosi_arr(0).sync;"
    "fil_bsn <= out_fil_sosi_arr(0).bsn;"
    "fil_valid <= out_fil_sosi_arr(0).valid ;"
    "fil_sop <= out_fil_sosi_arr(0).sop;"
    "fil_eop <= out_fil_sosi_arr(0).eop;"
    "fil_empty <= out_fil_sosi_arr(0).empty;"
    "fil_channel <= out_fil_sosi_arr(0).channel;"
    "fil_err <= out_fil_sosi_arr(0).err;"
%     "otherfilprtmap: for k in 0 to g_wb_factor-1 generate"
%     "fil_sync <= out_fil_sosi_arr(k).sync;"
%     "fil_bsn <= out_fil_sosi_arr(k).bsn;"
%     "fil_valid <= out_fil_sosi_arr(k).valid ;"
%     "fil_sop <= out_fil_sosi_arr(k).sop;"
%     "fil_eop <= out_fil_sosi_arr(k).eop;"
%     "fil_empty <= out_fil_sosi_arr(k).empty;"
%     "fil_channel <= out_fil_sosi_arr(k).channel;"
%     "fil_err <= out_fil_sosi_arr(k).err;"
%     "end generate;"
	];
    
    lnsafterarchopen_w_o_xtradat = [");"
    "end wbpfb_unit_top;"
    "architecture RTL of wbpfb_unit_top is"
    "constant round_mode : t_rounding_mode := t_rounding_mode'val(g_use_round);"
    "constant cc_wpfb : t_wpfb := (g_wb_factor, g_nof_points, g_nof_chan, g_nof_wb_streams, g_nof_taps, g_fil_backoff_w, g_fil_in_dat_w, g_fil_out_dat_w,"
                             "g_coef_dat_w, g_use_reorder, g_use_fft_shift, g_use_separate, g_fft_in_dat_w, g_fft_out_dat_w, g_fft_out_gain_w, g_stage_dat_w,"
                             "g_twiddle_dat_w, g_max_addr_w,g_guard_w, g_guard_enable, g_pipe_reo_in_place, 56, 2, 800000, c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);"
    "signal in_fil_sosi_arr  : t_fil_sosi_arr_in(g_wb_factor*g_nof_wb_streams - 1 downto 0);"
    "signal out_fil_sosi_arr : t_fil_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0) := (others => c_fil_sosi_rst_out);"
    "signal out_fft_sosi_arr : t_fft_sosi_arr_out(g_wb_factor*g_nof_wb_streams - 1 downto 0) := (others => c_fft_sosi_rst_out);"
    "begin"
    " wbpfb_unit : entity wpfb_lib.wbpfb_unit_dev"
    " generic map ("
    "   g_big_endian_wb_in   => g_big_endian_wb_in,"
    "   g_wpfb               => cc_wpfb,"
    "   g_dont_flip_channels => g_dont_flip_channels,"
    "   g_use_prefilter      => g_use_prefilter,"
    "   g_coefs_file_prefix  => g_coefs_file_prefix,"
    "   g_alt_output         => g_alt_output,"
    "   g_fil_ram_primitive  => g_fil_ram_primitive,"
    "   g_use_variant        => g_use_variant,"
    "   g_use_dsp            => g_use_dsp,"
    "   g_ovflw_behav        => g_ovflw_behav,"
    "   g_round              => round_mode,"
    "   g_fft_ram_primitive  => g_fft_ram_primitive"
    ")"
    " port map("
    "   rst                  => rst,"
    "   clk                  => clk,"
    "   ce                   => ce,"
    "   shiftreg             => shiftreg,"
    "   in_sosi_arr          => in_fil_sosi_arr,"
    "   fil_sosi_arr         => out_fil_sosi_arr,"
    "   ovflw                => ovflw,"
    "   out_sosi_arr         => out_fft_sosi_arr"
    " );"
    "otherinprtmap: for j in 0 to g_wb_factor-1 generate"
    "in_fil_sosi_arr(j).sync <= in_sync;"
    "in_fil_sosi_arr(j).valid <= in_valid;"
    "end generate;"
    "out_sync <= out_fft_sosi_arr(0).sync;"
    "out_valid <= out_fft_sosi_arr(0).valid;"
%     "otheroutprtmap: for k in 0 to g_wb_factor-1 generate"
%     "out_sync <= out_fft_sosi_arr(k).sync;"
%     "out_valid <= out_fft_sosi_arr(k).valid;"
%     "end generate;"
    "fil_sync <= out_fil_sosi_arr(0).sync;"
    "fil_valid <= out_fil_sosi_arr(0).valid;"
%     "otherfilprtmap: for k in 0 to g_wb_factor-1 generate"
%     "fil_sync <= out_fil_sosi_arr(k).sync;"
%     "fil_valid <= out_fil_sosi_arr(k).valid;"
%     "end generate;"
	];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %create an array of lines from architecture opening till where 
    %we wish to insert signal mappings in architecture
    archdec = join(mkarch(wb_factor,nof_wb_streams),'\n');
    
    %Done with breaking strings up, now write them to hdl file:
    Vfile = fopen(vhdlfile,'w');
    if(Vfile == -1) 
        error("Cannot open vhdl file"); 
    end
    if xtra_dat_sigs
        fprintf(Vfile,'%s\n',lnsuptoportdec_w_xtra{:});
    else
        fprintf(Vfile,'%s\n',lnsuptoportdec_w_o_xtra{:});
    end
    fprintf(Vfile,portdec{:});
    if xtra_dat_sigs
        fprintf(Vfile,'%s\n',lnsafterarchopen_w_xtradat{:});
    else
        fprintf(Vfile,'%s\n',lnsafterarchopen_w_o_xtradat{:});
    end
    fprintf(Vfile,archdec{:});
    fprintf(Vfile,"\nend architecture RTL;");
    fclose(Vfile);

    %Generate coefficients mem file for the filter:
    pyscriptloc = [filepathscript , '/fil_ppf_create.py'];
    command = sprintf("python %s -o %s -g 1 -t %d -p %d -w %d -c %d -v %d -W %s -F %d -V 0", pyscriptloc, vhdlfilefolder, nof_taps, nof_points, wb_factor, fil_coef_dat_w, 0, win, fwidth)';
    [status,cmdout] = system(command); %coefficient files will be generated at filepath/hex/
    
    if(status ~= 0)
        error("Filter coefficients not correctly generated by fil_ppf_create.py");
    end

    %update generics package
    coef_filepath_stem = strtrim(cmdout);
    updatefilpkg(filepathscript,vhdlfilefolder,fil_in_dat_w,fil_out_dat_w,fil_coef_dat_w,coef_filepath_stem);

    %Generate coefficients mem file for the fft:
    pyscriptloc = fullfile(filepathscript , 'sdf_fft_twid_create.py');
    command = sprintf("python %s -o %s -g 1 -p %d -w %d -c %d -v %d -V 0",strrep(pyscriptloc,'\','\\'), strrep(vhdlfilefolder,'\','\\'), nof_points, wb_factor, twid_dat_w, vendor);
    [status,cmdout] = system(command); %coefficient files will be generated at filepath/hex/
    
    if(status ~= 0)
        error("Filter coefficients not correctly generated by fil_ppf_create.py");
    end

    %update generics package
    twid_filepath_stem = strtrim(cmdout);
    updatefftpkg(filepathscript,vhdlfilefolder,fft_in_dat_w,fft_out_dat_w,fft_stage_dat_w,twid_filepath_stem);

    %generate twiddlePkg for parallel twiddle factors if wb_factor > 1:
    % if wb_factor > 1
    %     par_twiddle_pkg_gen(wb_factor, twid_dat_w, vhdlfilefolder);
    % end
end

function chararr = mknprts(wbfctr,nof_wb_streams)
    chararr = strings(6*wbfctr*nof_wb_streams,0);
    inimchar  = "in_im_str%d_wb%d             : in  STD_LOGIC_VECTOR(g_fil_in_dat_w -1 DOWNTO 0);";
    inrechar  = "in_re_str%d_wb%d             : in  STD_LOGIC_VECTOR(g_fil_in_dat_w -1 DOWNTO 0);";
    filimchar = "fil_im_str%d_wb%d            : out STD_LOGIC_VECTOR(g_fil_out_dat_w -1 DOWNTO 0);";
    filrechar = "fil_re_str%d_wb%d            : out STD_LOGIC_VECTOR(g_fil_out_dat_w -1 DOWNTO 0);";
    outrechar = "out_re_str%d_wb%d            : out STD_LOGIC_VECTOR(g_fft_out_dat_w -1 DOWNTO 0);";
    outimchar = "out_im_str%d_wb%d            : out STD_LOGIC_VECTOR(g_fft_out_dat_w -1 DOWNTO 0);";

    i=1;
    for k=0:1:nof_wb_streams-1
        for j=0:1:wbfctr-1
            chararr(i,1)=sprintf(inimchar,k,j);
            i=i+1;
            chararr(i,1)=sprintf(inrechar,k,j);
            i=i+1;
            chararr(i,1)=sprintf(filimchar,k,j);
            i=i+1;
            chararr(i,1)=sprintf(filrechar,k,j);
            i=i+1;
            chararr(i,1)=sprintf(outimchar,k,j);
            i=i+1;
            if (j ~= wbfctr-1 | k ~= nof_wb_streams-1)
                chararr(i,1)=sprintf(outrechar,k,j);
            else
                chararr(i,1)=sprintf(strip(outrechar,';'),k,j);
            end
            i=i+1;
        end
    end
end

function achararr = mkarch(wbfctr,nof_wb_streams)
    achararr = strings(6*wbfctr*nof_wb_streams,0);
    imap_re_c = "in_fil_sosi_arr(%d).re <= in_re_str%d_wb%d;";
    imap_im_c = "in_fil_sosi_arr(%d).im <= in_im_str%d_wb%d;";
    fmap_re_c = "fil_re_str%d_wb%d <= out_fil_sosi_arr(%d).re;";
    fmap_im_c = "fil_im_str%d_wb%d <= out_fil_sosi_arr(%d).im;";
    omap_re_c = "out_re_str%d_wb%d <= out_fft_sosi_arr(%d).re;";
    omap_im_c = "out_im_str%d_wb%d <= out_fft_sosi_arr(%d).im;";
    l = 1;
    arr_index = 0;
    for n=0:1:nof_wb_streams-1
        for m=0:1:wbfctr-1
            achararr(l,1)=sprintf(imap_re_c,arr_index,n,m);
            l=l+1;
            achararr(l,1)=sprintf(imap_im_c,arr_index,n,m);
            l=l+1;
            achararr(l,1)=sprintf(fmap_re_c,n,m,arr_index);
            l=l+1;
            achararr(l,1)=sprintf(fmap_im_c,n,m,arr_index);
            l=l+1;
            achararr(l,1)=sprintf(omap_re_c,n,m,arr_index);
            l=l+1;
            achararr(l,1)=sprintf(omap_im_c,n,m,arr_index);
            l=l+1;
            arr_index = arr_index + 1;
        end
    end
end

function updatefftpkg(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, stage_dat_w, twid_filepath_stem)
    %WRITE OUT THE FFTGNRCSINTRFCSPKG
    insertloc = 7; %Change this if you change the fft_gnrcs_intrfcs_pkg.vhd file so the line numbers change
    pkgsource = [filepathscript '/../../casper_wb_fft/fft_gnrcs_intrfcs_pkg.vhd'];
    pkgdest = [vhdlfilefolder '/fft_gnrcs_intrfcs_pkg.vhd'];
    lineone = sprintf(  "CONSTANT c_fft_in_dat_w       : natural := %d;    -- = 8,  number of input bits",in_dat_w);
    linetwo = sprintf(  "CONSTANT c_fft_out_dat_w      : natural := %d;    -- = 13, number of output bits",out_dat_w);
    linethree = sprintf("CONSTANT c_fft_stage_dat_w    : natural := %d;    -- = 18, data width used between the stages(= DSP multiplier-width)",stage_dat_w);

    fid = fopen(pkgsource,'r');
    if(fid == -1) 
        error("Cannot open vhdl file: %s",pkgsource); 
    end
    lines = textscan(fid, '%s', 'Delimiter', '\n', 'CollectOutput',true);
    lines = lines{1};
    fclose(fid);

    fid = fopen(pkgdest, 'w');
    if(fid == -1) 
        error("Cannot open vhdl file: %s",pkgdest); 
    end
    for jj = 1: insertloc
        fprintf(fid,'%s\n',lines{jj});
    end
    fprintf(fid,'%s\n', lineone);
    fprintf(fid,'%s\n',linetwo);
    fprintf(fid,'%s\n',linethree);
    for jj = insertloc+4 : length(lines)
        fprintf( fid, '%s\n', lines{jj} );
    end
    fclose(fid);

    %WRITE OUT THE RTWOSDFPKG
    insertloc = 5; %Change this if you change the rTwoSDFPkg.vhd file such that the line numbers change
    pkgsource = [filepathscript '/../../r2sdf_fft/rTwoSDFPkg.vhd'];
    pkgdest = [vhdlfilefolder '/rTwoSDFPkg.vhd'];
    line = sprintf("constant c_twid_file_stem : string := ""%s"";",twid_filepath_stem);
    fid = fopen(pkgsource,'r');
    if(fid == -1) 
        error("Cannot open vhdl file: %s",pkgsource); 
    end
    lines = textscan(fid, '%s', 'Delimiter', '\n', 'CollectOutput',true);
    lines = lines{1};
    fclose(fid);
    fid = fopen(pkgdest, 'w');
    if(fid == -1) 
        error("Cannot open vhdl file: %s",pkgdest); 
    end
    for jj = 1: insertloc
        fprintf(fid,'%s\n',lines{jj});
    end
    fprintf(fid,'%s\n', line);
    for jj = insertloc+4 : length(lines)
        fprintf( fid, '%s\n', lines{jj} );
    end
    fclose(fid);
end

function updatefilpkg(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, coef_dat_w, coef_filepath_stem)
    insertloc = 7;
    pkgsource = [filepathscript '/../../casper_filter/fil_pkg.vhd'];
    pkgdest = [vhdlfilefolder '/fil_pkg.vhd'];
    lineone = sprintf("CONSTANT c_fil_in_dat_w : natural := %d;",in_dat_w);
    linetwo = sprintf("CONSTANT c_fil_out_dat_w : natural := %d;", out_dat_w);
    linethree = sprintf("CONSTANT c_fil_coef_dat_w : natural :=%d;",coef_dat_w);
    linefour = sprintf("CONSTANT c_coefs_file : string := ""%s"";", coef_filepath_stem);
    fid = fopen(pkgsource,'r');
    if fid==-1
        error("Cannot open vhdl pkg file");
    end
    lines = textscan(fid,'%s', 'delimiter','\n','CollectOutput',true);
    lines = lines{1};
    fclose(fid);

    fid=fopen(pkgdest,'w');
    if(fid == -1) 
        error("Cannot open vhdl file: %s",pkgdest); 
    end
    for jj = 1:insertloc
        fprintf(fid,'%s\n',lines{jj});
    end
    fprintf(fid,'%s\n',lineone);
    fprintf(fid,'%s\n',linetwo);
    fprintf(fid,'%s\n',linethree);
    fprintf(fid,'%s\n',linefour);
    for jj = insertloc + 5 : length(lines)
        fprintf(fid,'%s\n',lines{jj});
    end
    fclose(fid);
end