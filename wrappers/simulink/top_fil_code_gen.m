function vhdlfile = top_fil_code_gen(wb_factor, nof_bands, nof_taps, win, fwidth, vendor, in_dat_w, out_dat_w, coef_dat_w)
    %gather all the string arrays required to write full file:
    filepathscript = fileparts(which('top_fil_code_gen'));                 %get the filepath of this script (and thereby all scripts needed)
    %where the top vhdl file will be generated
    vhdlfilefolder = [fileparts(which(bdroot)) '/tmp_dspdevel'];
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    vhdlfile = [vhdlfilefolder '/' bdroot '_fil_top.vhd'];              %filename for vhd file

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%prtdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    lnsuptoportdec = ["library IEEE, common_pkg_lib, casper_ram_lib, casper_filter_lib, casper_mm_lib;"
    "use IEEE.std_logic_1164.ALL;"
    "use IEEE.numeric_std.ALL;"
    "use common_pkg_lib.common_pkg.ALL; "
    "use casper_ram_lib.common_ram_pkg.ALL;"
    "use casper_filter_lib.fil_pkg.ALL;"
    "entity top_fil is generic ("
    "g_big_endian_wb_in  : boolean;          -- input endian"
    "g_big_endian_wb_out : boolean;          -- output endian"
    "g_in_dat_w          : natural;          -- input data width"
    "g_coef_dat_w        : natural;          -- coefficient data width"
    "g_out_dat_w         : natural;          -- output data width"
    "g_wb_factor         : natural;          -- wideband factor"
    "g_nof_chan          : natural;          -- number of channels"
    "g_nof_bands         : natural;          -- number of bands"
    "g_nof_taps          : natural;          -- number of taps"
    "g_nof_streams       : natural;          -- number of streams"
    "g_backoff_w         : natural;          -- backoff width"
    "g_ram_primitive     : string);          -- ram primitive function for use"
    "port("
    "clk            : in  std_logic;"
    "ce             : in  std_logic;"
    "rst            : in  std_logic;"
    "in_val         : in  std_logic;"
    "out_val        : out std_logic := '1';"];

    portdec = join(mknprts(wb_factor),'\n');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%archdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    lnsafterarchopen =[
    ");"
    "end top_fil;"
    "architecture rtl of top_fil is"
    "constant cc_fil_ppf : t_fil_ppf := (g_wb_factor, g_nof_chan, g_nof_bands, g_nof_taps, g_nof_streams, g_backoff_w, g_in_dat_w, g_out_dat_w, g_coef_dat_w);"
    "signal in_dat_arr : t_fil_slv_arr_in(g_wb_factor*g_nof_streams -1 DOWNTO 0);"
    "signal out_dat_arr : t_fil_slv_arr_out(g_wb_factor*g_nof_streams -1 DOWNTO 0);"
    "begin"
    "wide_ppf : entity casper_filter_lib.fil_ppf_wide"
    "generic map("
    "g_big_endian_wb_in  => g_big_endian_wb_in,"
    "g_big_endian_wb_out => g_big_endian_wb_out,"
    "g_fil_ppf           => cc_fil_ppf,"
    "g_fil_ppf_pipeline  => c_fil_ppf_pipeline,"
    "g_coefs_file_prefix => c_coefs_file,"
    "g_ram_primitive     => g_ram_primitive)"
    "port map("
    "clk => clk,"
    "ce => ce,"
    "rst => rst,"
    "in_dat_arr => in_dat_arr,"
    "in_val => in_val,"
    "out_dat_arr => out_dat_arr,"
    "out_val => out_val);"];
    archdec = join(mkarch(wb_factor),'\n');
    Vfile = fopen(vhdlfile,'w');
    if(Vfile == -1)
        error("Cannot open vhdl file");
    end
    fprintf(Vfile,'%s\n',lnsuptoportdec{:});
    fprintf(Vfile,portdec{:});
    fprintf(Vfile,'%s\n',lnsafterarchopen{:});
    fprintf(Vfile,archdec{:});
    fprintf(Vfile,"\nend architecture rtl;");
    fclose(Vfile);

    %Generate coefficients mem file for the filter:
    pyscriptloc = [filepathscript , '/fil_ppf_create.py'];
    command = sprintf("python %s -o %s -g 1 -t %d -p %d -w %d -c %d -v %d -W %s -F %d -V 0", pyscriptloc, vhdlfilefolder, nof_taps, nof_bands, wb_factor, coef_dat_w, vendor, win, fwidth);
    [status,cmdout] = system(command); %coefficient files will be generated at filepath/hex/
    
    if(status ~= 0)
        error("Filter coefficients not correctly generated by fil_ppf_create.py");
    end
    
    %Update fil_pkg.vhd:
    coef_filepath_stem = strtrim(cmdout);
    updatepkg(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, coef_dat_w, nof_taps, wb_factor, coef_filepath_stem);
end

function chararr = mknprts(wb_factor)
    chararr = strings(2*wb_factor,0);
    indatchar = "in_dat_%c    : in std_logic_vector(c_fil_in_dat_w-1 DOWNTO 0);";
    outdatchar = "out_dat_%c   : out std_logic_vector(c_fil_out_dat_w -1 DOWNTO 0);";
    i=1;
    for j=0:1:wb_factor-1
        jj = int2str(j);
        chararr(i,1)=sprintf(indatchar,jj);
        i=i+1;
        if (j~= wb_factor -1)
            chararr(i,1)=sprintf(outdatchar,jj);
        else
            chararr(i,1)=sprintf(strip(outdatchar,';'),jj);
        end
        i=i+1;
    end
end

function achararr = mkarch(wb_factor)
    achararr = strings(2*wb_factor,0);
    imap_c = "in_dat_arr(%c) <= in_dat_%c;";
    omap_c = "out_dat_%c <= out_dat_arr(%c);";
    l=1;
    for m=0:1:wb_factor-1
        mm = int2str(m);
        achararr(l,1) = sprintf(imap_c,mm,mm);
        l=l+1;
        achararr(l,1) = sprintf(omap_c,mm,mm);
        l=l+1;
    end
end

function updatepkg(filepathscript, vhdlfilefolder, in_dat_w, out_dat_w, coef_dat_w, nof_taps, wb_factor, coef_filepath_stem)
    insertloc = 7;
    vhdlgenfileloc = [filepathscript '/../../casper_filter/fil_pkg.vhd'];
    pkgdest = [vhdlfilefolder '/fil_pkg.vhd'];

    lineone = sprintf("CONSTANT c_fil_in_dat_w : natural := %d;",in_dat_w);
    linetwo = sprintf("CONSTANT c_fil_out_dat_w : natural := %d;", out_dat_w);
    linethree = sprintf("CONSTANT c_fil_coef_dat_w : natural :=%d;",coef_dat_w);
    linefour = sprintf("CONSTANT c_coefs_file : string := ""%s"";", coef_filepath_stem);
    fid = fopen(vhdlgenfileloc,'r');
    if fid==-1
        error("Cannot open vhdl pkg file");
    end
    lines = textscan(fid,'%s', 'delimiter','\n','CollectOutput',true);
    lines = lines{1};
    fclose(fid);

    fid=fopen(pkgdest,'w');
    for jj = 1:insertloc
        fprintf(fid,'%s\n',lines{jj} );
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
