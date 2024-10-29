-- A VHDL implementation of the CASPER triggered counter block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, common_pkg_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.all;

entity triggered_cntr is
    generic(
        g_run_length    : NATURAL := 8
    );
    port(
        clk   : IN  std_logic;
        ce    : IN  std_logic;
        trig  : IN  std_logic;
        count : OUT std_logic_vector;
        valid : OUT std_logic
    );
end triggered_cntr;

architecture rtl of triggered_cntr is
    CONSTANT c_init_val : INTEGER := pow2(next_pow2(g_run_length) +1) - g_run_length;
    CONSTANT c_cnt_bit_widths : NATURAL := next_pow2(g_run_length) + 1;

    SIGNAL s_trigger : std_logic_vector(0 DOWNTO 0) := (others => '0');
    SIGNAL s_edge_trigger : std_logic_vector(0 DOWNTO 0) := (others => '0');
    SIGNAL s_cnt_en : std_logic :='0';
    SIGNAL s_msb : std_logic := '0';
    SIGNAL s_cnt_out : std_logic_vector(c_cnt_bit_widths - 1 DOWNTO 0) := (others => '0');
    SIGNAL s_count : std_logic_vector(c_cnt_bit_widths - 2 DOWNTO 0) := (others => '0');

begin

    s_trigger(0) <= trig;
    s_msb <= s_cnt_out(s_cnt_out'high);
    s_count <= s_cnt_out(s_cnt_out'high - 1 DOWNTO 0);
    s_cnt_en <= s_msb;
    count <= s_count;
    valid <= s_msb;

    edge_detect_inst : entity work.edge_detect
        generic map(
            g_edge_type  => "rising",
            g_output_pol => "high"
        )
        port map(
            clk     => clk,
            ce      => ce,
            in_sig  => s_trigger,
            out_sig => s_edge_trigger
        );
    

    common_counter_inst : entity casper_counter_lib.common_counter
        generic map(
            g_latency   => 1,
            g_init      => c_init_val,
            g_width     => c_cnt_bit_widths,
            g_step_size => 1
        )
        port map(
            rst    => s_edge_trigger(0),
            clk    => clk,
            clken  => ce,
            cnt_en => s_cnt_en,
            count  => s_cnt_out
        );

end architecture;
