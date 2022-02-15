----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/20/2021 06:21:56 PM
-- Design Name: 
-- Module Name: tb_top_fil - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE, casper_filter_lib;
use IEEE.STD_LOGIC_1164.ALL;
use work.fil_pkg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_top_fil is
--  Port ( );
end tb_top_fil;

architecture Behavioral of tb_top_fil is
    constant clk_hz : integer := 100e6;
    constant clk_period : time := 1 sec / clk_hz;

    signal clk : std_logic := '1';
    signal rst : std_logic := '1';
    signal out_val : std_logic := '1';
   
    signal dat_in : std_logic_vector(in_dat_w-1 downto 0);
    signal dat_out : std_logic_vector(out_dat_w-1 downto 0);

begin
    clk <= not clk after clk_period / 2;
    DUT: entity work.top_fil(rtl)
    port map(
        clk => clk,
        ce => '1',
        rst => rst,
        in_val => '1',
        out_val => out_val,
        in_dat_0 => dat_in,
        out_dat_0 => dat_out
    );
    
    SEQUENCER_PROC : process
    begin
    wait for clk_period*10;
    rst<='0';
    wait for clk_period;
        for i in 0 to 1023 loop
            if i /= 127 then
                dat_in <= "00000000";
            else
                dat_in <= "11111111";
            end if;
        wait for clk_period;
        end loop;
    end process;
    


end Behavioral;
