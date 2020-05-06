-- megafunction wizard: %ALTMULT_COMPLEX%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altmult_complex 

-- ============================================================
-- File Name: ip_stratixiv_complex_mult.vhd
-- Megafunction Name(s):
-- 			altmult_complex
--
-- Simulation Library Files(s):
-- 			altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 10.0 Build 218 06/27/2010 SJ Full Version
-- ************************************************************

--Copyright (C) 1991-2010 Altera Corporation
--Your use of Altera Corporation's design tools, logic functions 
--and other software and tools, and its AMPP partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Altera Program License 
--Subscription Agreement, Altera MegaCore Function License 
--Agreement, or other applicable license agreement, including, 
--without limitation, that your use is for the sole purpose of 
--programming logic devices manufactured by Altera and sold by 
--Altera or its authorized distributors.  Please refer to the 
--applicable agreement for further details.

--altmult_complex CBX_AUTO_BLACKBOX="ALL" DEVICE_FAMILY="Stratix IV" IMPLEMENTATION_STYLE="AUTO" PIPELINE=3 REPRESENTATION_A="SIGNED" REPRESENTATION_B="SIGNED" WIDTH_A=18 WIDTH_B=18 WIDTH_RESULT=36 aclr clock dataa_imag dataa_real datab_imag datab_real ena result_imag result_real
--VERSION_BEGIN 10.0 cbx_alt_ded_mult_y 2010:06:27:21:21:57:SJ cbx_altmult_add 2010:06:27:21:21:57:SJ cbx_altmult_complex 2010:06:27:21:21:57:SJ cbx_cycloneii 2010:06:27:21:21:57:SJ cbx_lpm_add_sub 2010:06:27:21:21:57:SJ cbx_lpm_compare 2010:06:27:21:21:57:SJ cbx_lpm_mult 2010:06:27:21:21:57:SJ cbx_mgl 2010:06:27:21:25:48:SJ cbx_padd 2010:06:27:21:21:57:SJ cbx_parallel_add 2010:06:27:21:21:57:SJ cbx_stratix 2010:06:27:21:21:57:SJ cbx_stratixii 2010:06:27:21:21:57:SJ cbx_stratixv 2010:06:27:21:21:57:SJ cbx_util_mgl 2010:06:27:21:21:57:SJ  VERSION_END

LIBRARY altera_mf;
USE altera_mf.all;

--synthesis_resources = altmult_add 2 
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ip_stratixiv_complex_mult_altmult_complex_0vp IS
	PORT(
		aclr        : IN  STD_LOGIC := '0';
		clock       : IN  STD_LOGIC := '0';
		dataa_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		dataa_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		datab_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		datab_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
		ena         : IN  STD_LOGIC := '1';
		result_imag : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		result_real : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
	);
END ip_stratixiv_complex_mult_altmult_complex_0vp;

