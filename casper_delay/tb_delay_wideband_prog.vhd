-- Testbench for partial_delay_prog

library ieee, common_pkg_lib, casper_reorder_lib, casper_delay_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE common_pkg_lib.common_pkg.all;
USE common_pkg_lib.tb_common_pkg.all;
USE casper_delay_lib.delay_wideband_prog_pkg.all;

entity tb_delay_wideband_prog is
    generic(
        g_max_delay_bits          : NATURAL := 8;
        g_simultaneous_input_bits : NATURAL := 2;
        g_true_dual_port          : BOOLEAN := TRUE;
        g_delay_cycles            : NATURAL := 2;
        g_input_file_nof_lines    : NATURAL := 500;
        g_input_file              : STRING  := "C:\Users\mybur\Repos\CASPER\dspdevel_designs\casper_dspdevel\casper_delay\delay_input_4_1.dat";
        g_output_file_nof_lines   : NATURAL := 502;
        g_output_file             : STRING  := "C:\Users\mybur\Repos\CASPER\dspdevel_designs\casper_dspdevel\casper_delay\delay_output_4_1.dat"
    );
    port(
        o_clk       : out std_logic;
        o_tb_end    : out std_logic;
        o_test_msg  : out STRING(1 to 80);
        o_test_pass : out BOOLEAN
    );
end entity tb_delay_wideband_prog;

architecture tb_arch of tb_delay_wideband_prog is
    constant c_nof_inputs             : natural                                                := 2 ** g_simultaneous_input_bits;
    constant c_delimeter              : character                                              := ',';
    SIGNAL s_data_input_integer_array : t_nat_integer_matrix(0 TO g_input_file_nof_lines - 1, 0 TO c_nof_inputs - 1);
    SIGNAL s_data_output_integer_array_golden_matrix : t_nat_integer_matrix(0 TO g_output_file_nof_lines - 1, 0 TO c_nof_inputs - 1) := (others => (others => 0));
    SIGNAL s_data_output_integer_array_scope : t_nat_integer_arr(0 TO c_nof_inputs - 1):= (others => 0);
    SIGNAL s_data_output_integer_array_golden : t_nat_integer_arr(0 TO c_nof_inputs - 1) := (others => 0);
    SIGNAL s_data_output_integer_array_diff : t_nat_integer_arr(0 TO c_nof_inputs - 1) := (others => 0);
    SIGNAL s_data_din_slv             : t_wideband_delay_prog_inout_bus(0 TO c_nof_inputs - 1) := (others => (others => '0'));
    SIGNAL s_delay_wb_prog_dout       : t_wideband_delay_prog_inout_bus(0 TO c_nof_inputs - 1);
    SIGNAL s_dvalid                   : std_logic;
    CONSTANT c_clk_period             : TIME                                                   := 10 ns;
    SIGNAL clk                        : std_logic                                              := '0';
    SIGNAL ce                         : std_logic                                              := '1';
    SIGNAL en                         : std_logic                                              := '0';
    SIGNAL s_sync                     : std_logic                                              := '0';
    SIGNAL s_sync_out                 : std_logic                                              := '1';
    SIGNAL tb_end                     : STD_LOGIC                                              := '0';
    CONSTANT c_delay_bitwidth         : NATURAL                                                := ceil_log2(g_delay_cycles);
    SIGNAL s_delay                    : STD_LOGIC_VECTOR(g_max_delay_bits - 1 DOWNTO 0)        := TO_UVEC(g_delay_cycles, g_max_delay_bits);
    SIGNAL s_ld_delay                 : STD_LOGIC                                              := '0';
