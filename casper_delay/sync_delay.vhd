-- Delay an infrequent boolean pulse by the specified number of clocks.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
library ieee, common_pkg_lib, casper_counter_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;

entity sync_delay is
    generic(
        g_delay : natural := 4
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  std_logic;
        dout : out std_logic
    );
end entity sync_delay;

architecture RTL of sync_delay is

    constant c_ceil_log2 : NATURAL := ceil_log2(g_delay);
    constant c_cnt_w     : NATURAL := sel_a_b(2 > c_ceil_log2, 2, c_ceil_log2); --max(2, ceil_log2(g_delay)

    signal s_count    : std_logic_vector(c_cnt_w - 1 downto 0) := TO_UVEC(2**c_cnt_w, c_cnt_w);
    signal s_cnt_load : std_logic_vector(c_cnt_w - 1 downto 0) := TO_UVEC(g_delay, c_cnt_w);
    signal s_or_out   : std_logic := '0';
    signal s_a_neq_b  : std_logic := '0';
    signal s_a_eq_b   : std_logic := '0';
    signal s_zero     : std_logic_vector(c_cnt_w - 1 downto 0) := TO_UVEC(0, c_cnt_w);
    signal s_one      : std_logic_vector(c_cnt_w - 1 downto 0) := TO_UVEC(1, c_cnt_w);
    signal s_sel      : std_logic                              := sel_a_b(g_delay = 0, '0', '1'); --bypass logic for zero delay
begin
    ------------------------------------------------------------
    -- COUNTER
    counter : entity casper_counter_lib.common_counter
        generic map(
            g_latency   => 1,
            g_init      => 0,
            g_width     => c_cnt_w,
            g_max       => 0,
            g_step_size => -1
        )
        port map(
            clk    => clk,
            clken  => ce,
            cnt_ld => din,
            cnt_en => s_or_out,
            load   => s_cnt_load,
            count  => s_count
        );
    ------------------------------------------------------------
    ------------------------------------------------------------
    -- OR
    s_or_out <= din or s_a_neq_b;

    -- NEQ
    s_a_neq_b <= sel_a_b(s_zero = s_count, '0', '1');

    -- EQ
    s_a_eq_b <= sel_a_b(s_one = s_count, '1', '0');
    ------------------------------------------------------------
    -- MUX
    dout     <= s_a_eq_b when s_sel = '1' else din;

end architecture RTL;
