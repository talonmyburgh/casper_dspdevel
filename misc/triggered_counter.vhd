-- A VHDL implementation of the CASPER triggered counter block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity triggered_cntr is
    generic(
        g_num_cntr_bits : NATURAL := 5
    );
    port(
        clk   : IN  std_logic;
        ce    : IN  std_logic;
        trig  : IN  std_logic;
        count : OUT std_logic_vector(g_num_cntr_bits - 1 DOWNTO 0);
        valid : OUT std_logic
    );
end triggered_cntr;

architecture rtl of triggered_cntr is

    SIGNAL s_trigger : std_logic_vector(0 DOWNTO 0) := (others => '0');
    SIGNAL s_edge_trigger : std_logic_vector(0 DOWNTO 0) := (others => '0');
    SIGNAL s_cnt_en : std_logic :='0';
    SIGNAL s_msb : std_logic := '0';
    SIGNAL s_cnt_out : std_logic_vector(g_num_cntr_bits DOWNTO 0) := (others => '0');
    SIGNAL s_count : std_logic_vector(g_num_cntr_bits - 1 DOWNTO 0) := (others => '0');

begin

    s_trigger(0) <= trig;
    s_msb <= s_cnt_out(g_num_cntr_bits);
    s_count <= s_cnt_out(g_num_cntr_bits - 1 DOWNTO 0);
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
            g_init      => 0,
            g_width     => g_num_cntr_bits + 1,
            g_step_size => 1
        )
        port map(
            rst    => std_logic(s_edge_trigger),
            clk    => clk,
            clken  => ce,
            cnt_en => s_cnt_en,
            count  => s_cnt_out
        );

end architecture;
