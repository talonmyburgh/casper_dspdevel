-- A VHDL implementation of the CASPER sample_and_hold.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

entity sample_and_hold is
    generic(
        g_period : NATURAL := 1024
    );
    port(
        clk     : IN  std_logic;
        ce      : IN  std_logic;
        in_sig  : IN  std_logic_vector;
        sync    : IN  std_logic;
        out_sig : OUT std_logic_vector
    );
END sample_and_hold;

architecture rtl of sample_and_hold is
    CONSTANT c_logperiod : NATURAL          := ceil_log2(g_period);
    CONSTANT c_b         : std_logic_vector := TO_SVEC(g_period, c_logperiod);

    SIGNAL s_or_in  : std_logic;
    SIGNAL s_en     : std_logic;
    SIGNAL s_q      : std_logic_vector(in_sig'RANGE) := (others => '0');
    SIGNAL s_or_out : std_logic;
    SIGNAL s_a      : std_logic_vector(c_logperiod - 1 DOWNTO 0);
begin

    --------------------------------------------------------------
    -- counter
    --------------------------------------------------------------
    enable_counter : entity casper_counter_lib.common_counter
        generic map(
            g_width => c_logperiod
        )
        port map(
            clk     => clk,
            clken   => ce,
            cnt_clr => s_or_out,
            count   => s_a
        );

    --------------------------------------------------------------
    -- bit of logic
    --------------------------------------------------------------
    s_or_in <= '1' WHEN s_a >= c_b ELSE
               '0';

    s_or_out <= s_or_in or sync;

    --------------------------------------------------------------
    -- one clock cycle delay
    --------------------------------------------------------------
    one_clk_delay : process(clk)
    BEGIN
        IF rising_edge(clk) and ce = '1' THEN
            s_en <= s_or_out;
        END IF;
    END PROCESS;

    --------------------------------------------------------------
    -- register the input until enable is set
    --------------------------------------------------------------
    register_input : process(clk, s_en)
    BEGIN
        IF s_en = '1' THEN
            IF rising_edge(clk) and ce = '1' THEN
                s_q <= in_sig;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------
    -- output
    --------------------------------------------------------------

    out_sig <= s_q;

END architecture;
