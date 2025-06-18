function [partial_delay_prog_file, variable_mux_file] = partial_delay_prog_code_gen(nof_inputs, bit_width)
    %Locate where this matlab script is
    filepathscript = fileparts(which('partial_delay_prog_code_gen'));
    %where the top vhdl file will be generated
    vhdlfilefolder = fullfile(fileparts(which(bdroot)), '/tmp_dspdevel');
    if ~exist(vhdlfilefolder, 'dir')
        mkdir(vhdlfilefolder)
    end
    %and what it will be named
    partial_delay_prog_file = fullfile(vhdlfilefolder,[bdroot '_partial_delay_prog_top.vhd']);
    upperlines = [
        "library ieee, common_pkg_lib, casper_reorder_lib, casper_delay_lib;"
        "use ieee.std_logic_1164.all;"
        "use ieee.numeric_std.all;"
        "use common_pkg_lib.common_pkg.all;"
        "use casper_reorder_lib.variable_mux_pkg.all;"
        "entity partial_delay_prog_top is"
        "    generic("
        "        g_async       : boolean := FALSE;"
        "        g_num_ports   : integer := 2;"
        "        g_mux_latency : natural := 4"
        "    );"
        "    port("
        "        clk   : in  std_logic;"
        "        ce    : in  std_logic;"
        "        en    : in  std_logic := '1';"
        "        delay : in  std_logic_vector;"
    ];
    midlines = [
    "    );"
    "end entity partial_delay_prog_top;"
    ""
    "architecture RTL of partial_delay_prog_top is"
    "    signal s_din : t_mux_data_array(g_num_ports - 1 downto 0);"
    "    signal s_dout : t_mux_data_array(g_num_ports - 1 downto 0);"
    "begin"
    "    partial_delay_prog_inst : entity work.partial_delay_prog"
    "        generic map("
    "            g_async       => g_async,"
    "            g_num_ports   => g_num_ports,"
    "            g_mux_latency => g_mux_latency"
    "        )"
    "        port map("
    "            clk   => clk,"
    "            ce    => ce,"
    "            en    => en,"
    "            delay => delay,"
    "            din   => s_din,"
    "            dout  => s_dout"
    "        );"
    ];
    lowerlines = [
    "end architecture RTL;"
    ];

    %create function that will generate the din and dout ports of the entity
    function ports_arr = mknprts(nof_inputs)
        ports_arr = strings(nof_inputs*2,0);
        inport_str = "  din_%d : in std_logic_vector(c_mux_data_width-1 downto 0);";
        outport_str = "  dout_%d : out std_logic_vector(c_mux_data_width-1 downto 0);";
        for i = 1:nof_inputs
            ports_arr(i) = sprintf(inport_str, i);
            if (i ~= nof_inputs)
                ports_arr(i+nof_inputs) = sprintf(outport_str, i);
            else
                ports_arr(i+nof_inputs) = sprintf(strip(outport_str,';'), i);
            end
        end
    end

    function sig_arr = mknassignments(nof_inputs)
        sig_arr = strings(nof_inputs*2,0);
        inport_str = "  s_din(%d) <= din_%d;";
        outport_str = "  dout_%d <= s_dout(%d);";
        for i = 1:nof_inputs
            sig_arr(i) = sprintf(inport_str, i-1, i);
            sig_arr(i+nof_inputs) = sprintf(outport_str, i, i-1);

        end
    end

    Vfile = fopen(partial_delay_prog_file,'w');
    if(Vfile == -1)
        error("Cannot open vhdl file");
    end

    fprintf(Vfile,'%s\n',upperlines{:});
    ports = mknprts(nof_inputs);
    fprintf(Vfile,'%s\n',ports{:});

    fprintf(Vfile,'%s\n',midlines{:});
    assignments = mknassignments(nof_inputs);
    fprintf(Vfile,'%s\n',assignments{:});

    fprintf(Vfile,'%s\n',lowerlines{:});
    fclose(Vfile);

    %in addition, relative to the script location, we need to edit ../../casper_reorder/variable_mux.vhd. To vhdlfilefolder we write a copy of this with the package edited
    %Load in file:
    reorderfile = fullfile(filepathscript, '../../casper_reorder/variable_mux.vhd');
    variable_mux_file = fullfile(vhdlfilefolder, 'variable_mux.vhd');
    reorderfilecopyfile = fopen(variable_mux_file, 'w');
    if(reorderfilecopyfile == -1)
        error("Cannot open reorder file");
    end
    %read in the file
    reorderfilefile = fopen(reorderfile, 'r');
    if(reorderfilefile == -1)
        error("Cannot open reorder file");
    end
    while ~feof(reorderfilefile)
        line = fgetl(reorderfilefile);
        if contains(line, "    CONSTANT c_mux_data_width : integer :=")
            fprintf(reorderfilecopyfile, sprintf("    CONSTANT c_mux_data_width : integer := %d;\n", bit_width));
        else
            fprintf(reorderfilecopyfile, "%s\n", line);
        end
    end
    fclose(reorderfilefile);
end