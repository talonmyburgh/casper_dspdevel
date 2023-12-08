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
---------------------------------------------------------------------------------
-- Adapted for use in the CASPER ecosystem by Talon Myburgh under Mydon Solutions
-- myburgh.talon@gmail.com
-- https://github.com/talonmyburgh | https://github.com/MydonSolutions
---------------------------------------------------------------------------------
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

	--summation svec must be one larger than the largest svec
	constant c_sum_bit_width : natural := sel_a_b(in_a'length > in_b'length, in_a'length, in_b'length) + 1;

	signal in_a_dly  : std_logic_vector(in_a'range); -- := (others=>'0');
	signal out_c_buf : std_logic_vector(c_sum_bit_width - 1 DOWNTO 0); -- := (others=>'0');
	signal out_d_buf : std_logic_vector(c_sum_bit_width - 1 DOWNTO 0); -- := (others=>'0');
	signal out_d_ely : std_logic_vector(out_d'range) := (others=>'0');
	signal ovflw_add  : std_logic_vector(0 downto 0); -- := "0";
	signal ovflw_sub  : std_logic_vector(0 downto 0); --:= "0";
	signal ovflw_imm  : std_logic_vector(0 downto 0);-- := "0";
	signal ovflw_dly  : std_logic_vector(0 downto 0); -- := "0";

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

	u_ovflw_dly : entity common_components_lib.common_delay
		generic map(
			g_dat_w => 1,
			g_depth => g_out_d_zdly
		)
		port map(
			clk     => clk,
			in_val  => in_val,
			in_dat  => ovflw_imm,
			out_dat => ovflw_dly
		);

	------------------------------------------------------------------------------------
	-- DETECT overflow in addition and subtraction
	------------------------------------------------------------------------------------
	
	p_det_ovflw : process(clk)
	begin
		if rising_edge(clk) then
			ovflw_add(0) <= '0';
			for checkbit in out_c_buf'length-1 downto out_c'length loop
				if out_c_buf(checkbit) /= out_c_buf(out_c'length-1) then
					ovflw_add(0) <= '1';
				end if;
			end loop;
			ovflw_sub(0) <= '0';
			for checkbit in out_d_buf'length-1 downto out_d'length loop
				if out_d_buf(checkbit) /= out_d_buf(out_d'length-1) then
					ovflw_sub(0) <= '1';
				end if;
			end loop;
			ovflw_imm(0) <= ovflw_add(0) or ovflw_sub(0);
		end if;
	end process;

	ovflw <= ovflw_dly(0) when in_val = '1' else ovflw_imm(0);

	-- BF function: add, subtract or pass the data on dependent on in_sel
	out_c_buf <= ADD_SVEC(in_a_dly, in_b, c_sum_bit_width) when in_sel = '1' else RESIZE_SVEC(in_a_dly, c_sum_bit_width);
	out_c 		<= RESIZE_SVEC(out_c_buf, out_c'length);
	out_d_buf <= SUB_SVEC(in_a_dly, in_b, c_sum_bit_width) when in_sel = '1' else RESIZE_SVEC(in_b, c_sum_bit_width);
	out_d_ely <= RESIZE_SVEC(out_d_buf, out_d'length);	

end rtl;