library ieee, common_pkg_lib, casper_ram_lib, technology_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use work.rTwoSDFPkg.all;
use technology_lib.technology_select_pkg.all;

entity rTwoWeights is
	generic(
		g_stage           : natural := 4; -- The stage number of the pft
		g_wb_factor	      : natural := 1; -- The wideband factor of the wideband FFT
		g_wb_inst		  : natural := 1; -- WB instance index
		g_twid_file_stem  : string  := "UNUSED"; -- Pull the file stem from the rTwoSDFPkg
		g_ram_primitive   : string  := "block";	-- BRAM primitive for Weights 
		g_ram			  : t_c_mem := c_mem_ram -- RAM parameters
	);
	port(
		clk       : in  std_logic;
		in_wAdr   : in  std_logic_vector;
		weight_re : out std_logic_vector;
		weight_im : out std_logic_vector
	);
end;

architecture rtl of rTwoWeights is
	
	-- Ought to just be unique across stages
	-- g_stage : log2(nof_points) -> log2(wb_factor) = log2(nof_points/wb_factor) stage.
	-- stage indexing goes from log2(nof_points) -> log2(wb_factor) + 1  
	-- g_wb_inst : 0 -> wb_factor - 1
	constant c_twid_file : string := (g_twid_file_stem	& "_" & integer'image(g_wb_inst) & "wbinst_" & (integer'image(g_stage + true_log2(g_wb_factor) - 1))  & "stg"  & sel_a_b(c_tech_select_default = c_tech_xpm, ".mem", ".mif")); 

	signal re_addr : std_logic_vector(in_wAdr'length downto 0);
	signal im_addr : std_logic_vector(in_wAdr'length downto 0);


    begin
		--Real address addresses all odd indices, Imag all even. This also gives address widths g_stage which is the size of the bram.
		re_addr <= in_wAdr & '0';
		im_addr <= in_wAdr & '1';

        -- Instantiate a BRAM for the coefficients
		coef_mem : entity casper_ram_lib.common_rom_r_r
			generic map(
				g_ram => g_ram,
				g_init_file => c_twid_file,
				g_true_dual_port => TRUE, 
				g_ram_primitive => g_ram_primitive
			)
			port map(
				clk => clk,
				clken => std_logic'('1'),
				adr_a => re_addr,
				adr_b => im_addr,
				rd_en_a => std_logic'('1'),
				rd_en_b => std_logic'('1'),
				rd_dat_a => weight_re,
				rd_dat_b => weight_im,
				rd_val_a => open,
				rd_val_b => open
			);

end rtl;