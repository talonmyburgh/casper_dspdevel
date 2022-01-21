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
		g_wb_inst		  : natural := 1; -- WB instance index
		g_lat             : natural := 1; -- latency 0 or 1
		g_twid_dat_w	  : natural := 18; -- coefficient data width
		g_twiddle_offset  : natural := 0; -- The twiddle offset: 0 for normal FFT. Other than 0 in wideband FFT
		g_twid_file_stem  : string  := c_twid_file_stem; -- Pull the file stem from the rTwoSDFPkg
		g_stage_offset    : natural := 0 -- The Stage offset: 0 for normal FFT. Other than 0 in wideband FFT
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
	constant c_twid_file : string := (g_twid_file_stem	& "_" & integer'image(g_wb_inst) & "wb_" & integer'image(g_stage) & "stg_"  & sel_a_b(c_tech_select_default = c_tech_xpm, ".mem", ".mif")); 
	-- Calculate the address width needed to represent all values
	constant c_adr_w : natural := 9; 
	-- then we will calculate whether to implement in block or distributed based on the address width
	constant c_num_coefs : natural := 30;
	constant c_ram_primitive : string := "block";
	constant c_ram : t_c_mem := (g_lat, c_adr_w, g_twid_dat_w, c_num_coefs, '0');

	signal im_addr : std_logic_vector(in_wAdr'range) := std_logic_vector(unsigned(in_wAdr) + 1); 

    begin

        -- Instantiate a BRAM for the coefficients
		coef_mem : entity casper_ram_lib.common_rom_r_r
			generic map(
				g_ram => c_ram,
				g_init_file => c_twid_file,
				g_true_dual_port => TRUE, 
				g_ram_primitive => c_ram_primitive
			)
			port map(
				clk => clk,
				clken => std_logic'('1'),
				adr_a => in_wAdr,
				adr_b => im_addr,
				rd_en_a => std_logic'('1'),
				rd_en_b => std_logic'('1'),
				rd_dat_a => weight_re,
				rd_dat_b => weight_im,
				rd_val_a => open,
				rd_val_b => open
			);

end rtl;