ARCHITECTURE RTL OF ip_stratixiv_complex_mult_altmult_complex_0vp IS

	SIGNAL wire_mult_add1_result : STD_LOGIC_VECTOR(35 DOWNTO 0);
	SIGNAL wire_mult_add2_result : STD_LOGIC_VECTOR(35 DOWNTO 0);
	SIGNAL mult_add1_inputa      : STD_LOGIC_VECTOR(35 DOWNTO 0);
	SIGNAL mult_add1_inputb      : STD_LOGIC_VECTOR(35 DOWNTO 0);
	SIGNAL mult_add2_inputb      : STD_LOGIC_VECTOR(35 DOWNTO 0);
	COMPONENT altmult_add
		GENERIC(
			ACCUM_DIRECTION                       : STRING  := "ADD";
			ACCUM_SLOAD_ACLR                      : STRING  := "ACLR0";
			ACCUM_SLOAD_PIPELINE_ACLR             : STRING  := "ACLR0";
			ACCUM_SLOAD_PIPELINE_REGISTER         : STRING  := "CLOCK0";
			ACCUM_SLOAD_REGISTER                  : STRING  := "CLOCK0";
			ACCUMULATOR                           : STRING  := "NO";
			ADDER1_ROUNDING                       : STRING  := "NO";
			ADDER3_ROUNDING                       : STRING  := "NO";
			ADDNSUB1_ROUND_ACLR                   : STRING  := "ACLR0";
			ADDNSUB1_ROUND_PIPELINE_ACLR          : STRING  := "ACLR0";
			ADDNSUB1_ROUND_PIPELINE_REGISTER      : STRING  := "CLOCK0";
			ADDNSUB1_ROUND_REGISTER               : STRING  := "CLOCK0";
			ADDNSUB3_ROUND_ACLR                   : STRING  := "ACLR0";
			ADDNSUB3_ROUND_PIPELINE_ACLR          : STRING  := "ACLR0";
			ADDNSUB3_ROUND_PIPELINE_REGISTER      : STRING  := "CLOCK0";
			ADDNSUB3_ROUND_REGISTER               : STRING  := "CLOCK0";
			ADDNSUB_MULTIPLIER_ACLR1              : STRING  := "ACLR0";
			ADDNSUB_MULTIPLIER_ACLR3              : STRING  := "ACLR0";
			ADDNSUB_MULTIPLIER_PIPELINE_ACLR1     : STRING  := "ACLR0";
			ADDNSUB_MULTIPLIER_PIPELINE_ACLR3     : STRING  := "ACLR0";
			ADDNSUB_MULTIPLIER_PIPELINE_REGISTER1 : STRING  := "CLOCK0";
			ADDNSUB_MULTIPLIER_PIPELINE_REGISTER3 : STRING  := "CLOCK0";
			ADDNSUB_MULTIPLIER_REGISTER1          : STRING  := "CLOCK0";
			ADDNSUB_MULTIPLIER_REGISTER3          : STRING  := "CLOCK0";
			CHAINOUT_ACLR                         : STRING  := "ACLR0";
			CHAINOUT_ADDER                        : STRING  := "NO";
			CHAINOUT_REGISTER                     : STRING  := "CLOCK0";
			CHAINOUT_ROUND_ACLR                   : STRING  := "ACLR0";
			CHAINOUT_ROUND_OUTPUT_ACLR            : STRING  := "ACLR0";
			CHAINOUT_ROUND_OUTPUT_REGISTER        : STRING  := "CLOCK0";
			CHAINOUT_ROUND_PIPELINE_ACLR          : STRING  := "ACLR0";
			CHAINOUT_ROUND_PIPELINE_REGISTER      : STRING  := "CLOCK0";
			CHAINOUT_ROUND_REGISTER               : STRING  := "CLOCK0";
			CHAINOUT_ROUNDING                     : STRING  := "NO";
			CHAINOUT_SATURATE_ACLR                : STRING  := "ACLR0";
			CHAINOUT_SATURATE_OUTPUT_ACLR         : STRING  := "ACLR0";
			CHAINOUT_SATURATE_OUTPUT_REGISTER     : STRING  := "CLOCK0";
			CHAINOUT_SATURATE_PIPELINE_ACLR       : STRING  := "ACLR0";
			CHAINOUT_SATURATE_PIPELINE_REGISTER   : STRING  := "CLOCK0";
			CHAINOUT_SATURATE_REGISTER            : STRING  := "CLOCK0";
			CHAINOUT_SATURATION                   : STRING  := "NO";
			COEF0_0                               : NATURAL := 0;
			COEF0_1                               : NATURAL := 0;
			COEF0_2                               : NATURAL := 0;
			COEF0_3                               : NATURAL := 0;
			COEF0_4                               : NATURAL := 0;
			COEF0_5                               : NATURAL := 0;
			COEF0_6                               : NATURAL := 0;
			COEF0_7                               : NATURAL := 0;
			COEF1_0                               : NATURAL := 0;
			COEF1_1                               : NATURAL := 0;
			COEF1_2                               : NATURAL := 0;
			COEF1_3                               : NATURAL := 0;
			COEF1_4                               : NATURAL := 0;
			COEF1_5                               : NATURAL := 0;
			COEF1_6                               : NATURAL := 0;
			COEF1_7                               : NATURAL := 0;
			COEF2_0                               : NATURAL := 0;
			COEF2_1                               : NATURAL := 0;
			COEF2_2                               : NATURAL := 0;
			COEF2_3                               : NATURAL := 0;
			COEF2_4                               : NATURAL := 0;
			COEF2_5                               : NATURAL := 0;
			COEF2_6                               : NATURAL := 0;
			COEF2_7                               : NATURAL := 0;
			COEF3_0                               : NATURAL := 0;
			COEF3_1                               : NATURAL := 0;
			COEF3_2                               : NATURAL := 0;
			COEF3_3                               : NATURAL := 0;
			COEF3_4                               : NATURAL := 0;
			COEF3_5                               : NATURAL := 0;
			COEF3_6                               : NATURAL := 0;
			COEF3_7                               : NATURAL := 0;
			COEFSEL0_ACLR                         : STRING  := "ACLR0";
			COEFSEL0_REGISTER                     : STRING  := "CLOCK0";
			COEFSEL1_ACLR                         : STRING  := "ACLR0";
			COEFSEL1_REGISTER                     : STRING  := "CLOCK0";
			COEFSEL2_ACLR                         : STRING  := "ACLR0";
			COEFSEL2_REGISTER                     : STRING  := "CLOCK0";
			COEFSEL3_ACLR                         : STRING  := "ACLR0";
			COEFSEL3_REGISTER                     : STRING  := "CLOCK0";
			DEDICATED_MULTIPLIER_CIRCUITRY        : STRING  := "AUTO";
			DSP_BLOCK_BALANCING                   : STRING  := "Auto";
			EXTRA_LATENCY                         : NATURAL := 0;
			INPUT_ACLR_A0                         : STRING  := "ACLR0";
			INPUT_ACLR_A1                         : STRING  := "ACLR0";
			INPUT_ACLR_A2                         : STRING  := "ACLR0";
			INPUT_ACLR_A3                         : STRING  := "ACLR0";
			INPUT_ACLR_B0                         : STRING  := "ACLR0";
			INPUT_ACLR_B1                         : STRING  := "ACLR0";
			INPUT_ACLR_B2                         : STRING  := "ACLR0";
			INPUT_ACLR_B3                         : STRING  := "ACLR0";
			INPUT_ACLR_C0                         : STRING  := "ACLR0";
			INPUT_REGISTER_A0                     : STRING  := "CLOCK0";
			INPUT_REGISTER_A1                     : STRING  := "CLOCK0";
			INPUT_REGISTER_A2                     : STRING  := "CLOCK0";
			INPUT_REGISTER_A3                     : STRING  := "CLOCK0";
			INPUT_REGISTER_B0                     : STRING  := "CLOCK0";
			INPUT_REGISTER_B1                     : STRING  := "CLOCK0";
			INPUT_REGISTER_B2                     : STRING  := "CLOCK0";
			INPUT_REGISTER_B3                     : STRING  := "CLOCK0";
			INPUT_REGISTER_C0                     : STRING  := "CLOCK0";
			INPUT_SOURCE_A0                       : STRING  := "DATAA";
			INPUT_SOURCE_A1                       : STRING  := "DATAA";
			INPUT_SOURCE_A2                       : STRING  := "DATAA";
			INPUT_SOURCE_A3                       : STRING  := "DATAA";
			INPUT_SOURCE_B0                       : STRING  := "DATAB";
			INPUT_SOURCE_B1                       : STRING  := "DATAB";
			INPUT_SOURCE_B2                       : STRING  := "DATAB";
			INPUT_SOURCE_B3                       : STRING  := "DATAB";
			LOADCONST_VALUE                       : NATURAL := 64;
			MULT01_ROUND_ACLR                     : STRING  := "ACLR0";
			MULT01_ROUND_REGISTER                 : STRING  := "CLOCK0";
			MULT01_SATURATION_ACLR                : STRING  := "ACLR1";
			MULT01_SATURATION_REGISTER            : STRING  := "CLOCK0";
			MULT23_ROUND_ACLR                     : STRING  := "ACLR0";
			MULT23_ROUND_REGISTER                 : STRING  := "CLOCK0";
			MULT23_SATURATION_ACLR                : STRING  := "ACLR0";
			MULT23_SATURATION_REGISTER            : STRING  := "CLOCK0";
			MULTIPLIER01_ROUNDING                 : STRING  := "NO";
			MULTIPLIER01_SATURATION               : STRING  := "NO";
			MULTIPLIER1_DIRECTION                 : STRING  := "ADD";
			MULTIPLIER23_ROUNDING                 : STRING  := "NO";
			MULTIPLIER23_SATURATION               : STRING  := "NO";
			MULTIPLIER3_DIRECTION                 : STRING  := "ADD";
			MULTIPLIER_ACLR0                      : STRING  := "ACLR0";
			MULTIPLIER_ACLR1                      : STRING  := "ACLR0";
			MULTIPLIER_ACLR2                      : STRING  := "ACLR0";
			MULTIPLIER_ACLR3                      : STRING  := "ACLR0";
			MULTIPLIER_REGISTER0                  : STRING  := "CLOCK0";
			MULTIPLIER_REGISTER1                  : STRING  := "CLOCK0";
			MULTIPLIER_REGISTER2                  : STRING  := "CLOCK0";
			MULTIPLIER_REGISTER3                  : STRING  := "CLOCK0";
			NUMBER_OF_MULTIPLIERS                 : NATURAL;
			OUTPUT_ACLR                           : STRING  := "ACLR0";
			OUTPUT_REGISTER                       : STRING  := "CLOCK0";
			OUTPUT_ROUND_ACLR                     : STRING  := "ACLR0";
			OUTPUT_ROUND_PIPELINE_ACLR            : STRING  := "ACLR0";
			OUTPUT_ROUND_PIPELINE_REGISTER        : STRING  := "CLOCK0";
			OUTPUT_ROUND_REGISTER                 : STRING  := "CLOCK0";
			OUTPUT_ROUND_TYPE                     : STRING  := "NEAREST_INTEGER";
			OUTPUT_ROUNDING                       : STRING  := "NO";
			OUTPUT_SATURATE_ACLR                  : STRING  := "ACLR0";
			OUTPUT_SATURATE_PIPELINE_ACLR         : STRING  := "ACLR0";
			OUTPUT_SATURATE_PIPELINE_REGISTER     : STRING  := "CLOCK0";
			OUTPUT_SATURATE_REGISTER              : STRING  := "CLOCK0";
			OUTPUT_SATURATE_TYPE                  : STRING  := "ASYMMETRIC";
			OUTPUT_SATURATION                     : STRING  := "NO";
			port_addnsub1                         : STRING  := "PORT_CONNECTIVITY";
			port_addnsub3                         : STRING  := "PORT_CONNECTIVITY";
			PORT_CHAINOUT_SAT_IS_OVERFLOW         : STRING  := "PORT_UNUSED";
			PORT_MULT0_IS_SATURATED               : STRING  := "UNUSED";
			PORT_MULT1_IS_SATURATED               : STRING  := "UNUSED";
			PORT_MULT2_IS_SATURATED               : STRING  := "UNUSED";
			PORT_MULT3_IS_SATURATED               : STRING  := "UNUSED";
			PORT_OUTPUT_IS_OVERFLOW               : STRING  := "PORT_UNUSED";
			port_signa                            : STRING  := "PORT_CONNECTIVITY";
			port_signb                            : STRING  := "PORT_CONNECTIVITY";
			PREADDER_DIRECTION_0                  : STRING  := "ADD";
			PREADDER_DIRECTION_1                  : STRING  := "ADD";
			PREADDER_DIRECTION_2                  : STRING  := "ADD";
			PREADDER_DIRECTION_3                  : STRING  := "ADD";
			PREADDER_MODE                         : STRING  := "SIMPLE";
			REPRESENTATION_A                      : STRING  := "UNSIGNED";
			REPRESENTATION_B                      : STRING  := "UNSIGNED";
			ROTATE_ACLR                           : STRING  := "ACLR0";
			ROTATE_OUTPUT_ACLR                    : STRING  := "ACLR0";
			ROTATE_OUTPUT_REGISTER                : STRING  := "CLOCK0";
			ROTATE_PIPELINE_ACLR                  : STRING  := "ACLR0";
			ROTATE_PIPELINE_REGISTER              : STRING  := "CLOCK0";
			ROTATE_REGISTER                       : STRING  := "CLOCK0";
			SCANOUTA_ACLR                         : STRING  := "ACLR0";
			SCANOUTA_REGISTER                     : STRING  := "UNREGISTERED";
			SHIFT_MODE                            : STRING  := "NO";
			SHIFT_RIGHT_ACLR                      : STRING  := "ACLR0";
			SHIFT_RIGHT_OUTPUT_ACLR               : STRING  := "ACLR0";
			SHIFT_RIGHT_OUTPUT_REGISTER           : STRING  := "CLOCK0";
			SHIFT_RIGHT_PIPELINE_ACLR             : STRING  := "ACLR0";
			SHIFT_RIGHT_PIPELINE_REGISTER         : STRING  := "CLOCK0";
			SHIFT_RIGHT_REGISTER                  : STRING  := "CLOCK0";
			SIGNED_ACLR_A                         : STRING  := "ACLR0";
			SIGNED_ACLR_B                         : STRING  := "ACLR0";
			SIGNED_PIPELINE_ACLR_A                : STRING  := "ACLR0";
			SIGNED_PIPELINE_ACLR_B                : STRING  := "ACLR0";
			SIGNED_PIPELINE_REGISTER_A            : STRING  := "CLOCK0";
			SIGNED_PIPELINE_REGISTER_B            : STRING  := "CLOCK0";
			SIGNED_REGISTER_A                     : STRING  := "CLOCK0";
			SIGNED_REGISTER_B                     : STRING  := "CLOCK0";
			SYSTOLIC_ACLR1                        : STRING  := "ACLR0";
			SYSTOLIC_ACLR3                        : STRING  := "ACLR0";
			SYSTOLIC_DELAY1                       : STRING  := "UNREGISTERED";
			SYSTOLIC_DELAY3                       : STRING  := "UNREGISTERED";
			WIDTH_A                               : NATURAL;
			WIDTH_B                               : NATURAL;
			WIDTH_C                               : NATURAL := 22;
			WIDTH_CHAININ                         : NATURAL := 1;
			WIDTH_COEF                            : NATURAL := 18;
			WIDTH_MSB                             : NATURAL := 17;
			WIDTH_RESULT                          : NATURAL;
			WIDTH_SATURATE_SIGN                   : NATURAL := 1;
			ZERO_CHAINOUT_OUTPUT_ACLR             : STRING  := "ACLR0";
			ZERO_CHAINOUT_OUTPUT_REGISTER         : STRING  := "CLOCK0";
			ZERO_LOOPBACK_ACLR                    : STRING  := "ACLR0";
			ZERO_LOOPBACK_OUTPUT_ACLR             : STRING  := "ACLR0";
			ZERO_LOOPBACK_OUTPUT_REGISTER         : STRING  := "CLOCK0";
			ZERO_LOOPBACK_PIPELINE_ACLR           : STRING  := "ACLR0";
			ZERO_LOOPBACK_PIPELINE_REGISTER       : STRING  := "CLOCK0";
			ZERO_LOOPBACK_REGISTER                : STRING  := "CLOCK0";
			lpm_hint                              : STRING  := "UNUSED";
			lpm_type                              : STRING  := "altmult_add"
		);
		PORT(
			accum_sload           : IN  STD_LOGIC                                                      := '0';
			aclr0                 : IN  STD_LOGIC                                                      := '0';
			aclr1                 : IN  STD_LOGIC                                                      := '0';
			aclr2                 : IN  STD_LOGIC                                                      := '0';
			aclr3                 : IN  STD_LOGIC                                                      := '0';
			addnsub1              : IN  STD_LOGIC                                                      := '1';
			addnsub1_round        : IN  STD_LOGIC                                                      := '0';
			addnsub3              : IN  STD_LOGIC                                                      := '1';
			addnsub3_round        : IN  STD_LOGIC                                                      := '0';
			chainin               : IN  STD_LOGIC_VECTOR(WIDTH_CHAININ - 1 DOWNTO 0)                   := (OTHERS => '0');
			chainout_round        : IN  STD_LOGIC                                                      := '0';
			chainout_sat_overflow : OUT STD_LOGIC;
			chainout_saturate     : IN  STD_LOGIC                                                      := '0';
			clock0                : IN  STD_LOGIC                                                      := '1';
			clock1                : IN  STD_LOGIC                                                      := '1';
			clock2                : IN  STD_LOGIC                                                      := '1';
			clock3                : IN  STD_LOGIC                                                      := '1';
			coefsel0              : IN  STD_LOGIC_VECTOR(2 DOWNTO 0)                                   := (OTHERS => '0');
			coefsel1              : IN  STD_LOGIC_VECTOR(2 DOWNTO 0)                                   := (OTHERS => '0');
			coefsel2              : IN  STD_LOGIC_VECTOR(2 DOWNTO 0)                                   := (OTHERS => '0');
			coefsel3              : IN  STD_LOGIC_VECTOR(2 DOWNTO 0)                                   := (OTHERS => '0');
			dataa                 : IN  STD_LOGIC_VECTOR(WIDTH_A * NUMBER_OF_MULTIPLIERS - 1 DOWNTO 0) := (OTHERS => '0');
			datab                 : IN  STD_LOGIC_VECTOR(WIDTH_B * NUMBER_OF_MULTIPLIERS - 1 DOWNTO 0) := (OTHERS => '0');
			datac                 : IN  STD_LOGIC_VECTOR(WIDTH_C - 1 DOWNTO 0)                         := (OTHERS => '0');
			ena0                  : IN  STD_LOGIC                                                      := '1';
			ena1                  : IN  STD_LOGIC                                                      := '1';
			ena2                  : IN  STD_LOGIC                                                      := '1';
			ena3                  : IN  STD_LOGIC                                                      := '1';
			mult01_round          : IN  STD_LOGIC                                                      := '0';
			mult01_saturation     : IN  STD_LOGIC                                                      := '0';
			mult0_is_saturated    : OUT STD_LOGIC;
			mult1_is_saturated    : OUT STD_LOGIC;
			mult23_round          : IN  STD_LOGIC                                                      := '0';
			mult23_saturation     : IN  STD_LOGIC                                                      := '0';
			mult2_is_saturated    : OUT STD_LOGIC;
			mult3_is_saturated    : OUT STD_LOGIC;
			output_round          : IN  STD_LOGIC                                                      := '0';
			output_saturate       : IN  STD_LOGIC                                                      := '0';
			overflow              : OUT STD_LOGIC;
			result                : OUT STD_LOGIC_VECTOR(WIDTH_RESULT - 1 DOWNTO 0);
			rotate                : IN  STD_LOGIC                                                      := '0';
			scanina               : IN  STD_LOGIC_VECTOR(WIDTH_A - 1 DOWNTO 0)                         := (OTHERS => '0');
			scaninb               : IN  STD_LOGIC_VECTOR(WIDTH_B - 1 DOWNTO 0)                         := (OTHERS => '0');
			scanouta              : OUT STD_LOGIC_VECTOR(WIDTH_A - 1 DOWNTO 0);
			scanoutb              : OUT STD_LOGIC_VECTOR(WIDTH_B - 1 DOWNTO 0);
			shift_right           : IN  STD_LOGIC                                                      := '0';
			signa                 : IN  STD_LOGIC                                                      := '0';
			signb                 : IN  STD_LOGIC                                                      := '0';
			sourcea               : IN  STD_LOGIC_VECTOR(NUMBER_OF_MULTIPLIERS - 1 DOWNTO 0)           := (OTHERS => '0');
			sourceb               : IN  STD_LOGIC_VECTOR(NUMBER_OF_MULTIPLIERS - 1 DOWNTO 0)           := (OTHERS => '0');
			zero_chainout         : IN  STD_LOGIC                                                      := '0';
			zero_loopback         : IN  STD_LOGIC                                                      := '0'
		);
	END COMPONENT;
