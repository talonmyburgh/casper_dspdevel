-- A VHDL implementation of a variable mux block. Adaptation of mux.vhd to allow for a variable number of inputs.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

PACKAGE variable_mux_pkg IS
    CONSTANT c_mux_data_width : integer := 8;
    TYPE t_mux_data_array IS ARRAY (natural range <>) OF std_logic_vector(c_mux_data_width - 1 downto 0);
END PACKAGE variable_mux_pkg;

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE work.variable_mux_pkg.ALL;

entity variable_mux is
    generic(
        g_async     : BOOLEAN := FALSE;
        g_num_ports : integer := 2      -- Number of i_data ports
    );
    port(
        clk    : IN  std_logic := '0';
        ce     : IN  std_logic := '1';
        en     : IN  std_logic := '1';
        i_sel  : IN  std_logic_vector(g_num_ports - 1 downto 0);
        i_data : IN  t_mux_data_array(g_num_ports - 1 downto 0);
        o_data : out std_logic_vector
    );
end variable_mux;

architecture rtl of variable_mux is
    signal s_int_i_sel : integer range 0 to g_num_ports - 1;
begin
    s_int_i_sel <= to_integer(unsigned(i_sel));
    --------------------------------------------------------
    -- Asynchronous operation
    --------------------------------------------------------
    async : IF g_async = TRUE GENERATE
        sync_process : PROCESS(en)
        begin
            if rising_edge(en) THEN
                o_data <= i_data(s_int_i_sel);
            end if;
        end PROCESS;
    END GENERATE;

    --------------------------------------------------------
    -- Synchronous operation
    --------------------------------------------------------
    sync : IF g_async = FALSE GENERATE
    BEGIN
        sync_process : PROCESS(clk)
        begin
            if rising_edge(clk) and ce = '1' THEN
                o_data <= i_data(s_int_i_sel);
            end if;
        end PROCESS;
    END GENERATE;

end architecture;
