-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, common_pkg_lib, common_components_lib,technology_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE technology_lib.technology_select_pkg.ALL;

--
-- Function: Signed complex multiply
--   p = a * b       when g_conjugate_b = FALSE
--     = (ar + j ai) * (br + j bi)
--     =  ar*br - ai*bi + j ( ar*bi + ai*br)
--
--   p = a * conj(b) when g_conjugate_b = TRUE
--     = (ar + j ai) * (br - j bi)
--     =  ar*br + ai*bi + j (-ar*bi + ai*br)
--
-- Architectures:
-- . rtl          : uses RTL to have all registers in one clocked process
-- . str          : uses two RTL instances of common_mult_add2 for out_pr and out_pi
-- . str_stratix4 : uses two Stratix4 instances of common_mult_add2 for out_pr and out_pi
-- . stratix4     : uses MegaWizard component from common_complex_mult(stratix4).vhd
-- . rtl_dsp      : uses RTL with one process (as in Altera example)
-- . altera_rtl   : uses RTL with one process (as in Altera example, by Raj R. Thilak)
--
-- Preferred architecture: 'str', see synth\quartus\common_top.vhd

ENTITY common_complex_mult IS
	GENERIC(
		g_use_ip           : BOOLEAN := FALSE;  -- Use IP component when TRUE, else rtl component when FALSE
		g_use_variant      : STRING  := "3DSP"; --! Use 4DSP variant or 3DSP variant
		g_use_dsp          : STRING  := "YES";
		g_in_a_w           : POSITIVE := 8;  --! Input A-bitwidth
		g_in_b_w           : POSITIVE := 8;  --! Input B-bitwidth
		g_out_p_w          : POSITIVE := 16;  --! default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_conjugate_b      : BOOLEAN := FALSE; --! Conjugate b value prior to cmult
		g_pipeline_input   : NATURAL := 0; --! 0 or 1
		g_pipeline_product : NATURAL := 1; --! 0 or 1
		g_pipeline_adder   : NATURAL := 1; --! 0 or 1
		g_pipeline_output  : NATURAL := 1 --! >= 0
	);
	PORT(
		rst     : IN  STD_LOGIC := '0'; --! Reset port, active high
		clk     : IN  STD_LOGIC;        --! Clock signal
		clken   : IN  STD_LOGIC := '1'; --! Clock enable
		in_ar   : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0); --! Input real A value
		in_ai   : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0); --! Input imag A value
		in_br   : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0); --! Input real B value
		in_bi   : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0); --! Input imag B value
		in_val  : IN  STD_LOGIC := '1'; --! Sync pulse
		out_pr  : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0); --! Output real value
		out_pi  : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0); --! Output imag value
		out_val : OUT STD_LOGIC         --! Output sync
	);
END common_complex_mult;

ARCHITECTURE str OF common_complex_mult IS

	CONSTANT c_pipeline : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_adder + g_pipeline_output;

	-- MegaWizard IP ip_stratixiv_complex_mult was generated with latency c_dsp_latency = 3
	CONSTANT c_dsp_latency : NATURAL := sel_a_b((c_tech_select_default = c_tech_agilex or c_tech_select_default=c_tech_versal),4,3); -- the agilex model is 4 clocks internally so deal with that here.

	-- Extra output pipelining is only needed when c_pipeline > c_dsp_latency
	CONSTANT c_pipeline_output : NATURAL := 1;--sel_a_b(c_pipeline > c_dsp_latency, c_pipeline - c_dsp_latency, 0);

	SIGNAL result_re : STD_LOGIC_VECTOR(g_in_a_w + g_in_b_w DOWNTO 0);
	SIGNAL result_im : STD_LOGIC_VECTOR(g_in_a_w + g_in_b_w DOWNTO 0);
	signal in_clr    : STD_LOGIC := '0';
	signal in_en     : STD_LOGIC := '1';

BEGIN
	-- User specificied latency must be >= MegaWizard IP dsp_mult_add2 latency
	ASSERT c_pipeline >= c_dsp_latency
	REPORT "tech_complex_mult: pipeline value not supported"
	SEVERITY FAILURE;

	-- Propagate in_val with c_pipeline latency
	u_out_val : ENTITY common_components_lib.common_pipeline_sl
		GENERIC MAP(
			g_pipeline => c_pipeline
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			clken   => clken,
			in_clr  => in_clr,
			in_en   => in_en,
			in_dat  => in_val,
			out_dat => out_val
		);

	u_complex_mult : ENTITY work.tech_complex_mult
		GENERIC MAP(
			g_use_ip           => g_use_ip,
			g_use_variant      => g_use_variant,
			g_use_dsp          => g_use_dsp,
			g_in_a_w           => g_in_a_w,
			g_in_b_w           => g_in_b_w,
			g_conjugate_b      => g_conjugate_b,
			g_pipeline_input   => g_pipeline_input,
			g_pipeline_product => g_pipeline_product,
			g_pipeline_adder   => g_pipeline_adder,
			g_pipeline_output  => g_pipeline_output
		)
		PORT MAP(
			rst       => rst,
			clk       => clk,
			clken     => clken,
			in_ar     => in_ar,
			in_ai     => in_ai,
			in_br     => in_br,
			in_bi     => in_bi,
			result_re => result_re,
			result_im => result_im
		);

	------------------------------------------------------------------------------
	-- Extra output pipelining
	------------------------------------------------------------------------------

	u_output_re_pipe : ENTITY common_components_lib.common_pipeline -- pipeline output
		GENERIC MAP(
			g_representation => "SIGNED",
			g_pipeline       => c_pipeline_output,
			g_in_dat_w       => g_in_a_w + g_in_b_w + 1,
			g_out_dat_w      => g_out_p_w
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			clken   => clken,
			in_clr  => in_clr,
			in_en   => in_en,
			in_dat  => STD_LOGIC_VECTOR(result_re),
			out_dat => out_pr
		);

	u_output_im_pipe : ENTITY common_components_lib.common_pipeline -- pipeline output
		GENERIC MAP(
			g_representation => "SIGNED",
			g_pipeline       => c_pipeline_output,
			g_in_dat_w       => g_in_a_w + g_in_b_w + 1,
			g_out_dat_w      => g_out_p_w
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			clken   => clken,
			in_clr  => in_clr,
			in_en   => in_en,
			in_dat  => STD_LOGIC_VECTOR(result_im),
			out_dat => out_pi
		);

END str;
