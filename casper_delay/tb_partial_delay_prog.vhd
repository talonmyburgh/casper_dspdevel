-- Testbench for partial_delay_prog

library ieee, common_pkg_lib, casper_reorder_lib;
use ieee.std_logic_1164.all;
use casper_reorder_lib.variable_mux_pkg.all;
USE common_pkg_lib.common_pkg.all;

entity tb_partial_delay_prog is
    generic(
        g_delay     : NATURAL := 2;
        g_num_ports : NATURAL := 3
    );
    port(
        o_clk       : out std_logic;
        o_tb_end    : out std_logic;
        o_test_msg  : out STRING(1 to 80);
        o_test_pass : out BOOLEAN
    );
end entity tb_partial_delay_prog;

architecture tb_arch of tb_partial_delay_prog is

    CONSTANT clk_period       : TIME                                            := 10 ns;
    SIGNAL clk                : std_logic                                       := '0';
    SIGNAL ce                 : std_logic                                       := '1';
    SIGNAL en                 : std_logic                                       := '1';
    SIGNAL tb_end             : STD_LOGIC                                       := '0';
    CONSTANT c_delay_bitwidth : NATURAL                                         := ceil_log2(g_delay);
    SIGNAL delay              : STD_LOGIC_VECTOR(c_delay_bitwidth - 1 DOWNTO 0) := TO_UVEC(g_delay, c_delay_bitwidth);
    TYPE t_mux_data_matrix IS ARRAY (NATURAL range <>) OF t_mux_data_array(g_num_ports - 1 downto 0);
    SIGNAL s_din              : t_mux_data_array(g_num_ports - 1 downto 0)      := (others => (others => '0'));
    SIGNAL s_din_matrix       : t_mux_data_matrix(0 TO g_delay)                 := (others => (others => (others => '0')));
    SIGNAL s_dout             : t_mux_data_array(g_num_ports - 1 downto 0)      := (others => (others => '0'));
    SIGNAL s_dout_matrix      : t_mux_data_matrix(0 TO g_delay)                 := (others => (others => (others => '0')));
    SIGNAL s_iteration        : NATURAL                                         := 0;
begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    ---------------------------------------------------------------------
    -- PARTIAL DELAY PROG module
    ---------------------------------------------------------------------
    partial_delay_prog_inst : entity work.partial_delay_prog
        generic map(
            g_async       => FALSE,
            g_num_ports   => g_num_ports,
            g_mux_latency => 2
        )
        port map(
            clk   => clk,
            ce    => ce,
            en    => en,
            delay => delay,
            din   => s_din,
            dout  => open
        );

    -- Stimulus process
    p_stimuli : PROCESS(clk) is
        VARIABLE v_count     : NATURAL := 1; -- ramp input to the block
        VARIABLE v_iteration : NATURAL := 0;
    BEGIN
        if v_iteration < g_delay then
            if rising_edge(clk) then
                s_iteration <= v_iteration;
                for i in 0 to g_num_ports - 1 loop
                    s_din(i)                     <= TO_UVEC(v_count, c_mux_data_width);
                    s_din_matrix(v_iteration)(i) <= TO_UVEC(v_count, c_mux_data_width);
                    v_count                      := v_count + 1;
                end loop;
                v_iteration := v_iteration + 1;
            end if;
        end if;
    END PROCESS;
end architecture tb_arch;
