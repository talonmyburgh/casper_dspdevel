-- A VHDL testbench for cross_multiplier.vhd.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;
USE work.correlator_pkg.all;

entity tb_cross_multiplier is
    generic(
        g_values : t_natural_matrix(0 TO c_cross_mult_nof_input_streams - 1,0 TO c_cross_mult_aggregation_per_stream - 1); --:= ((11, 27), (10, 16), (-26, 26));
        g_results : t_natural_matrix (0 TO c_cross_mult_nof_output_streams - 1, 0 TO c_cross_mult_aggregation_per_stream - 1)-- := ((247808, 225280), (137205, 204800), (124918, 75776), (51200, 163840), (61440, 524288), (196608, 73728))
    );
    port(
        o_clk       : out std_logic;
        o_tb_end    : out std_logic;
        o_test_msg  : out STRING(1 to 200);
        o_test_pass : out BOOLEAN := True
    );
end entity tb_cross_multiplier;

architecture rtl of tb_cross_multiplier is

    CONSTANT clk_period : TIME := 10 ns;
    CONSTANT c_pipeline_input : NATURAL := 1;
    CONSTANT c_pipeline_product : NATURAL := 1;
    CONSTANT c_pipeline_adder : NATURAL := 1;
    CONSTANT c_pipeline_round : NATURAL := 1; 
    CONSTANT c_pipeline_output : NATURAL := 0;

    SIGNAL clk    : STD_LOGIC        := '0';
    SIGNAL ce     : STD_LOGIC;
    SIGNAL tb_end : STD_LOGIC        := '0';
    SIGNAL din    : s_cross_mult_din := (others => (others => '0'));
    SIGNAL dout   : s_cross_mult_out := (others => (others => '0'));
    SIGNAL exp_dout : s_cross_mult_out := (others => (others => '0'));

    function populate_din
    return s_cross_mult_din IS
        VARIABLE pop_input : s_cross_mult_din;
        VARIABLE max_width : NATURAL := c_cross_mult_aggregation_per_stream * c_cross_mult_input_cbit_width;
    BEGIN
        FOR i IN 0 TO c_cross_mult_nof_input_streams - 1 LOOP
            FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 LOOP
                pop_input(i)(max_width - c_cross_mult_input_cbit_width*j - 1 DOWNTO max_width - c_cross_mult_input_cbit_width*(j+1)) := TO_UVEC(g_values(i, c_cross_mult_aggregation_per_stream-j-1),c_cross_mult_input_cbit_width);
            END LOOP;
        END LOOP;
        RETURN pop_input;
    END FUNCTION;
    
    function populate_exp_dout
    return s_cross_mult_out IS
        VARIABLE pop_output : s_cross_mult_out;
    BEGIN
        FOR i IN 0 TO c_cross_mult_nof_output_streams - 1 LOOP
            FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 LOOP
                pop_output(i)((j+1)*c_cross_mult_output_cbit_width -1 DOWNTO j*c_cross_mult_output_cbit_width) := TO_UVEC(g_results(i,j),c_cross_mult_output_cbit_width);
            END LOOP;
        END LOOP;
        RETURN pop_output;
    END FUNCTION;

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk    <= clk;
    o_tb_end <= tb_end;

    ---------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------
    p_stimuli_verify : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := True;
    BEGIN
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 5 * clk_period;
        din <= populate_din;
        exp_dout <= populate_exp_dout;
        ce <= '1';
        WAIT FOR (c_pipeline_input + c_pipeline_product + c_pipeline_adder + c_pipeline_round + c_pipeline_output + 1)*clk_period;
       FOR i IN 0 TO c_cross_mult_nof_output_streams - 1 LOOP
           v_test_pass := v_test_pass and (dout(i) = exp_dout(i));
               if not v_test_pass then
                   v_test_msg := pad("4DSP RE cmult wrong RTL result#" & integer'image(i) & ", expected: " & to_hstring(exp_dout(i)) & " but got: " & to_hstring(dout(i)), o_test_msg'length, '.');
                   o_test_msg <= v_test_msg;
                   report "Error: " & v_test_msg severity failure;
               end if;
       END LOOP;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end <= '1';
    WAIT;
    
    END PROCESS;
---------------------------------------------------------------------
-- cross multiplier module
---------------------------------------------------------------------
cross_mult : entity work.cross_multiplier
        generic map(
            g_use_gauss        => FALSE,
            g_use_dsp          => TRUE,
            g_pipeline_input   => c_pipeline_input,
            g_pipeline_product => c_pipeline_product,
            g_pipeline_adder   => c_pipeline_adder,
            g_pipeline_round   => c_pipeline_round,
            g_pipeline_output  => c_pipeline_output,
            ovflw_behav        => FALSE,
            quant_behav        => 0
        )
        port map(
            clk  => clk,
            ce   => ce,
            din  => din,
            dout => dout
        );

end architecture;