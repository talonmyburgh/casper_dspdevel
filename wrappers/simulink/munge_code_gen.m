function vhdlfile = munge_code_gen(number_of_divisions, division_size_bits, packing_order_string)
    %gather all the string arrays required to write full file:
    filepathscript = fileparts(which('munge_code_gen'));                 %get the filepath of this script (and thereby all scripts needed)
    %where the top vhdl file will be generated
    vhdlfilefolder = [fileparts(which(bdroot)) '/tmp_dspdevel'];
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    vhdlfile = fullfile(vhdlfilefolder, [bdroot '_munge_static.vhd']);              %filename for vhd file

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%upperdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    upperlines = [
    "LIBRARY IEEE, common_pkg_lib, casper_flow_control_lib;"
    "USE IEEE.std_logic_1164.all;"
    "USE common_pkg_lib.common_pkg.all;"
    "ENTITY munge_static is"
    "  port ("
    "    clk   : in std_logic := '1';"
    "    ce    : in std_logic := '1';"
    "    din   : in std_logic_vector;"
    "    dout  : out std_logic_vector"
    "  );"
    "end ENTITY;"
    "ARCHITECTURE rtl of munge_static is"
    ];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%lowerdec%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    lowerlines = [
    "begin"
    "  u_munge : entity casper_flow_control_lib.munge"
    "  generic map ("
    "    g_number_of_divisions => c_number_of_divisions,"
    "    g_division_size_bits => c_division_size_bits,"
    "    g_packing_order => c_packing_order"
    "  )"
    "  port map ("
    "    clk => clk,"
    "    ce => ce,"
    "    din => din,"
    "    dout => dout"
    "  );"
    "end ARCHITECTURE;"
    ];
    
    Vfile = fopen(vhdlfile,'w');
    if(Vfile == -1)
        error("Cannot open vhdl file");
    end

    fprintf(Vfile,'%s\n',upperlines{:});
    fprintf(Vfile,"\tCONSTANT c_number_of_divisions : NATURAL := %d;\n", number_of_divisions);
    fprintf(Vfile,"\tCONSTANT c_division_size_bits : NATURAL := %d;\n", division_size_bits);
    fprintf(Vfile,"\tCONSTANT c_packing_order : t_natural_arr(0 to c_number_of_divisions-1) := (\n");
    fprintf(Vfile,"\t\t%s\n",packing_order_string);
    fprintf(Vfile,"\t);\n");
    fprintf(Vfile,'%s\n',lowerlines{:});
    fclose(Vfile);
end
