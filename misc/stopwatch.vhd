-- A VHDL implementation of the CASPER stopwatch block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, common_pkg_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.all;

entity stopwatch is
    port(
        clk   : IN  std_logic;
        ce    : IN  std_logic;
        stop  : IN  std_logic;
        start : IN  std_logic;
        reset : IN  std_logic;
        count : OUT std_logic_vector(32 - 1 DOWNTO 0)
    );
end stopwatch;

architecture rtl of stopwatch is
    SIGNAL s_register_stop           : std_logic                         := '0';
    SIGNAL s_register_start          : std_logic                         := '0';
    SIGNAL s_reset_or_start          : std_logic                         := '0';
    SIGNAL s_and_register_start_stop : std_logic                         := '0';
    SIGNAL s_reg_din                 : std_logic;
    SIGNAL s_count                   : std_logic_vector(32 - 1 DOWNTO 0) := (others => '0');
begin
    s_reg_din                 <= '1';
    s_reset_or_start          <= reset OR start;
    s_and_register_start_stop <= s_register_start AND s_register_stop;
    count                     <= s_count;

    proc_start : process(clk, reset)
    begin
        if reset = '1' then
            s_register_start <= '0';
        else
            if rising_edge(clk) and ce = '1' and start = '1' then
                s_register_start <= s_reg_din;
            end if;
        end if;
    end process;

    proc_stop : process(clk, stop)
    begin
        if stop = '1' then
            s_register_stop <= '0';
        else
            if rising_edge(clk) and ce = '1' then
                if s_reset_or_start = '1' then
                    s_register_stop <= s_reg_din;
                end if;
            end if;
        end if;
    end process;

    common_counter_inst : entity casper_counter_lib.common_counter
        generic map(
            g_latency => 1,
            g_init    => 0,
            g_width   => 32
        )
        port map(
            rst    => reset,
            clk    => clk,
            clken  => ce,
            cnt_en => s_and_register_start_stop,
            count  => s_count
        );
end architecture;
