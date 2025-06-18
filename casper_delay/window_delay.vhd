-- Implementation of the CASPER window delay block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
library ieee, common_pkg_lib, casper_misc_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;

entity window_delay is
    generic(
        g_delay          : natural := 4
    );
    port(
        clk   : in  std_logic;
        ce    : in  std_logic;
        din   : in  std_logic;
        dout  : out std_logic
    );
end entity window_delay;

architecture RTL of window_delay is

    SIGNAL s_din : std_logic_vector(0 DOWNTO 0);
    SIGNAL s_pos_edge : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL s_neg_edge : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL s_neg_delay : std_logic;
    SIGNAL s_pos_delay : std_logic;

begin

    s_din(0) <= din;

    pos_edge_detect_inst : entity casper_misc_lib.edge_detect
        generic map(
            g_edge_type  => "rising",
            g_output_pol => "high"
        )
        port map(
            clk     => clk,
            ce      => ce,
            in_sig  => s_din,
            out_sig => s_pos_edge
        );

    neg_edge_detect_inst : entity casper_misc_lib.edge_detect
        generic map(
            g_edge_type  => "falling",
            g_output_pol => "high"
        )
        port map(
            clk     => clk,
            ce      => ce,
            in_sig  => s_din,
            out_sig => s_neg_edge
        );
    
    pos_sync_delay_inst : entity work.sync_delay
        generic map(
            g_delay          => g_delay
        )
        port map(
            clk   => clk,
            ce    => ce,
            en    => '1',
            din   => s_pos_edge(0),
            delay => "0000",
            dout  => s_pos_delay
        );

    neg_sync_delay_inst : entity work.sync_delay
        generic map(
            g_delay          => g_delay
        )
        port map(
            clk   => clk,
            ce    => ce,
            en    => '1',
            din   => s_neg_edge(0),
            delay => "0000",
            dout  => s_neg_delay
        );
    
    register_output : process(clk, s_neg_delay) is
    begin
        if s_neg_delay = '1' then
            dout <= '0';
        end if;
        if rising_edge(clk) and ce = '1' and s_pos_delay = '1' then
            dout <= s_pos_delay;
        end if;
    end process register_output;

end architecture RTL;