BEGIN

	mult_add1_inputa <= (dataa_imag(17 DOWNTO 0) & dataa_real(17 DOWNTO 0));
	mult_add1_inputb <= (datab_imag(17 DOWNTO 0) & datab_real(17 DOWNTO 0));
	mult_add2_inputb <= (datab_real(17 DOWNTO 0) & datab_imag(17 DOWNTO 0));
	result_imag      <= wire_mult_add2_result;
	result_real      <= wire_mult_add1_result;
	mult_add1 : altmult_add
		GENERIC MAP(
			INPUT_ACLR_A0         => "ACLR0",
			INPUT_ACLR_A1         => "ACLR0",
			INPUT_ACLR_B0         => "ACLR0",
			INPUT_ACLR_B1         => "ACLR0",
			INPUT_REGISTER_A0     => "CLOCK0",
			INPUT_REGISTER_A1     => "CLOCK0",
			INPUT_REGISTER_B0     => "CLOCK0",
			INPUT_REGISTER_B1     => "CLOCK0",
			MULTIPLIER1_DIRECTION => "SUB",
			MULTIPLIER_ACLR0      => "ACLR0",
			MULTIPLIER_ACLR1      => "ACLR0",
			MULTIPLIER_REGISTER0  => "CLOCK0",
			MULTIPLIER_REGISTER1  => "CLOCK0",
			NUMBER_OF_MULTIPLIERS => 2,
			OUTPUT_ACLR           => "ACLR0",
			OUTPUT_REGISTER       => "CLOCK0",
			port_addnsub1         => "PORT_UNUSED",
			port_signa            => "PORT_UNUSED",
			port_signb            => "PORT_UNUSED",
			REPRESENTATION_A      => "SIGNED",
			REPRESENTATION_B      => "SIGNED",
			WIDTH_A               => 18,
			WIDTH_B               => 18,
			WIDTH_RESULT          => 36
		)
		PORT MAP(
			aclr0  => aclr,
			clock0 => clock,
			dataa  => mult_add1_inputa,
			datab  => mult_add1_inputb,
			ena0   => ena,
			result => wire_mult_add1_result
		);
	mult_add2 : altmult_add
		GENERIC MAP(
			INPUT_ACLR_A0         => "ACLR0",
			INPUT_ACLR_A1         => "ACLR0",
			INPUT_ACLR_B0         => "ACLR0",
			INPUT_ACLR_B1         => "ACLR0",
			INPUT_REGISTER_A0     => "CLOCK0",
			INPUT_REGISTER_A1     => "CLOCK0",
			INPUT_REGISTER_B0     => "CLOCK0",
			INPUT_REGISTER_B1     => "CLOCK0",
			MULTIPLIER1_DIRECTION => "ADD",
			MULTIPLIER_ACLR0      => "ACLR0",
			MULTIPLIER_ACLR1      => "ACLR0",
			MULTIPLIER_REGISTER0  => "CLOCK0",
			MULTIPLIER_REGISTER1  => "CLOCK0",
			NUMBER_OF_MULTIPLIERS => 2,
			OUTPUT_ACLR           => "ACLR0",
			OUTPUT_REGISTER       => "CLOCK0",
			port_addnsub1         => "PORT_UNUSED",
			port_signa            => "PORT_UNUSED",
			port_signb            => "PORT_UNUSED",
			REPRESENTATION_A      => "SIGNED",
			REPRESENTATION_B      => "SIGNED",
			WIDTH_A               => 18,
			WIDTH_B               => 18,
			WIDTH_RESULT          => 36
		)
		PORT MAP(
			aclr0  => aclr,
			clock0 => clock,
			dataa  => mult_add1_inputa,
			datab  => mult_add2_inputb,
			ena0   => ena,
			result => wire_mult_add2_result
		);

