library ieee, r2sdf_fft_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_gnrcs_intrfcs_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;

use std.textio.all;
use std.env.finish;

entity fft_wide_unit_tb is
end fft_wide_unit_tb;

architecture sim of fft_wide_unit_tb is

    constant clk_hz : integer := 100e6;
    constant clk_period : time := 1 sec / clk_hz;

    signal clk : std_logic := '1';
    signal rst : std_logic := '1';

    signal array_in : t_bb_sosi_arr_in(wb_factor -1 downto 0);
    signal array_out : t_bb_sosi_arr_out(wb_factor -1 downto 0);

begin

    clk <= not clk after clk_period / 2;

    DUT : entity work.fft_wide_unit(str)
    generic map
    (
        g_fft          => c_fft,
        g_pft_pipeline => c_fft_pipeline, -- For the pipelined part, defined in casper_r2sdf_fft_lib.rTwoSDFPkg
		g_fft_pipeline => c_fft_pipeline -- For the parallel part, defined in casper_r2sdf_fft_lib.rTwoSDFPkg
    )
    port map (
        clk => clk,
        rst => rst,
        clken => '1',
        in_bb_sosi_arr => array_in,
		out_bb_sosi_arr => array_out
    );

    SEQUENCER_PROC : process
    begin
        wait for clk_period * 2;

        rst <= '0';

        wait for clk_period * 10;

        -- RESET INPUT ARRAY
        for I in 0 to wb_factor-1 loop
            array_in(I) <= c_bb_sosi_rst_in;
        end loop;

        wait for clk_period *39;
        array_in(0).sync <='1';
        array_in(0).valid <= '1';
        wait for clk_period;
        array_in(0).sync<='0';
        wait for clk_period;
        array_in(0).re <= "01111111";
        wait for clk_period*2;
        array_in(0).re <= "00000000";
        wait for clk_period*255;
        array_in(0).re <= "01111111";
        wait for clk_period*2;
        array_in(0).re <= "00000000";
        wait;
    end process;
end architecture;