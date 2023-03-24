library ieee, common_pkg_lib, casper_ram_lib, technology_lib,r2sdf_fft_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use work.rTwoSDFPkg.all;
use technology_lib.technology_select_pkg.all;
use r2sdf_fft_lib.twiddlesPkg.all;

entity rTwoWeights is
	generic(
		g_stage           : natural := 4; -- The stage number of the pft
		g_wb_factor	      : natural := 1; -- The wideband factor of the wideband FFT
		g_wb_inst		  : natural := 1; -- WB instance index
		g_twid_file_stem  : string  := "UNUSED"; -- Pull the file stem from the rTwoSDFPkg
		g_ram_primitive   : string  := "block";	-- BRAM primitive for Weights 
		g_do_ifft		  : boolean := false;
		g_use_inferred_ram: boolean := false;
		g_ram			  : t_c_mem := c_mem_ram -- RAM parameters
	);
	port(
		clk       : in  std_logic;
		in_wAdr   : in  std_logic_vector;
		weight_re : out std_logic_vector;
		weight_im : out std_logic_vector
	);
end;

architecture rTwoWeights_rtl of rTwoWeights is
	
	-- Ought to just be unique across stages
	-- g_stage : log2(nof_points) -> log2(wb_factor) = log2(nof_points/wb_factor) stage.
	-- stage indexing goes from log2(nof_points) -> log2(wb_factor) + 1  
	-- g_wb_inst : 0 -> wb_factor - 1
	constant c_twid_file 	: string := (g_twid_file_stem	& "_" & integer'image(g_wb_inst) & "wbinst_" & (integer'image(g_stage + true_log2(g_wb_factor) - 1))  & "stg"  & sel_a_b(c_tech_select_default = c_tech_xpm, ".mem", ".mif")); 

	signal add_reg_mux		: unsigned(min_one(in_wAdr'length)-1 downto 0);
	signal addr_reg			: unsigned(min_one(in_wAdr'length)-1 downto 0);
	constant c_latency 		: natural := g_ram.latency;
	signal rom_data			: signed((2*weight_re'length)-1 downto 0);

	signal re_addr			: std_logic_vector(in_wAdr'length downto 0);
	signal im_addr			: std_logic_vector(in_wAdr'length downto 0);
	attribute rom_style : string;

	
	signal rom              : twiddle_signed_array(min_one(2**(g_stage-1))-1 downto 0)((2*weight_re'length)-1 downto 0) := gen_twiddle_factor_rom(g_wb_inst,g_stage,g_wb_factor, weight_re'length,g_do_ifft); -- @suppress "signal rom is never written"
	attribute rom_style of rom : signal is g_ram_primitive;
	signal weight_re_irom			: std_logic_vector(weight_re'length-1 downto 0);
	signal weight_im_irom			: std_logic_vector(weight_im'length-1 downto 0);
begin

	assert c_latency>0 and c_latency<3 report "rTwoWeights: unsupported latency" severity failure;





      --  assert FALSE REPORT "Using twiddle file: " & c_twid_file severity error;
      -- Instantiate a BRAM for the coefficients
	use_tech_rom : if not(g_use_inferred_ram) generate
		re_addr <= in_wAdr & "0";
		im_addr <= in_wAdr & "1";

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
	end generate use_tech_rom;
	use_infer_rom: if (g_use_inferred_ram) generate
		noaddress : if in_wAdr'length=0 generate
			weight_re_irom <= std_logic_vector(to_signed((2**(weight_re'length-1))-1,weight_re'length)); --send max positive value
			weight_im_irom <= std_logic_vector(to_signed(0,weight_re'length));
		end generate noaddress;

		rom_infer : if in_wAdr'length>0 generate
			-- We just use a wider RAM now, rather than use dual-port.
			-- For most common Coefficient sizes Xilinx and Intel will automatically do the right thing
			-- Wider memories are usually not a problem
			-- Note Ultraram might not efficiently be used unless we futz with sharing roms.

			add_reg_mux	<= addr_reg when c_latency=2 else unsigned(in_wAdr);
			twiddle_rom_proc : process (clk)
			begin
				if clk'event and clk='1' then
					addr_reg	<= unsigned(in_wAdr);
					rom_data	<= rom(to_integer(add_reg_mux));
				end if;
			end process twiddle_rom_proc;

			weight_re_irom <= std_logic_vector(rom_data(weight_re'length-1 downto 0));
			weight_im_irom <= std_logic_vector(rom_data(rom_data'length-1 downto weight_re'length));
		end generate rom_infer;
		weight_re <= weight_re_irom;
		weight_im <= weight_im_irom;
	end generate use_infer_rom;

end rTwoWeights_rtl;