END RTL;                                --ip_stratixiv_complex_mult_altmult_complex_0vp
--VALID FILE

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ip_stratixiv_complex_mult IS
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
END ip_stratixiv_complex_mult;

ARCHITECTURE RTL OF ip_stratixiv_complex_mult IS

	SIGNAL sub_wire0 : STD_LOGIC_VECTOR(35 DOWNTO 0);
	SIGNAL sub_wire1 : STD_LOGIC_VECTOR(35 DOWNTO 0);

	COMPONENT ip_stratixiv_complex_mult_altmult_complex_0vp
		PORT(
			clock       : IN  STD_LOGIC;
			dataa_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			ena         : IN  STD_LOGIC;
			result_imag : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
			datab_imag  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			datab_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			aclr        : IN  STD_LOGIC;
			dataa_real  : IN  STD_LOGIC_VECTOR(17 DOWNTO 0);
			result_real : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
		);
	END COMPONENT;

BEGIN
	result_imag <= sub_wire0(35 DOWNTO 0);
	result_real <= sub_wire1(35 DOWNTO 0);

	ip_stratixiv_complex_mult_altmult_complex_0vp_component : ip_stratixiv_complex_mult_altmult_complex_0vp
		PORT MAP(
			clock       => clock,
			dataa_imag  => dataa_imag,
			ena         => ena,
			datab_imag  => datab_imag,
			datab_real  => datab_real,
			aclr        => aclr,
			dataa_real  => dataa_real,
			result_imag => sub_wire0,
			result_real => sub_wire1
		);

