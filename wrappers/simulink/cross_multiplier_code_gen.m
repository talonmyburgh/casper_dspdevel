function vhdlfile = cross_multiplier_code_gen(number_of_streams, number_of_aggregations, in_bit_w, out_bit_w)
    %gather all the string arrays required to write full file:
    filepathscript = fileparts(which('cross_multiplier_code_gen'));                 %get the filepath of this script (and thereby all scripts needed)
    %where the top vhdl file will be generated
    vhdlfilefolder = [fileparts(which(bdroot)) '/tmp_dspdevel'];
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    vhdlfile = fullfile(vhdlfilefolder, [bdroot '_cross_mult_top.vhd']);              %filename for vhd file

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%upperdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    upperlines = [
    "library ieee, common_pkg_lib, casper_multiplier_lib, cross_multiplier_lib;"
    "use ieee.std_logic_1164.all;"
    "use ieee.numeric_std.all;"
    "use common_pkg_lib.common_pkg.all;"
    "use work.correlator_pkg.all;"
    ""
    "entity cross_multiplier_top is"
    "    generic("
    "        g_use_gauss        : BOOLEAN := FALSE;"
    "        g_use_dsp          : BOOLEAN := TRUE;"
    "        g_pipeline_input   : NATURAL := 1; --! 0 or 1"
    "        g_pipeline_product : NATURAL := 1; --! 0 or 1"
    "        g_pipeline_adder   : NATURAL := 1; --! 0 or 1"
    "        g_pipeline_round   : NATURAL := 1; --! 0 or 1"
    "        g_pipeline_output  : NATURAL := 0; --! >= 0"
    "        ovflw_behav        : BOOLEAN := FALSE;"
    "        quant_behav        : NATURAL := 0"
    "    );"
    "    port("
    "        clk  : in  std_logic;"
    "        ce   : in  std_logic;"
    "        sync_in : in std_logic;"
    "        sync_out : out std_logic;"
    ];

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%lowerdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    lowerlines = [
        ");"
        "architecture RTL of cross_multiplier_top is"
        "SIGNAL s_din : s_cross_mult_din;"
        "SIGNAL s_dout : s_cross_mult_out;"
    "begin"
    "  u_cross_mult : entity cross_multiplier_lib.cross_multiplier"
    "  generic map ("
    "   g_use_gauss => g_use_gauss"
    "   g_use_dsp => g_use_dsp"
    "   g_pipeline_input => g_pipeline_input"
    "   g_pipeline_product => g_pipeline_product"
    "   g_pipeline_adder => g_pipeline_adder"
    "   g_pipeline_round => g_pipeline_round"
    "   g_pipeline_output => g_pipeline_output"
    "   ovflw_behav => ovflw_behav"
    "   quant_behav => quant_behav"
    "  )"
    "  port map ("
    "    clk => clk,"
    "    ce => ce,"
    "    sync_in => sync_in,"
    "    sync_out => sync_out,"
    "    din => din,"
    "    dout => dout"
    "  );"
    ];

    portdec = join(mknprts(number_of_streams),'\n');
    archdec = join(mknarch(number_of_streams),'\n');
    
    Vfile = fopen(vhdlfile,'w');
    if(Vfile == -1)
        error("Cannot open vhdl file");
    end

    fprintf(Vfile,'%s\n',upperlines{:});
    fprintf(Vfile,portdec{:});
    fprintf(Vfile,'%s\n',lowerlines{:});
    fprintf(Vfile,archdec{:});
    fprintf(Vfile,"\nend architecture RTL;");
    fclose(Vfile);

    %update generics package
    updatepkgs(filepathscript, vhdlfilefolder, number_of_streams, number_of_aggregations,in_bit_w, out_bit_w);    
end

function chararr = mknprts(number_of_streams)
    nof_outputs = ((number_of_streams + 1) * number_of_streams)/ 2;
    chararr = strings(number_of_streams + nof_outputs,0);
    din = "din_%d : in STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_input_cbit_width) - 1 downto 0);";
    dout = "dout_%d : out STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_output_cbit_width) - 1 downto 0);";
    i=1;
    for s = 0:1:number_of_streams-1
        chararr(i,1) = sprintf(din,s,s);
        i=i+1;
    end
    for o = 0:1:nof_outputs-1
        if o ~= nof_outputs-1
            chararr(i,1) = sprintf(dout,o,o);
        else
            chararr(i,1) = sprintf(strip(dout,';'),o,o);
        end
        i=i+1;
    end
end

function chararr = mknarch(number_of_streams)
    nof_outputs = ((number_of_streams + 1) * number_of_streams)/ 2;
    chararr = strings(number_of_streams + nof_outputs,0);
    din = "s_din(%d) <= din_%d;";
    dout = "dout_%d <= s_dout(%d);";
    i=1;
    for s = 0:1:number_of_streams-1
        chararr(i,1) = sprintf(din,s,s);
        i=i+1;
    end
    for o = 0:1:nof_outputs-1
        chararr(i,1) = sprintf(dout,o,o);
        i=i+1;
    end
end

function updatepkgs(filepathscript, vhdlfilefolder, nof_streams, nof_aggregations, in_dat_w, out_dat_w)
    insertloc = 5;
    pkgsource = [filepathscript '/../../casper_correlator/correlator_pkg.vhd'];
    pkgdest = [vhdlfilefolder '/correlator_pkg.vhd'];
    lineone = sprintf(  "CONSTANT c_cross_mult_nof_input_streams : NATURAL := %d;",nof_streams);
    linetwo = sprintf(  "CONSTANT c_cross_mult_aggregation_per_stream : NATURAL := %d;",nof_aggregations);
    linethree = sprintf("CONSTANT c_cross_mult_input_bit_width : NATURAL := %d;",in_dat_w);
    linefour = sprintf("CONSTANT c_cross_mult_output_bit_width : NATURAL := %d;",out_dat_w);
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
    fprintf(fid,'%s\n',linefour);
    for jj = insertloc+5 : length(lines)
        fprintf( fid, '%s\n', lines{jj} );
    end
    fclose(fid);
end