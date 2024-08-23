-- A VHDL implementation of a partial programmable delay block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

library ieee, common_pkg_lib, casper_reorder_lib, casper_delay_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_reorder_lib.variable_mux_pkg.all;

entity partial_delay_prog is
    generic(
        g_async       : boolean := FALSE;
        g_num_ports   : integer := 2;
        g_mux_latency : natural := 4
    );
    port(
        clk   : in  std_logic;
        ce    : in  std_logic;
        en    : in  std_logic := '1';
        delay : in  std_logic_vector;
        din   : in  t_mux_data_array(g_num_ports - 1 downto 0);
        dout  : out t_mux_data_array(g_num_ports - 1 downto 0)
    );
end entity partial_delay_prog;

architecture RTL of partial_delay_prog is

    constant c_mux_latency : natural := sel_a_b(g_mux_latency > 0, g_mux_latency - 1, 0); -- overall mux latency must always be at least 1

    signal s_delay_din : t_mux_data_array(g_num_ports - 1 downto 0);
    signal s_mux_din   : t_mux_data_array(g_num_ports * g_num_ports - 1 downto 0); -- all of the input data ports for the mux's
    signal s_mux_dout  : t_mux_data_array(g_num_ports - 1 downto 0); -- all of the output data ports for the mux's

begin

    -- REGISTER din for 1 clock:
    register_din : process(clk) is
    begin
        if rising_edge(clk) and ce = '1' then
            s_delay_din <= din;
        end if;
    end process register_din;

    create_muxs : for i in 0 to g_num_ports - 1 generate
        variable_mux_inst : entity casper_reorder_lib.variable_mux
            generic map(
                g_async       => g_async,
                g_num_ports   => g_num_ports,
                g_mux_latency => c_mux_latency - 1 --one goes to the 
            )
            port map(
                clk    => clk,
                ce     => ce,
                en     => en,
                i_sel  => delay,
                i_data => s_mux_din(i * g_num_ports to (i + 1) * g_num_ports - 1), -- all of the input data ports for the mux's
                o_data => s_mux_dout(i)
            );

        s_mux_din(i * g_num_ports) <= s_delay_din(i);
    end generate create_muxs;

    -- Connect the input data ports to the mux's bus interface:
    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                for j in 0 to g_num_ports - 1 loop
                    for k in 1 to g_num_ports - 1 loop
                        if j + k <= g_num_ports - 1 then
                            s_mux_din(j * g_num_ports + k) <= s_delay_din(j + k); --delayed din
                        else
                            s_mux_din(j * g_num_ports + k) <= din(j + k - g_num_ports); --not delayed din
                        end if;
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    dout <= s_mux_dout;

end architecture RTL;
