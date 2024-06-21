-- A VHDL free-running down-counter module with asynch reset.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

library ieee, casper_counter_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity free_run_down_counter is
    generic(
        g_cnt_w : natural := 4
    );
    port(
        clk     : in std_logic;
        ce      : in std_logic;
        reset   : in std_logic;
        count   : out std_logic_vector(g_cnt_w - 1 DOWNTO 0)
    );
end entity free_run_down_counter;

ARCHITECTURE rtl of free_run_down_counter is
    constant c_max_count : natural := 2**g_cnt_w - 1;

    signal s_count : std_logic_vector(g_cnt_w - 1 DOWNTO 0);

begin
    
        process (clk, reset)
            variable cnt : integer range 0 to c_max_count;
        begin
            if (reset = '1') then
                cnt := c_max_count;
            elsif (rising_edge(clk) and ce = '1') then
                cnt := cnt - 1;
            end if;
            s_count <= std_logic_vector(to_signed(cnt, g_cnt_w));
        end process;
    
        count <= s_count;
    
    end ARCHITECTURE rtl;