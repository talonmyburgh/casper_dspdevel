-- A VHDL implementation of a variable mux block. Adaptation of mux.vhd to allow for a variable number of inputs.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

PACKAGE variable_mux_pkg IS
    CONSTANT c_mux_data_width : integer := 8;
    TYPE t_mux_data_array IS ARRAY (NATURAL range <>) OF std_logic_vector(c_mux_data_width - 1 downto 0);
END PACKAGE variable_mux_pkg;

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE work.variable_mux_pkg.ALL;

entity variable_mux is
    generic(
        g_async       : BOOLEAN := FALSE;
        g_num_ports   : integer := 2;   -- Number of i_data ports
        g_mux_latency : integer := 4    -- Maximum latency
    );
    port(
        clk    : IN  std_logic := '0';
        ce     : IN  std_logic := '1';
        en     : IN  std_logic := '1';
        i_sel  : IN  std_logic_vector;
        i_data : IN  t_mux_data_array(g_num_ports - 1 downto 0);
        o_data : out std_logic_vector
    );
end variable_mux;

architecture rtl of variable_mux is
    signal s_int_i_sel           : integer range 0 to g_num_ports - 1;
    type shift_reg_type is array (NATURAL range <>) OF std_logic_vector(c_mux_data_width - 1 downto 0);
    signal shift_reg             : shift_reg_type(0 to g_mux_latency - 1) := (others => (others => '0'));
    signal shift_reg_passthrough : std_logic_vector(c_mux_data_width - 1 downto 0) := (others => '0');
begin
    s_int_i_sel <= TO_UINT(i_sel);

    gen_passthrough : IF g_mux_latency < 3 generate
        --------------------------------------------------------
        -- Asynchronous operation
        --------------------------------------------------------
        async : IF g_async = TRUE GENERATE
            async_process : PROCESS(en)
            begin
                if rising_edge(en) THEN
                    shift_reg_passthrough <= i_data(s_int_i_sel);
                    o_data                <= shift_reg_passthrough;
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
                    shift_reg_passthrough <= i_data(s_int_i_sel);
                    o_data                <= shift_reg_passthrough;
                end if;
            end PROCESS;
        END GENERATE;
    END GENERATE;

    gen_delay : IF g_mux_latency > 2 generate
        --------------------------------------------------------
        -- Asynchronous operation
        --------------------------------------------------------
        async : IF g_async = TRUE GENERATE
            async_process : PROCESS(en)
            begin
                if rising_edge(en) THEN
                    shift_reg(0) <= i_data(s_int_i_sel);
                    for i in 1 to g_mux_latency loop
                        shift_reg(i) <= shift_reg(i - 1);
                    end loop;
                    o_data       <= shift_reg(g_mux_latency - 1);
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
                    shift_reg(0) <= i_data(s_int_i_sel);
                    for i in 1 to g_mux_latency loop
                        shift_reg(i) <= shift_reg(i - 1);
                    end loop;
                    o_data       <= shift_reg(g_mux_latency - 1);
                end if;
            end PROCESS;
        END GENERATE;
    END GENERATE;

end architecture;
