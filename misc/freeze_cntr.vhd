-- A VHDL implementation of the CASPER freeze_cntr block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity freeze_cntr is
    generic(
        g_num_cntr_bits : NATURAL := 5
    );
    port(
        clk  : IN  std_logic;
        ce   : IN  std_logic;
        en   : IN  std_logic;
        rst  : IN  std_logic;
        addr : OUT std_logic_vector(g_num_cntr_bits - 1 DOWNTO 0);
        we   : OUT std_logic;
        done : OUT std_logic
    );
end freeze_cntr;

architecture rtl of freeze_cntr is

    signal s_stop_cnt : STD_LOGIC_VECTOR(g_num_cntr_bits - 1 DOWNTO 0) := (others => '1');
    signal s_cnt_en   : STD_LOGIC;
    signal s_done     : STD_LOGIC;
    signal s_not_rst  : STD_LOGIC;
    signal s_cnt      : STD_LOGIC_VECTOR(g_num_cntr_bits DOWNTO 0);

begin

    s_not_rst <= not rst;
    we        <= s_not_rst and en;
    addr      <= s_cnt(g_num_cntr_bits - 1 DOWNTO 0);
    s_done    <= '1' when s_cnt(g_num_cntr_bits - 1 DOWNTO 0) = s_stop_cnt else '0';
    s_cnt_en  <= (not s_done) and en;
    done      <= s_done;

    common_counter_inst : entity casper_counter_lib.common_counter
        generic map(
            g_latency   => 1,
            g_init      => 0,
            g_width     => g_num_cntr_bits + 1,
            g_step_size => 1
        )
        port map(
            rst    => rst,
            clk    => clk,
            clken  => ce,
            cnt_en => s_cnt_en,
            count  => s_cnt
        );

end architecture;
