-- A VHDL implementation of a simple delay block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity delay_simple is
    generic (
        g_delay : NATURAL := 1;
        g_initial_values : std_logic := '0'
    );
    port (
        clk : IN std_logic := '0';
        ce :  IN std_logic := '0';
        i_data : IN std_logic_vector;
        o_data : out std_logic_vector
    );
end delay_simple;

architecture rtl of delay_simple is
    TYPE t_delay_slv_arr IS ARRAY (0 to g_delay-1) OF STD_LOGIC_VECTOR(i_data'RANGE);
    SIGNAL s_delays : t_delay_slv_arr := (OTHERS => (OTHERS => g_initial_values));
begin
    o_data <= s_delays(g_delay-1);

    --------------------------------------------------------
    -- Synchronous operation
    --------------------------------------------------------
    sync_process: PROCESS (clk, ce)
    begin
        if rising_edge(clk) and ce='1' THEN
            FOR latency in g_delay-1 downto 1 LOOP
                s_delays(latency) <= s_delays(latency-1);
            END LOOP;
            s_delays(0) <= i_data;
        end if;
    end PROCESS;

end architecture;

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity delay_simple_sl is
    generic (
        g_delay : NATURAL := 1;
        g_initial_values : std_logic := '0'
    );
    port (
        clk : IN std_logic := '0';
        ce :  IN std_logic := '0';
        i_data : IN std_logic;
        o_data : out std_logic
    );
end delay_simple_sl;

architecture rtl of delay_simple_sl is
    SIGNAL s_in, s_out : STD_LOGIC_VECTOR(0 to 0);
begin
    s_in(0) <= i_data;
    o_data <= s_out(0);

    u_sync_delay : entity work.delay_simple
        generic map (
            g_delay => g_delay,
            g_initial_values => g_initial_values
        )
        port map (
        clk => clk,
        ce => ce,
        i_data => s_in,
        o_data => s_out
    );

end architecture;