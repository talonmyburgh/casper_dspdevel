----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.08.2020 10:40:41
-- Design Name: 
-- Module Name: common_ram_crw_crw_tb - Behavioral
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

library IEEE, casper_ram_lib, common_pkg_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE casper_ram_lib.common_ram_pkg.all;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity common_ram_crw_crw_tb is
end common_ram_crw_crw_tb;

architecture Behavioral of common_ram_crw_crw_tb is
	CONSTANT clk_period : TIME    := 10 ns;
	CONSTANT c_data_w   : NATURAL := 9;

	SIGNAL rst      : STD_LOGIC;
	SIGNAL clk      : STD_LOGIC                               := '1';
	SIGNAL wr_en_a  : STD_LOGIC                               := '0';
	SIGNAL wr_en_b  : STD_LOGIC                               := '0';
	SIGNAL wrdata_a : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wrdata_b : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rddata_a : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rddata_b : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL adr_a    : STD_LOGIC_VECTOR(9 DOWNTO 0)            := (OTHERS => '0');
	SIGNAL adr_b    : STD_LOGIC_VECTOR(9 DOWNTO 0)            := (OTHERS => '0');
	SIGNAL rd_val_a : STD_LOGIC                               := '0';
	SIGNAL rd_val_b : STD_LOGIC                               := '0';
	SIGNAL tb_end   : STD_LOGIC                               := '0';
	SIGNAL rd_en_b  : STD_LOGIC                               := '0';
begin

	clk <= NOT clk AND NOT tb_end AFTER clk_period / 2;
	rst <= '1', '0' AFTER clk_period * 7;
	stimuli : process is
	begin
		wait for clk_period * 10;
		FOR I IN 0 TO 10 LOOP
			wr_en_a <= '1';
			wait for clk_period * 6;
			wr_en_a <= '0';
			wait for clk_period * 6;
		END LOOP;
		tb_end <= '1';
		wait;
	end process stimuli;

	wrdata_a <= INCR_UVEC(wrdata_a, 1) WHEN rising_edge(clk) AND wr_en_a = '1';
	adr_a    <= INCR_UVEC(adr_a, 1) WHEN rising_edge(clk) AND wr_en_a = '1';
	adr_b    <= adr_a WHEN rising_edge(clk);
	--rd_en_b  <=            wr_en_a     WHEN rising_edge(clk);

	dut : entity work.common_ram_crw_crw
		generic map(
			g_technology     => 0,
			g_ram            => c_mem_ram,
			g_init_file      => "UNUSED",
			g_true_dual_port => True,
			g_ram_primitive  => "auto"
		)
		port map(
			clk_a    => clk,
			clk_b    => clk,
			clken_a  => '1',
			clken_b  => '1',
			wr_en_a  => wr_en_a,
			wr_en_b  => '0',
			wr_dat_a => wrdata_a,
			wr_dat_b => (others => '1'),
			adr_a    => adr_a,
			adr_b    => adr_b,
			rd_en_a  => '1',
			rd_en_b  => '1',
			rd_dat_a => rddata_a,
			rd_dat_b => rddata_b,
			rd_val_a => open,
			rd_val_b => rd_val_b
		);
end Behavioral;
