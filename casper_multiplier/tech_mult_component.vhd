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

-- Purpose: IP components declarations for various devices that get wrapped by the tech components

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE tech_mult_component_pkg IS

	-----------------------------------------------------------------------------
	-- Stratix IV components
	-----------------------------------------------------------------------------

	COMPONENT ip_stratixiv_complex_mult IS
		PORT(
			aclr        : IN  STD_LOGIC;
			clock       : IN  STD_LOGIC;
			dataa_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			dataa_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			datab_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			datab_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			ena         : IN  STD_LOGIC;
			result_imag : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
			result_real : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_complex_mult_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18;
			g_in_b_w           : POSITIVE := 18;
			g_out_p_w          : POSITIVE := 36;
			g_conjugate_b      : BOOLEAN  := FALSE;
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1 -- >= 0
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
	END COMPONENT;

	COMPONENT ip_stratixiv_mult IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18;
			g_in_b_w           : POSITIVE := 18;
			g_out_p_w          : POSITIVE := 36; -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
			g_nof_mult         : POSITIVE := 1; -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1; -- >= 0
			g_representation   : STRING   := "SIGNED" -- or "UNSIGNED"
		);
		PORT(
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			out_p : OUT STD_LOGIC_VECTOR(g_nof_mult * (g_in_a_w + g_in_b_w) - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_mult_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18;
			g_in_b_w           : POSITIVE := 18;
			g_out_p_w          : POSITIVE := 36; -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
			g_nof_mult         : POSITIVE := 1; -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1; -- >= 0
			g_representation   : STRING   := "SIGNED" -- or "UNSIGNED"
		);
		PORT(
			rst   : IN  STD_LOGIC;
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			out_p : OUT STD_LOGIC_VECTOR(g_nof_mult * (g_in_a_w + g_in_b_w) - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_mult_add2_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_res_w            : POSITIVE; -- g_in_a_w + g_in_b_w + log2(2)
			g_force_dsp        : BOOLEAN := TRUE; -- when TRUE resize input width to >= 18
			g_add_sub          : STRING  := "ADD"; -- or "SUB"
			g_nof_mult         : INTEGER := 2; -- fixed
			g_pipeline_input   : NATURAL := 1; -- 0 or 1
			g_pipeline_product : NATURAL := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL := 1; -- 0 or 1
			g_pipeline_output  : NATURAL := 1 -- >= 0
		);
		PORT(
			rst   : IN  STD_LOGIC := '0';
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			res   : OUT STD_LOGIC_VECTOR(g_res_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_mult_add4_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_res_w            : POSITIVE; -- g_in_a_w + g_in_b_w + log2(4)
			g_force_dsp        : BOOLEAN := TRUE; -- when TRUE resize input width to >= 18
			g_add_sub0         : STRING  := "ADD"; -- or "SUB"
			g_add_sub1         : STRING  := "ADD"; -- or "SUB"
			g_add_sub          : STRING  := "ADD"; -- or "SUB" only available with rtl architecture
			g_nof_mult         : INTEGER := 4; -- fixed
			g_pipeline_input   : NATURAL := 1; -- 0 or 1
			g_pipeline_product : NATURAL := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL := 1; -- 0 or 1, first sum
			g_pipeline_output  : NATURAL := 1 -- >= 0,   second sum and optional rounding
		);
		PORT(
			rst   : IN  STD_LOGIC := '0';
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			res   : OUT STD_LOGIC_VECTOR(g_res_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	-----------------------------------------------------------------------------
	-- Arria 10 components
	-----------------------------------------------------------------------------

	COMPONENT ip_arria10_complex_mult is
		PORT(
			dataa_real  : in  std_logic_vector(17 downto 0) := (others => '0'); --  complex_input.dataa_real
			dataa_imag  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .dataa_imag
			datab_real  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .datab_real
			datab_imag  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .datab_imag
			clock       : in  std_logic                     := '0'; --               .clk
			aclr        : in  std_logic                     := '0'; --               .aclr
			ena         : in  std_logic                     := '0'; --               .ena
			result_real : out std_logic_vector(35 downto 0); -- complex_output.result_real
			result_imag : out std_logic_vector(35 downto 0) --               .result_imag
		);
	END COMPONENT;

	COMPONENT ip_arria10_complex_mult_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18;
			g_in_b_w           : POSITIVE := 18;
			g_out_p_w          : POSITIVE := 36;
			g_conjugate_b      : BOOLEAN  := FALSE;
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1 -- >= 0
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
	END COMPONENT;

	COMPONENT ip_arria10_complex_mult_rtl_canonical IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_out_p_w          : POSITIVE; -- default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
			--    g_conjugate_b      : BOOLEAN := FALSE;
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
	END COMPONENT;

	COMPONENT ip_arria10_mult IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18; -- Width of the data A port
			g_in_b_w           : POSITIVE := 18; -- Width of the data B port
			g_out_p_w          : POSITIVE := 36; -- Width of the result port
			g_nof_mult         : POSITIVE := 1; -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1; -- >= 0
			g_representation   : STRING   := "SIGNED" -- or "UNSIGNED"
		);
		PORT(
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			out_p : OUT STD_LOGIC_VECTOR(g_nof_mult * (g_in_a_w + g_in_b_w) - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_arria10_mult_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE := 18;
			g_in_b_w           : POSITIVE := 18;
			g_out_p_w          : POSITIVE := 36; -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
			g_nof_mult         : POSITIVE := 1; -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
			g_pipeline_input   : NATURAL  := 1; -- 0 or 1
			g_pipeline_product : NATURAL  := 1; -- 0 or 1
			g_pipeline_output  : NATURAL  := 1; -- >= 0
			g_representation   : STRING   := "SIGNED" -- or "UNSIGNED"
		);
		PORT(
			rst   : IN  STD_LOGIC;
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			out_p : OUT STD_LOGIC_VECTOR(g_nof_mult * (g_in_a_w + g_in_b_w) - 1 DOWNTO 0)
		);
	END COMPONENT;

	-----------------------------------------------------------------------------
	-- Arria 10 e3sge3 components
	-----------------------------------------------------------------------------

	COMPONENT ip_arria10_e3sge3_mult_add4_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_res_w            : POSITIVE; -- g_in_a_w + g_in_b_w + log2(4)
			g_force_dsp        : BOOLEAN := TRUE; -- when TRUE resize input width to >= 18
			g_add_sub0         : STRING  := "ADD"; -- or "SUB"
			g_add_sub1         : STRING  := "ADD"; -- or "SUB"
			g_add_sub          : STRING  := "ADD"; -- or "SUB" only available with rtl architecture
			g_nof_mult         : INTEGER := 4; -- fixed
			g_pipeline_input   : NATURAL := 1; -- 0 or 1
			g_pipeline_product : NATURAL := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL := 1; -- 0 or 1, first sum
			g_pipeline_output  : NATURAL := 1 -- >= 0,   second sum and optional rounding
		);
		PORT(
			rst   : IN  STD_LOGIC := '0';
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			res   : OUT STD_LOGIC_VECTOR(g_res_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	-----------------------------------------------------------------------------
	-- Arria 10 e1sg components
	-----------------------------------------------------------------------------
	COMPONENT ip_arria10_e1sg_mult_add2_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_res_w            : POSITIVE; -- g_in_a_w + g_in_b_w + log2(2)
			g_force_dsp        : BOOLEAN := TRUE; -- when TRUE resize input width to >= 18
			g_add_sub          : STRING  := "ADD"; -- or "SUB"
			g_nof_mult         : INTEGER := 2; -- fixed
			g_pipeline_input   : NATURAL := 1; -- 0 or 1
			g_pipeline_product : NATURAL := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL := 1; -- 0 or 1
			g_pipeline_output  : NATURAL := 1 -- >= 0
		);
		PORT(
			rst   : IN  STD_LOGIC := '0';
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			res   : OUT STD_LOGIC_VECTOR(g_res_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_arria10_e1sg_mult_add4_rtl IS
		GENERIC(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_res_w            : POSITIVE; -- g_in_a_w + g_in_b_w + log2(4)
			g_force_dsp        : BOOLEAN := TRUE; -- when TRUE resize input width to >= 18
			g_add_sub0         : STRING  := "ADD"; -- or "SUB"
			g_add_sub1         : STRING  := "ADD"; -- or "SUB"
			g_add_sub          : STRING  := "ADD"; -- or "SUB" only available with rtl architecture
			g_nof_mult         : INTEGER := 4; -- fixed
			g_pipeline_input   : NATURAL := 1; -- 0 or 1
			g_pipeline_product : NATURAL := 0; -- 0 or 1
			g_pipeline_adder   : NATURAL := 1; -- 0 or 1, first sum
			g_pipeline_output  : NATURAL := 1 -- >= 0,   second sum and optional rounding
		);
		PORT(
			rst   : IN  STD_LOGIC := '0';
			clk   : IN  STD_LOGIC;
			clken : IN  STD_LOGIC := '1';
			in_a  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_a_w - 1 DOWNTO 0);
			in_b  : IN  STD_LOGIC_VECTOR(g_nof_mult * g_in_b_w - 1 DOWNTO 0);
			res   : OUT STD_LOGIC_VECTOR(g_res_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_arria10_e1sg_complex_mult is
		PORT(
			dataa_real  : in  std_logic_vector(17 downto 0) := (others => '0'); --  complex_input.dataa_real
			dataa_imag  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .dataa_imag
			datab_real  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .datab_real
			datab_imag  : in  std_logic_vector(17 downto 0) := (others => '0'); --               .datab_imag
			clock       : in  std_logic                     := '0'; --               .clk
			aclr        : in  std_logic                     := '0'; --               .aclr
			ena         : in  std_logic                     := '0'; --               .ena
			result_real : out std_logic_vector(35 downto 0); -- complex_output.result_real
			result_imag : out std_logic_vector(35 downto 0) --               .result_imag
		);
	END COMPONENT;
END tech_mult_component_pkg;
