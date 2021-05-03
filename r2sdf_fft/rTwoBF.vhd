--! @file
--! @brief Radix 2 butterfly module

--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
--! Libraries: IEEE, common_pkg_lib, common_components_lib
library ieee, common_pkg_lib, common_components_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

--! Purpose : Butterfly
--! Description :
--!   Default the rTwoBF is combinatorial and it can not be pipelined because
--!   of the feedback shift register.
--!   However for the FFT input stages with larger feedback shift registers it
--!   may be beneficial for achieving timing closure to move some of the z^(-1)
--!   shift delay out from the d to a feedback shift register into this rTwoBF.
--!   The shift must only occur for valid data, so therefor then the in_val
--!   input is also needed.
--!   The g_in_a_zdly allows getting a delay shift into this rTwoBF for input
--!   in_a. The g_out_d_zdly allows getting a delay shift into this rTwoBF for
--!   output out_d. Externally the feedback shift register depth must then be 
--!   decreased by g_in_a_zdly+g_out_d_zdly.
--! Remarks:
--! . For the last FFT output stages the feedback shift register depth is ...,
--!   4, 2, 1 so then there is less need to use g_in_a_zdly or g_in_a_zdly
--!   other than 0.
--! . Default use g_in_a_zdly=0 and g_out_d_zdly=0, so then clk and in_val can
--!   be left not connected.
--! . Alternatively one can use g_in_a_zdly=0 and g_out_d_zdly=1 for all
--!   stages.

--! @dot 
--! digraph rTwoBF {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! rTwoBF;
--! node [shape=plaintext];
--! clk;
--! in_a;
--! in_b;
--! in_sel;
--! in_val;
--! out_c;
--! out_d;
--! clk -> rTwoBF;
--! in_a -> rTwoBF;
--! in_b -> rTwoBF;
--! in_sel -> rTwoBF;
--! in_val -> rTwoBF;
--! rTwoBF -> out_c;
--! rTwoBF -> out_d;
--!}
--! @enddot

entity rTwoBF is
	generic(
		g_in_a_zdly  : natural := 0;    --! default 0, 1
		g_out_d_zdly : natural := 0     --! default 0, optionally use 1
	);
	port(
		clk    : in  std_logic := '0';  --! Input clock source
		in_a   : in  std_logic_vector;  --! Input signal A
		in_b   : in  std_logic_vector;  --! Input signal B
		in_sel : in  std_logic;         --! Select input
		in_val : in  std_logic := '0';  --! Select input for delay
		ovflw  : out std_logic;			--! Overflow flag for addition/subtraction
		out_c  : out std_logic_vector;  --! Output signal c
		out_d  : out std_logic_vector   --! Output signal d
	);
end;

architecture rtl of rTwoBF is

	signal in_a_dly  : std_logic_vector(in_a'range);
	signal out_c_buf : std_logic_vector(out_c'range);
	signal out_d_ely : std_logic_vector(out_d'range);

begin

	-- Optionally some z-1 delay gets move here into this BF stage, default 0
	u_in_dly : entity common_components_lib.common_delay
		generic map(
			g_dat_w => in_a'length,
			g_depth => g_in_a_zdly
		)
		port map(
			clk     => clk,
			in_val  => in_val,
			in_dat  => in_a,
			out_dat => in_a_dly
		);

	u_out_dly : entity common_components_lib.common_delay
		generic map(
			g_dat_w => out_d'length,
			g_depth => g_out_d_zdly
		)
		port map(
			clk     => clk,
			in_val  => in_val,
			in_dat  => out_d_ely,
			out_dat => out_d
		);

	------------------------------------------------------------------------------------
	-- PRE-EMPT overflow in addition and subtraction
	------------------------------------------------------------------------------------
	ovflw <= (S_ADD_OVFLW_DET(in_a_dly, in_b, out_c_buf) or S_SUB_OVFLW_DET(in_a_dly, in_b, out_d_ely));

	-- BF function: add, subtract or pass the data on dependent on in_sel
	out_c_buf <= ADD_SVEC(in_a_dly, in_b, out_c'length) when in_sel = '1' else in_a_dly;
	out_c 		<= out_c_buf;
	out_d_ely <= SUB_SVEC(in_a_dly, in_b, out_d'length) when in_sel = '1' else in_b;

end rtl;
