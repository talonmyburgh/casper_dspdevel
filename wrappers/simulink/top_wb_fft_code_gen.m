function vhdlfile = top_wb_fft_code_gen(wb_factor,nof_points,twid_dat_w,vendor, xtra_dat_sigs, in_dat_w, out_dat_w, stage_dat_w)

    %Locate where this matlab script is
    filepathscript = fileparts(which('top_wb_fft_code_gen'));
    %where the top vhdl file will be generated
    vhdlfilefolder = fullfile(fileparts(which(bdroot)), '/tmp_dspdevel');
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    vhdlfile = fullfile(vhdlfilefolder,[bdroot '_wb_fft_top.vhd']);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%prtdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    lnsuptoportdec_w_xtra = ["library ieee, casper_wb_fft_lib, r2sdf_fft_lib, common_pkg_lib;"
"use ieee.std_logic_1164.all;"
"use ieee.numeric_std.all;"
"use common_pkg_lib.common_pkg.all;"
"use casper_wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;"
"use r2sdf_fft_lib.rTwoSDFPkg.all;"
"--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually."
"entity wideband_fft_top is"
"	generic("
		"use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output"
		"use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input"
		"use_separate   : boolean;  -- = false for complex input, true for two real inputs"
		"wb_factor      : natural;  -- = default 1, wideband factor"
		"nof_points     : natural;  -- = 1024, N point FFT"
		"in_dat_w       : natural;  -- = 8,  number of input bits"
		"out_dat_w      : natural;  -- = 13, number of output bits"
		"out_gain_w     : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w"
		"stage_dat_w    : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)"
        "twiddle_dat_w  : natural;  -- = 18, the twiddle coefficient data width"
        "max_addr_w     : natural;  -- = 8, ceoff address widths above which to implement in bram/ultraram"
		"guard_w        : natural;  -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. "
        "                           --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section"
        "                           --   12.3.2], therefore use input guard_w = 2."
		"guard_enable   : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be"
        "                           --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section"
        "                           --   doing the input guard and par fft section doing the output compensation)"
        "use_variant    : string;   -- = ""4DSP"" or ""3DSP"" for 3 or 4 mult cmult."
        "use_dsp        : string;   -- = ""yes"" or ""no"""
        "ovflw_behav    : string;   -- = ""WRAP"" or ""SATURATE"" will default to WRAP if invalid option used"
        "use_round      : string;   -- = ""ROUND"" or ""TRUNCATE"" will default to TRUNCATE if invalid option used"
        "ram_primitive  : string;   -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"
        "fifo_primitive : string    -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"                                        
	");"
	"port("
		"clk            : in std_logic;"
		"ce             : in std_logic;"
		"rst            : in std_logic;"
		"in_sync        : in std_logic;"
        "in_valid       : in std_logic;"
        "in_shiftreg    : in std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0);"
        "out_ovflw      : out std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0) := (others=>'0');"
        "out_sync       : out std_logic := '0';"
        "out_valid      : out std_logic := '0';"
        "in_bsn         : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);"
		"in_sop         : in std_logic;"
		"in_eop         : in std_logic;"
		"in_empty       : in STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);"
		"in_err         : in STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);"
		"in_channel     : in STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);"
		"out_bsn        : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := (others=>'0');"
		"out_sop        : out std_logic := '0';"
		"out_eop        : out std_logic := '0';"
		"out_empty      : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0) := (others=>'0');"
		"out_err        : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0) := (others=>'0');"
		"out_channel    : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0) := (others=>'0');"];
    
    lnsuptoportdec_w_o_xtra = ["library ieee,casper_wb_fft_lib, r2sdf_fft_lib, common_pkg_lib;"
"use ieee.std_logic_1164.all;"
"use ieee.numeric_std.all;"
"use common_pkg_lib.common_pkg.all;"
"use casper_wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;"
"use r2sdf_fft_lib.rTwoSDFPkg.all;"
"--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually."
"entity wideband_fft_top is"
"	generic("
        "use_reorder    : boolean; -- = false for bit-reversed output, true for normal output"
        "use_fft_shift  : boolean; -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input"
        "use_separate   : boolean; -- = false for complex input, true for two real inputs"
        "wb_factor      : natural; -- = default 1, wideband factor"
        "nof_points     : natural; -- = 1024, N point FFT"
        "in_dat_w       : natural; -- = 8,  number of input bits"
        "out_dat_w      : natural; -- = 13, number of output bits"
        "out_gain_w     : natural; -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w"
        "stage_dat_w    : natural; -- = 18, data width used between the stages(= DSP multiplier-width)"
        "twiddle_dat_w  : natural;  -- = 18, the twiddle coefficient data width"
        "max_addr_w     : natural;  -- = 8, ceoff address widths above which to implement in bram/ultraram"
        "guard_w        : natural; -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. "
        "                          --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section"
        "                          --   12.3.2], therefore use input guard_w = 2."
        "guard_enable   : boolean; -- = true when input needs guarding, false when input requires no guarding but scaling must be"
        "                          --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section"
        "                          --   doing the input guard and par fft section doing the output compensation)"
        "use_variant    : string;  -- = ""4DSP"" or ""3DSP"" for 3 or 4 mult cmult."
        "use_dsp        : string;  -- = ""yes"" or ""no"""
        "ovflw_behav    : string;  -- = ""WRAP"" or ""SATURATE"" will default to WRAP if invalid option used"
        "use_round      : string;  -- = ""ROUND"" or ""TRUNCATE"" will default to TRUNCATE if invalid option used"
        "ram_primitive  : string;  -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"
        "fifo_primitive : string  -- = ""auto"", ""distributed"", ""block"" or ""ultra"" for RAM architecture"     
	");"
	"port("
		"clk            : in std_logic;"
		"ce             : in std_logic;"
		"rst            : in std_logic;"
		"in_sync        : in std_logic:='0';"
        "in_valid       : in std_logic:='0';"
        "in_shiftreg    : in std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0);"
        "out_ovflw      : out std_logic_vector(ceil_log2(nof_points)-1 DOWNTO 0) := (others=>'0');"
        "out_sync       : out std_logic:='0';"
        "out_valid      : out std_logic:='0';"];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    portdec = join(mknprts(wb_factor),'\n');                               %fetch port declarations
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%archdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    lnsafterarchopen_w_xtradat = [");"
        "end entity wideband_fft_top;"
        "architecture RTL of wideband_fft_top is"
        "constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,0,wb_factor,0,nof_points,"
        "in_dat_w,out_dat_w,out_gain_w,stage_dat_w,twiddle_dat_w,max_addr_w,guard_w,guard_enable, 56, 2);"
        "signal in_fft_sosi_arr : t_bb_sosi_arr_in(wb_factor - 1 downto 0);"
        "signal out_fft_sosi_arr : t_bb_sosi_arr_out(wb_factor - 1 downto 0);"
        "constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "begin"
        "fft_wide_unit : entity casper_wb_fft_lib.fft_wide_unit"
        "generic map("
        "g_fft          => cc_fft,"
        "g_pft_pipeline => c_pft_pipeline,"
        "g_fft_pipeline => c_fft_pipeline,"
        "g_use_variant => use_variant,"
        "g_use_dsp   => use_dsp,"
        "g_ovflw_behav => ovflw_behav,"
        "g_use_round => use_round,"
        "g_ram_primitive => ram_primitive,"
        "g_fifo_primitive => fifo_primitive"
        ")"
        "port map ("
        "clken        => ce,"
        "rst       => rst,"
        "clk       => clk,"
        "shiftreg  => in_shiftreg,"
        "ovflw     => out_ovflw,"
        "in_fft_sosi_arr  => in_fft_sosi_arr,"
        "out_fft_sosi_arr => out_fft_sosi_arr);"
        "otherinprtmap: for j in 0 to wb_factor-1 generate"
        "in_fft_sosi_arr(j).sync <= in_sync;"
        "in_fft_sosi_arr(j).bsn <= in_bsn;"
        "in_fft_sosi_arr(j).valid <= in_valid;"
        "in_fft_sosi_arr(j).sop <= in_sop;"
        "in_fft_sosi_arr(j).eop <= in_eop;"
        "in_fft_sosi_arr(j).empty <= in_empty;"
        "in_fft_sosi_arr(j).channel <= in_channel;"
        "in_fft_sosi_arr(j).err <= in_err;"
        "end generate;"
        "otheroutprtmap: for k in 0 to wb_factor-1 generate"
        "out_sync <= out_fft_sosi_arr(k).sync;"
        "out_bsn <= out_fft_sosi_arr(k).bsn;"
        "out_valid <= out_fft_sosi_arr(k).valid ;"
        "out_sop <= out_fft_sosi_arr(k).sop;"
        "out_eop <= out_fft_sosi_arr(k).eop;"
        "out_empty <= out_fft_sosi_arr(k).empty;"
        "out_channel <= out_fft_sosi_arr(k).channel;"
        "out_err <= out_fft_sosi_arr(k).err;"
        "end generate;"
		];
    
    lnsafterarchopen_w_o_xtradat = [");"
        "end entity wideband_fft_top;"
        "architecture RTL of wideband_fft_top is"
        "constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,0,wb_factor,0,nof_points,"
        "in_dat_w,out_dat_w,out_gain_w,stage_dat_w,twiddle_dat_w,max_addr_w,guard_w,guard_enable, 56, 2);"
        "signal in_fft_sosi_arr : t_fft_sosi_arr_in(wb_factor - 1 downto 0);"
        "signal out_fft_sosi_arr : t_fft_sosi_arr_out(wb_factor - 1 downto 0);"
        "constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "begin"
        "fft_wide_unit : entity casper_wb_fft_lib.fft_wide_unit"
        "generic map("
        "g_fft          => cc_fft,"
        "g_pft_pipeline => c_pft_pipeline,"
        "g_fft_pipeline => c_fft_pipeline,"
        "g_use_variant => use_variant,"
        "g_use_dsp   => use_dsp,"
        "g_ovflw_behav => ovflw_behav,"
        "g_use_round => use_round,"
        "g_ram_primitive => ram_primitive,"
        "g_fifo_primitive => fifo_primitive"
        ")"
        "port map ("
        "clken        => ce,"
        "rst       => rst,"
        "clk       => clk,"
        "shiftreg  => in_shiftreg,"
        "ovflw     => out_ovflw,"
        "in_fft_sosi_arr  => in_fft_sosi_arr,"
        "out_fft_sosi_arr => out_fft_sosi_arr);"
        "otherinprtmap: for j in 0 to wb_factor-1 generate"
        "in_fft_sosi_arr(j).sync <= in_sync;"
        "in_fft_sosi_arr(j).valid <= in_valid;"
        "end generate;"
        "otheroutprtmap: for k in 0 to wb_factor-1 generate"
        "out_sync<=out_fft_sosi_arr(k).sync;"
        "out_valid<=out_fft_sosi_arr(k).valid;"
        "end generate;"
		];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %create an array of lines from architecture opening till where 
    %we wish to insert signal mappings in architecture
    archdec = join(mkarch(wb_factor),'\n');
    
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

    %Generate twiddle coefficient mem files for the fft:
    pyscriptloc = fullfile(filepathscript , 'sdf_fft_twid_create.py');
    command = sprintf("python %s -o %s -g 1 -p %d -w %d -c %d -v %d -V 0",strrep(pyscriptloc,'\','\\'), strrep(vhdlfilefolder,'\','\\'), nof_points, wb_factor, twid_dat_w, vendor);
    [status,cmdout] = system(command); %coefficient files will be generated at filepath/twids/
    if(status ~= 0)
        error("FFT coefficients not correctly generated by sdf_fft_twid_create.py");
    end
    
    %Update fil_pkg.vhd:
    coef_filepath_stem = strtrim(cmdout);
    
    %update generics package
    updatepkgs(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, stage_dat_w, coef_filepath_stem);

    %generate twiddlePkg for parallel twiddle factors:
    par_twiddle_pkg_gen(nof_points, twid_dat_w, vhdlfilefolder);
end

function chararr = mknprts(wbfctr)

    chararr = strings(4*wbfctr,0);
    inimchar = "in_im_%d : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);";
    inrechar = "in_re_%d : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);";
    outimchar = "out_im_%d : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);";
    outrechar = "out_re_%d : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);";

    i=1;
    for j=0:1:wbfctr-1
        chararr(i,1)=sprintf(inimchar,j);
        i=i+1;
        chararr(i,1)=sprintf(inrechar,j);
        i=i+1;
        chararr(i,1)=sprintf(outimchar,j);
        i=i+1;
        if (j ~= wbfctr-1)
            chararr(i,1)=sprintf(outrechar,j);
        else
            chararr(i,1)=sprintf(strip(outrechar,';'),j);
        end
        i=i+1;
    end
end

function achararr = mkarch(wbfctr)
    achararr = strings(4*wbfctr,0);
    imap_re_c = "in_fft_sosi_arr(%d).re <= RESIZE_SVEC(in_re_%d, in_fft_sosi_arr(%d).re'length);";
    imap_im_c = "in_fft_sosi_arr(%d).im <= RESIZE_SVEC(in_im_%d, in_fft_sosi_arr(%d).im'length);";
    omap_re_c = "out_re_%d <= RESIZE_SVEC(out_fft_sosi_arr(%d).re,out_dat_w);";
    omap_im_c = "out_im_%d <= RESIZE_SVEC(out_fft_sosi_arr(%d).im,out_dat_w);";
    l = 1;
    for m=0:1:wbfctr-1
        achararr(l,1)=sprintf(imap_re_c,m,m,m);
        l=l+1;
        achararr(l,1)=sprintf(imap_im_c,m,m,m);
        l=l+1;
        achararr(l,1)=sprintf(omap_re_c,m,m);
        l=l+1;
        achararr(l,1)=sprintf(omap_im_c,m,m);
        l=l+1;
   end
end

function updatepkgs(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, stage_dat_w, coef_filepath_stem)
    
    %WRITE OUT THE FFT_GNRCS_INTRFCS_PKG
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
    line = sprintf("constant c_twid_file_stem : string := ""%s"";",coef_filepath_stem);
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