begin

    clk      <= NOT clk OR tb_end AFTER c_clk_period / 2;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    -----------------------------------------------
    -- Read input file and package into s_axis_data
    -----------------------------------------------
    p_read_input : process
        VARIABLE v_data_input_array : t_nat_integer_matrix(0 TO g_input_file_nof_lines - 1, 0 TO c_nof_inputs - 1);
        VARIABLE v_slv              : t_wideband_delay_prog_inout_bus(0 TO c_nof_inputs - 1);
        VARIABLE v_cnt              : NATURAL := 0;
    begin
        csv_open_and_read_file(g_input_file, v_data_input_array, g_input_file_nof_lines, c_delimeter);
        wait for 10 * c_clk_period;
        wait until rising_edge(clk);
        s_data_input_integer_array <= v_data_input_array;
        en                         <= '1';
        s_sync                     <= '1';
        s_ld_delay                 <= '1';
        wait until rising_edge(clk);
        FOR J in 0 to g_input_file_nof_lines - 1 loop --serial
            v_slv := (others => (others => '0'));
            FOR I in 0 to c_nof_inputs - 1 loop --parallel 
                v_slv(I) := std_logic_vector(to_unsigned(s_data_input_integer_array(J, I), c_delay_wideband_prog_bit_width));
            end loop;
            s_data_din_slv <= v_slv;
            v_cnt          := v_cnt + 1;
            wait FOR c_clk_period;      -- Adjust timing as needed
        end loop;
    end process p_read_input;

    -----------------------------------------------
    -- Read output file for comparison
    -----------------------------------------------
    p_read_output : process
        VARIABLE v_data_output_integer_array_golden : t_nat_integer_matrix(0 TO g_output_file_nof_lines - 1, 0 TO c_nof_inputs - 1);
    begin
        csv_open_and_read_file(g_output_file, v_data_output_integer_array_golden, g_output_file_nof_lines, c_delimeter);
        wait for c_clk_period;
        s_data_output_integer_array_golden_matrix <= v_data_output_integer_array_golden;   
    end process p_read_output;

    -----------------------------------------------
    -- Compare output with golden output
    -----------------------------------------------
    p_compare_output : process(clk)
        VARIABLE v_data_output_integer_array : t_nat_integer_arr(0 TO c_nof_inputs - 1) := (others => 0);
        VARIABLE v_cnt : NATURAL := 0;
        VARIABLE v_test_pass : BOOLEAN := TRUE;
    begin
        if rising_edge(clk) and s_sync_out = '1' then
            FOR I in 0 to c_nof_inputs - 1 loop
                IF s_data_output_integer_array_diff(I) = 0 then
                    v_test_pass := v_test_pass and TRUE;
                ELSE
                    v_test_pass := v_test_pass and FALSE;
                end if;
                v_data_output_integer_array(I) := TO_SINT(s_delay_wb_prog_dout(I));
                s_data_output_integer_array_golden(I) <= s_data_output_integer_array_golden_matrix(v_cnt,I);
                s_data_output_integer_array_diff(I) <= s_data_output_integer_array_scope(I) - s_data_output_integer_array_golden(I);
                -- v_test_pass :=v_test_pass or s_data_output_integer_array_golden(I,0)  = s_data_output_integer_array(I,0);
            END LOOP;
            v_cnt := v_cnt + 1;
        end if;
        if v_test_pass then
            report "Test Passed" severity note;
        else
            report "Test Failed" severity failure;
        end if;
        s_data_output_integer_array_scope <= v_data_output_integer_array;
        o_test_pass <= TRUE;
       
    end process p_compare_output;

    ---------------------------------------------------------------------
    -- PARTIAL DELAY PROG module
    ---------------------------------------------------------------------
    delay_wideband_prog_inst : entity work.delay_wideband_prog
        generic map(
            g_max_delay_bits          => g_max_delay_bits,
            g_simultaneous_input_bits => g_simultaneous_input_bits,
            g_bram_latency            => 2,
            g_true_dual_port          => g_true_dual_port,
            g_async                   => FALSE
        )
        port map(
            clk      => clk,
            ce       => ce,
            sync     => s_sync,
            en       => en,
            delay    => s_delay,
            ld_delay => s_ld_delay,
            data_in  => s_data_din_slv,
            sync_out => s_sync_out,
            data_out => s_delay_wb_prog_dout,
            dvalid   => s_dvalid
        );
end architecture tb_arch;
