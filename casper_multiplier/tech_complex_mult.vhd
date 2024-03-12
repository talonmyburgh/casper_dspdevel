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

LIBRARY IEEE, common_pkg_lib, common_components_lib, technology_lib,casper_multiplier_lib;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;

USE common_pkg_lib.common_pkg.ALL;
USE work.tech_mult_component_pkg.all;
USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
LIBRARY ip_stratixiv_mult_lib;
LIBRARY ip_xpm_mult_lib;

ENTITY tech_complex_mult IS
	GENERIC(
		g_use_ip           : BOOLEAN := FALSE;  -- Use IP component when TRUE, else rtl component when FALSE
		g_use_variant      : STRING  := "4DSP";
		g_use_dsp          : STRING  := "YES"; --! Implement multiplications in DSP48 or not
		g_in_a_w           : POSITIVE;
		g_in_b_w           : POSITIVE;
		g_out_p_w          : POSITIVE;  -- default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_conjugate_b      : BOOLEAN := FALSE;
		g_pipeline_input   : NATURAL := 1; -- 0 or 1
		g_pipeline_product : NATURAL := 0; -- 0 or 1
		g_pipeline_adder   : NATURAL := 1; -- 0 or 1
		g_pipeline_output  : NATURAL := 1 -- >= 0
	);
	PORT(
		rst       : IN  STD_LOGIC := '0';
		clk       : IN  STD_LOGIC;
		clken     : IN  STD_LOGIC := '1';
		in_ar     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);
		in_ai     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);
		in_br     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);
		in_bi     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);
		result_re : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0);
		result_im : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0)
	);
END tech_complex_mult;

ARCHITECTURE str of tech_complex_mult is

	--! Force to maximum 18 bit width, because:
	--! . the ip_cmult_infer is generated for 18b inputs and 36b output and then uses 4 real multipliers and no additional registers
	--! . if one input   > 18b then another IP needs to be regenerated and that will use  8 real multipliers and some extra LUTs and registers
	--! . if both inputs > 18b then another IP needs to be regenerated and that will use 16 real multipliers and some extra LUTs and registers
	--! . if the output is set to 18b+18b + 1b =37b to account for the sum then another IP needs to be regenerated and that will use some extra registers
	--! ==> for inputs <= 18b this ip_complex_mult is appropriate and it can not be made parametrisable to fit also inputs > 18b.
  CONSTANT c_dsp_dat_w    : NATURAL  := 18;
  CONSTANT c_dsp_prod_w   : NATURAL  := 2*c_dsp_dat_w;

  SIGNAL ar        : STD_LOGIC_VECTOR(c_dsp_dat_w-1 DOWNTO 0);
  SIGNAL ai        : STD_LOGIC_VECTOR(c_dsp_dat_w-1 DOWNTO 0);
  SIGNAL br        : STD_LOGIC_VECTOR(c_dsp_dat_w-1 DOWNTO 0);
  SIGNAL bi        : STD_LOGIC_VECTOR(c_dsp_dat_w-1 DOWNTO 0);
  SIGNAL mult_re   : STD_LOGIC_VECTOR(c_dsp_prod_w-1 DOWNTO 0);
  SIGNAL mult_im   : STD_LOGIC_VECTOR(c_dsp_prod_w-1 DOWNTO 0);
  signal result_reTemp : signed(g_in_a_w+g_in_b_w downto 0);
  signal result_imTemp : signed(g_in_a_w+g_in_b_w downto 0);

  FUNCTION RESIZE_NUM(s : SIGNED; w : positive) RETURN SIGNED IS
  BEGIN
    -- extend sign bit or keep LS part
    IF w>s'LENGTH THEN
      RETURN RESIZE(s, w);                    -- extend sign bit
    ELSE
      RETURN SIGNED(RESIZE(UNSIGNED(s), w));  -- keep LSbits (= vec[w-1:0])
    END IF;
  END function RESIZE_NUM;

