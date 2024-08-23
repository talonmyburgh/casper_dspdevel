-- Testbench for partial_delay_prog

library ieee;
use ieee.std_logic_1164.all;

entity tb_partial_delay_prog is
end entity tb_partial_delay_prog;

architecture tb_arch of tb_partial_delay_prog is
    -- Component declaration
    component partial_delay_prog
        port (
            -- Add port declarations here
        );
    end component;

    -- Signal declarations
    signal clk : std_logic := '0';
    -- Add signal declarations for other ports here

begin
    -- Instantiate the DUT (Device Under Test)
    dut : partial_delay_prog
        port map (
            -- Map the DUT ports to signals here
        );

    -- Clock process
    clk_process : process
    begin
        while now < 1000 ns loop
            clk <= not clk;
            wait for 5 ns;
        end loop;
        wait;
    end process clk_process;

    -- Add test stimulus process here

end architecture tb_arch;