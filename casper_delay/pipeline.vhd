-- A VHDL implementation of the pipeline block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY pipeline IS
    GENERIC(
        g_pipeline : NATURAL := 1       --! 0 for wires, > 0 for registers, 
    );
    PORT(
        clk     : IN  STD_LOGIC;        --! Input clock signal
        ce      : IN  STD_LOGIC := '1'; --! Enable clock
        in_dat  : IN  STD_LOGIC_VECTOR; --! Input data
        out_dat : OUT STD_LOGIC_VECTOR  --! Output data
    );
END pipeline;

ARCHITECTURE rtl OF pipeline IS

    CONSTANT c_bit_width : NATURAL := in_dat'LENGTH;

    CONSTANT c_reset_value : STD_LOGIC_VECTOR(in_dat'RANGE) := TO_SVEC(0, c_bit_width);

    TYPE t_out_dat IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(in_dat'RANGE);

    SIGNAL out_dat_p : t_out_dat(0 TO g_pipeline) := (OTHERS => c_reset_value);

BEGIN

    gen_pipe_n : IF g_pipeline > 0 GENERATE
        p_clk : PROCESS(clk)
        BEGIN
            IF rising_edge(clk) THEN
                IF ce = '1' THEN
                    out_dat_p(1 TO g_pipeline) <= out_dat_p(0 TO g_pipeline - 1);
                END IF;
            END IF;
        END PROCESS;
    END GENERATE;

    out_dat_p(0) <= in_dat;

    out_dat <= out_dat_p(g_pipeline);
END rtl;
