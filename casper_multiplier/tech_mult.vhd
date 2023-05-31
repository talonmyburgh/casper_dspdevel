
LIBRARY IEEE, common_pkg_lib, common_components_lib, technology_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE work.tech_mult_component_pkg.all;
USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
LIBRARY ip_stratixiv_mult_lib;
LIBRARY ip_xpm_mult_lib;

ENTITY tech_mult IS
	GENERIC(
		g_sim              : BOOLEAN := TRUE;
		g_sim_level        : NATURAL := 0; 	   -- 0: Simulate variant passed via g_variant for given technology
		g_use_dsp          : STRING  := "YES"; --! Implement multiplications in DSP48 or not
		g_in_a_w           : POSITIVE;
		g_in_b_w           : POSITIVE;
		g_out_p_w          : POSITIVE;  -- default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_pipeline_input   : NATURAL := 1; -- 0 or 1
		g_pipeline_product : NATURAL := 0; -- 0 or 1
		g_pipeline_output  : NATURAL := 1 -- >= 0
	);
	PORT(
		rst    : IN  STD_LOGIC := '0';
		clk    : IN  STD_LOGIC;
		clken  : IN  STD_LOGIC := '1';
		in_a   : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);
		in_b   : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);
		result : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0)
	);
END tech_mult;

ARCHITECTURE str of tech_mult is

	-- sim_model=1
	SIGNAL result_undelayed : STD_LOGIC_VECTOR(g_in_b_w + g_in_a_w - 1 DOWNTO 0);

begin
	gen_ip_xpm_rtl : IF c_tech_select_default <= c_tech_versal GENERATE  -- Xilinx, Stratix or AgileX or versal
		u_ip_mult_infer : ip_mult_infer
			generic map(
				g_use_dsp          => g_use_dsp,
				g_in_a_w           => g_in_a_w,
				g_in_b_w           => g_in_b_w,
				g_out_p_w          => g_out_p_w,
				g_pipeline_input   => g_pipeline_input,
				g_pipeline_product => g_pipeline_product,
				g_pipeline_output  => g_pipeline_output
			)
			port map(
				in_a  => in_a,
				in_b  => in_b,
				clk   => clk,
				rst   => rst,
				ce    => clken,
				out_p => result
			);
--  only allowed in VHDL 2008			
--	else generate
--		-- Use an inferred mult
--		assert false report "No Multiplier Generated!" severity failure;
	end generate;

	-------------------------------------------------------------------------------
	-- Model: forward concatenated inputs to the 'result' output
	-- 
	-- Example:
	--                                    ______ 
	-- Input B = 0xBBBB --> 			 |      |
	--                                   | mult | --> Output result = 0xBBBBAAAA
	-- Input A = 0xAAAA --> 			 |______|
	-- 
	-- Note: this model is synthsizable as well.
	-- 
	-------------------------------------------------------------------------------	
	gen_sim_level_1 : IF g_sim = TRUE AND g_sim_level = 1 GENERATE
		result_undelayed <= in_b & in_a;

		u_common_pipeline : entity common_components_lib.common_pipeline
			generic map(
				g_pipeline  => 3,
				g_in_dat_w  => g_in_b_w + g_in_a_w,
				g_out_dat_w => g_out_p_w
			)
			port map(
				clk     => clk,
				in_dat  => result_undelayed,
				out_dat => result
			);
	END GENERATE;

end str;