END RTL;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Stratix IV"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: IMPLEMENTATION_STYLE STRING "AUTO"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Stratix IV"
-- Retrieval info: CONSTANT: PIPELINE NUMERIC "3"
-- Retrieval info: CONSTANT: REPRESENTATION_A STRING "SIGNED"
-- Retrieval info: CONSTANT: REPRESENTATION_B STRING "SIGNED"
-- Retrieval info: CONSTANT: WIDTH_A NUMERIC "18"
-- Retrieval info: CONSTANT: WIDTH_B NUMERIC "18"
-- Retrieval info: CONSTANT: WIDTH_RESULT NUMERIC "36"
-- Retrieval info: USED_PORT: aclr 0 0 0 0 INPUT NODEFVAL "aclr"
-- Retrieval info: USED_PORT: clock 0 0 0 0 INPUT NODEFVAL "clock"
-- Retrieval info: USED_PORT: dataa_imag 0 0 18 0 INPUT NODEFVAL "dataa_imag[17..0]"
-- Retrieval info: USED_PORT: dataa_real 0 0 18 0 INPUT NODEFVAL "dataa_real[17..0]"
-- Retrieval info: USED_PORT: datab_imag 0 0 18 0 INPUT NODEFVAL "datab_imag[17..0]"
-- Retrieval info: USED_PORT: datab_real 0 0 18 0 INPUT NODEFVAL "datab_real[17..0]"
-- Retrieval info: USED_PORT: ena 0 0 0 0 INPUT NODEFVAL "ena"
-- Retrieval info: USED_PORT: result_imag 0 0 36 0 OUTPUT NODEFVAL "result_imag[35..0]"
-- Retrieval info: USED_PORT: result_real 0 0 36 0 OUTPUT NODEFVAL "result_real[35..0]"
-- Retrieval info: CONNECT: @aclr 0 0 0 0 aclr 0 0 0 0
-- Retrieval info: CONNECT: @clock 0 0 0 0 clock 0 0 0 0
-- Retrieval info: CONNECT: @dataa_imag 0 0 18 0 dataa_imag 0 0 18 0
-- Retrieval info: CONNECT: @dataa_real 0 0 18 0 dataa_real 0 0 18 0
-- Retrieval info: CONNECT: @datab_imag 0 0 18 0 datab_imag 0 0 18 0
-- Retrieval info: CONNECT: @datab_real 0 0 18 0 datab_real 0 0 18 0
-- Retrieval info: CONNECT: @ena 0 0 0 0 ena 0 0 0 0
-- Retrieval info: CONNECT: result_imag 0 0 36 0 @result_imag 0 0 36 0
-- Retrieval info: CONNECT: result_real 0 0 36 0 @result_real 0 0 36 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_complex_mult.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_complex_mult.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_complex_mult.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_complex_mult.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_complex_mult_inst.vhd FALSE
-- Retrieval info: LIB_FILE: altera_mf