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
        g_values : t_integer_matrix(0 TO c_cross_mult_nof_input_streams - 1,0 TO c_cross_mult_aggregation_per_stream - 1):=((85, 51),(85, 51))
    );
    port(
        o_clk       : out std_logic;
        o_tb_end    : out std_logic;
        o_test_msg  : out STRING(1 to 80);
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

    function populate_din(nof_aggregation : NATURAL; nof_streams : NATURAL)
    return s_cross_mult_din IS
        VARIABLE pop_input : s_cross_mult_din;
    BEGIN
        FOR i IN 0 TO c_cross_mult_nof_input_streams - 1 LOOP
            FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 LOOP
                pop_input(i)((j+1)*c_cross_mult_input_cbit_width -1 DOWNTO j*c_cross_mult_input_cbit_width) := TO_SVEC(g_values(i,j),c_cross_mult_input_cbit_width);
            END LOOP;
        END LOOP;
        RETURN pop_input;
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
        VARIABLE v_test_vector : STD_LOGIC_VECTOR(c_cross_mult_input_bit_width -1 DOWNTO 0);
        VARIABLE v_test_pass : BOOLEAN := True;
    BEGIN
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 5 * clk_period;
        din <= populate_din(c_cross_mult_aggregation_per_stream, c_cross_mult_nof_input_streams);
        ce <= '1';
        WAIT FOR 10*clk_period;
        
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