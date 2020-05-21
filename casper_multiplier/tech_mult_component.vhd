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

--! Purpose: IP components declarations for various devices that get wrapped by the tech components

LIBRARY IEEE,ip_xilinx_mult_lib;
USE IEEE.STD_LOGIC_1164.ALL;
use ip_xilinx_mult_lib.all;
PACKAGE tech_mult_component_pkg IS

	-----------------------------------------------------------------------------
	-- Xilinx 7 Series Mults
	-----------------------------------------------------------------------------
	--! Complex multiplier allowing for signed/unsigned multiplication with option to conjugate b input. Does not translate to DSP element.
		COMPONENT ip_cmult_rtl IS
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
	
	--! Complex multiplier that infers DSP element on 7 series Xilinx chips.
	component ip_cmult_infer
		generic(
			AWIDTH : natural;
			BWIDTH : natural
		);
		port(
			clk    : in  std_logic;
			ar, ai : in  std_logic_vector(AWIDTH - 1 downto 0);
			br, bi : in  std_logic_vector(BWIDTH - 1 downto 0);
			rst    : in  std_logic;
			clken  : in  std_logic;
			pr, pi : out std_logic_vector(AWIDTH + BWIDTH downto 0)
		);
	end component ip_cmult_infer;
	
	--! Real multiplier that infers DSP element on 7 series Xilinx chips. 
	component ip_mult_infer
		generic(
			AWIDTH : natural;
			BWIDTH : natural
		);
		port(
			a   : in  std_logic_vector(AWIDTH - 1 downto 0);
			b   : in  std_logic_vector(BWIDTH - 1 downto 0);
			clk : in  std_logic;
			rst : in  std_logic;
			ce  : in  std_logic;
			p   : out std_logic_vector(AWIDTH + BWIDTH - 1 downto 0)
		);
	end component ip_mult_infer;
END tech_mult_component_pkg;