begin

	gen_ip_xpm_rtl_4dsp : IF (c_tech_select_default = c_tech_xpm) AND g_use_variant = "4DSP" GENERATE  -- Xilinx or agilex
		u1 : ip_cmult_rtl_4dsp
			generic map(
				g_use_dsp          => g_use_dsp,
				g_in_a_w           => g_in_a_w,
				g_in_b_w           => g_in_b_w,
				g_out_p_w          => g_out_p_w,
				g_conjugate_b      => g_conjugate_b,
				g_pipeline_input   => g_pipeline_input,
				g_pipeline_product => g_pipeline_product,
				g_pipeline_adder   => g_pipeline_adder,
				g_pipeline_output  => g_pipeline_output
			)
			port map(
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
	end generate;

	gen_ip_xpm_rtl_3dsp : IF (c_tech_select_default = c_tech_xpm) AND g_use_variant = "3DSP" GENERATE  -- Xilinx
		u1 : ip_cmult_rtl_3dsp
			generic map(
				g_use_dsp          => g_use_dsp,
				g_in_a_w           => g_in_a_w,
				g_in_b_w           => g_in_b_w,
				g_out_p_w          => g_out_p_w,
				g_conjugate_b      => g_conjugate_b,
				g_pipeline_input   => g_pipeline_input,
				g_pipeline_product => g_pipeline_product,
				g_pipeline_adder   => g_pipeline_adder,
				g_pipeline_output  => g_pipeline_output
			)
			port map(
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
	end generate;

  gen_ip_stratixiv_ip_4dsp : IF c_tech_select_default = c_tech_stratixiv AND g_use_variant = "4DSP" AND g_use_ip = TRUE GENERATE
    -- Adapt DSP input widths
    ar <= RESIZE_SVEC(in_ar, c_dsp_dat_w);
    ai <= RESIZE_SVEC(in_ai, c_dsp_dat_w);
    br <= RESIZE_SVEC(in_br, c_dsp_dat_w);
    bi <= RESIZE_SVEC(in_bi, c_dsp_dat_w) WHEN g_conjugate_b=FALSE ELSE TO_SVEC(-TO_SINT(in_bi), c_dsp_dat_w);

    u0 : ip_stratixiv_complex_mult
    PORT MAP (
         aclr        => rst,
         clock       => clk,
         dataa_imag  => ai,
         dataa_real  => ar,
         datab_imag  => bi,
         datab_real  => br,
         ena         => clken,
         result_imag => mult_im,
         result_real => mult_re
         );

    -- Back to true input widths and then resize for output width
    result_re <= RESIZE_SVEC(mult_re, g_out_p_w);
    result_im <= RESIZE_SVEC(mult_im, g_out_p_w);
  END GENERATE;

  gen_ip_stratixiv_rtl_4dsp : IF (c_tech_select_default = c_tech_stratixiv AND g_use_variant = "4DSP" AND g_use_ip = FALSE) GENERATE
    u0 : ip_stratixiv_complex_mult_rtl
    GENERIC MAP(
      g_in_a_w           => g_in_a_w,
      g_in_b_w           => g_in_b_w,
      g_out_p_w          => g_out_p_w,
      g_conjugate_b      => g_conjugate_b,
      g_pipeline_input   => g_pipeline_input,
      g_pipeline_product => g_pipeline_product,
      g_pipeline_adder   => g_pipeline_adder,
      g_pipeline_output  => g_pipeline_output
    )
    PORT MAP(
      rst        => rst,
      clk        => clk,
      clken      => clken,
      in_ar      => in_ar,
      in_ai      => in_ai,
      in_br      => in_br,
      in_bi      => in_bi,
      result_re  => result_re,
      result_im  => result_im
      );
  END GENERATE;

  gen_ip_stratixiv_rtl_3dsp : IF (c_tech_select_default = c_tech_stratixiv  or c_tech_select_default = c_tech_agilex) AND g_use_variant = "3DSP" GENERATE
     -- Cannot simply instantiate the RTL of ip_cmult_rtl_3dsp here, because that is kept in ip_xpm_mult_lib
     -- for c_tech_xpm, which is not available for c_tech_stratixiv. A way is to copy this RTL file also to
     -- the ip_stratixiv_mult_lib, but for now only give a FAILURE on 3DSP.
     ASSERT FALSE REPORT "g_use_variant = 3DSP is not supported for yet for gen_ip_stratixiv_rtl_3dsp" SEVERITY FAILURE;
  END GENERATE;
  
  gen_ip_agilex_rtl : if c_tech_select_default = c_tech_agilex generate
  

  begin
	tech_agilex_versal_cmult_inst : entity work.tech_agilex_versal_cmult
		generic map(
			g_is_xilinx         => false,
			g_inputA_width      => g_in_a_w,
			g_inputB_width      => g_in_b_w,
			g_desired_pipedelay => g_pipeline_input+g_pipeline_product+g_pipeline_adder+g_pipeline_output-1, -- it's not clear why, but the agilex is 1 cycle more latent than the xpm version
			g_pipe_width        => 1
		)
		port map(
			i_clk        => clk,
			i_dataA_real => signed(in_ar),
			i_dataA_imag => signed(in_ai),
			i_dataB_real => signed(in_br),
			i_dataB_imag => signed(in_bi),
			i_data_valid => '1',
			i_pipe       => "0",
			o_data_real  => result_reTemp,
			o_data_imag  => result_imTemp,
			o_data_valid => open,
			o_pipe       => open
		);
		result_re <= std_logic_vector(RESIZE_NUM(result_reTemp, g_out_p_w));	
		result_im <= std_logic_vector(RESIZE_NUM(result_imTemp, g_out_p_w));	 
  end generate;

  gen_ip_versal_rtl : if c_tech_select_default = c_tech_versal generate
  

  begin
	tech_agilex_versal_cmult_inst : entity work.tech_agilex_versal_cmult
		generic map(
			g_is_xilinx         => True,
			g_inputA_width      => g_in_a_w,
			g_inputB_width      => g_in_b_w,
			g_desired_pipedelay => g_pipeline_input+g_pipeline_product+g_pipeline_adder+g_pipeline_output-1,
			g_pipe_width        => 1
		)
		port map(
			i_clk        => clk,
			i_dataA_real => signed(in_ar),
			i_dataA_imag => signed(in_ai),
			i_dataB_real => signed(in_br),
			i_dataB_imag => signed(in_bi),
			i_data_valid => '1',
			i_pipe       => "0",
			o_data_real  => result_reTemp,
			o_data_imag  => result_imTemp,
			o_data_valid => open,
			o_pipe       => open
		);
		result_re <= std_logic_vector(RESIZE_NUM(result_reTemp, g_out_p_w));	
		result_im <= std_logic_vector(RESIZE_NUM(result_imTemp, g_out_p_w));	 
  end generate;



end str;

