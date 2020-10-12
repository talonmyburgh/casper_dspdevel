function topwb_code_gen(wb_factor)
    %gather all the string arrays required to write full file:
    filepath = fileparts(which(bdroot));                                   %get filepath of this sim design
    vhdlfile = filepath+"/"+bdroot+"_wb_fft_top.vhd";                         %filename for vhd file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%prtdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    lnsuptoportdec = ["library ieee, dp_pkg_lib, wb_fft_lib, r2sdf_fft_lib, common_pkg_lib;"
"use ieee.std_logic_1164.all;"
"use ieee.numeric_std.all;"
"use common_pkg_lib.common_pkg.all;"
"use dp_pkg_lib.dp_stream_pkg.ALL;"
"use wb_fft_lib.fft_pkg.all;"
"use r2sdf_fft_lib.rTwoSDFPkg.all;"
"--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually."
"entity wideband_fft_top is"
"	generic("
		"use_reorder    : boolean := True;       -- = false for bit-reversed output, true for normal output"
		"use_fft_shift  : boolean := True;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input"
		"use_separate   : boolean := True;       -- = false for complex input, true for two real inputs"
		"nof_chan       : natural := 0;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan "
		"wb_factor      : natural := 1;       -- = default 1, wideband factor"
		"twiddle_offset : natural := 0;       -- = default 0, twiddle offset for PFT sections in a wideband FFT"
		"nof_points     : natural := 1024;       -- = 1024, N point FFT"
		"in_dat_w       : natural := 8;       -- = 8,  number of input bits"
		"out_dat_w      : natural := 13;       -- = 13, number of output bits"
		"out_gain_w     : natural := 0;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w"
		"stage_dat_w    : natural := 18;       -- = 18, data width used between the stages(= DSP multiplier-width)"
		"guard_w        : natural := 2;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. "
		                                "--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section"
		                                "--   12.3.2], therefore use input guard_w = 2."
		"guard_enable   : boolean := True       -- = true when input needs guarding, false when input requires no guarding but scaling must be"
		                                "--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section"
		                                "--   doing the input guard and par fft section doing the output compensation)"
	");"
	"port("
		"clk : in std_logic;"
		"ce : in std_logic;"
		"rst : in std_logic;"
		"in_sync : in std_logic;"
		"in_bsn : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);"
		"in_valid : in std_logic;"
		"in_sop : in std_logic;"
		"in_eop : in std_logic;"
		"in_empty : in STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);"
		"in_err : in STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);"
		"in_channel : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);"
		"out_sync : out std_logic;"
		"out_bsn : out STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);"
		"out_valid : out std_logic;"
		"out_sop : out std_logic;"
		"out_eop : out std_logic;"
		"out_empty : out STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);"
		"out_err : out STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);"
		"out_channel : out STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);"];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    portdec = join(mknprts(wb_factor),'\n');                               %fetch port declarations
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%archdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    lnsafterarchopen = [");"
        "end entity wideband_fft_top;"
        "architecture RTL of wideband_fft_top is"
        "constant cc_fft : t_fft := (use_reorder,use_fft_shift,use_separate,nof_chan,wb_factor,twiddle_offset,"
        "nof_points, in_dat_w,out_dat_w,out_gain_w,stage_dat_w,guard_w,guard_enable,56,2);"
        "signal in_sosi_arr : t_dp_sosi_arr(wb_factor - 1 downto 0);"
        "signal out_sosi_arr : t_dp_sosi_arr(wb_factor - 1 downto 0);"
        "constant c_pft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "constant c_fft_pipeline : t_fft_pipeline := c_fft_pipeline;"
        "begin"
        "fft_wide_unit : entity wb_fft_lib.fft_wide_unit"
        "generic map("
        "g_fft          => cc_fft,"
        "g_pft_pipeline => c_pft_pipeline,"
        "g_fft_pipeline => c_fft_pipeline)"
        "port map ("
        "clken        => clken,"
        "dp_rst       => rst,"
        "dp_clk       => clk,"
        "in_sosi_arr  => in_sosi_arr,"
        "out_sosi_arr => out_sosi_arr);"
        "otherinprtmap: for j in 0 to wb_factor-1 generate"
        "in_sosi_arr(j).sync <= in_sync;"
        "in_sosi_arr(j).bsn <= in_bsn;"
        "in_sosi_arr(j).valid <= in_valid;"
        "in_sosi_arr(j).sop <= in_sop;"
        "in_sosi_arr(j).eop <= in_eop;"
        "in_sosi_arr(j).empty <= in_empty;"
        "in_sosi_arr(j).channel <= in_channel;"
        "in_sosi_arr(j).err <= in_err;"
        "end generate;"
        "otheroutprtmap: for k in 0 to wb_factor-1 generate"
        "out_sosi_arr(k).sync <= out_sync;"
        "out_sosi_arr(k).bsn <= out_bsn;"
        "out_sosi_arr(k).valid <= out_valid;"
        "out_sosi_arr(k).sop <= out_sop;"
        "out_sosi_arr(k).eop <= out_eop;"
        "out_sosi_arr(k).empty <= out_empty;"
        "out_sosi_arr(k).channel <= out_channel;"
        "out_sosi_arr(k).err <= out_err;"
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
    fprintf(Vfile,'%s\n',lnsuptoportdec{:});
    fprintf(Vfile,portdec{:});
    fprintf(Vfile,'%s\n',lnsafterarchopen{:});
    fprintf(Vfile,archdec{:});
    fprintf(Vfile,"\nend architecture RTL;");
    fclose(Vfile);
end

function chararr = mknprts(wbfctr)
chararr = strings(6*wbfctr,0);
inimchar = "in_im_%c : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);"; 
inrechar = "in_re_%c : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);"; 
indatchar = "in_data_%c : in STD_LOGIC_VECTOR(2*in_dat_w-1 DOWNTO 0);";
outimchar = "out_im_%c : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);"; 
outrechar = "out_re_%c : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);"; 
outdatchar = "out_data_%c : out STD_LOGIC_VECTOR(2*out_dat_w-1 DOWNTO 0);";
i=1;
    for j=0:1:wbfctr-1
        jj = int2str(j);
        chararr(i,1)=sprintf(inimchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(inrechar,jj);
        i=i+1;
        chararr(i,1)=sprintf(indatchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(outimchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(outrechar,jj);
        i=i+1;
        if (j ~= wbfctr-1)
            chararr(i,1)=sprintf(outdatchar,jj);
        else
            chararr(i,1)=sprintf(strip(outdatchar,';'),jj);
        end
        i=i+1;
    end
end

function achararr = mkarch(wbfctr)
    achararr = strings(6*wbfctr,0);
    imap_re_c = "in_sosi_arr(%c).re <= RESIZE_SVEC(in_re_%c, in_sosi_arr(%c).re'length);";
    imap_im_c = "in_sosi_arr(%c).im <= RESIZE_SVEC(in_im_%c, in_sosi_arr(%c).im'length);";
    imap_data_c = "in_sosi_arr(%c).data <= RESIZE_SVEC(in_data_%c, in_sosi_arr(%c).data'length);";
    omap_re_c = "out_re_%c <= RESIZE_SVEC(out_sosi_arr(%c).re,out_dat_w);";
    omap_im_c = "out_im_%c <= RESIZE_SVEC(out_sosi_arr(%c).im,out_dat_w);";
    omap_data_c = "out_data_%c <= RESIZE_SVEC(out_sosi_arr(%c).data,2*out_dat_w);";
    
    l = 1;
        for m=0:1:wbfctr-1
            mm = int2str(m);
            achararr(l,1)=sprintf(imap_re_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(imap_im_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(imap_data_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_re_c,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_im_c,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_data_c,mm,mm);
            l=l+1;
        end
end