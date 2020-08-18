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

-- Purpose: Testbench for common_spulse.
-- Description:
--   The tb is not self checking, so manually observe working in Wave window.
-- Usage:
-- > as 10
-- > run 1 us

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_spulse_tb IS
END common_spulse_tb;

ARCHITECTURE tb OF common_spulse_tb IS

	CONSTANT c_meta_delay : NATURAL := 2;

	--CONSTANT in_clk_period   : TIME := 10 ns;
	CONSTANT in_clk_period  : TIME := 27 ns;
	CONSTANT out_clk_period : TIME := 17 ns;

	SIGNAL in_rst    : STD_LOGIC;
	SIGNAL out_rst   : STD_LOGIC;
	SIGNAL in_clk    : STD_LOGIC := '0';
	SIGNAL out_clk   : STD_LOGIC := '0';
	SIGNAL in_pulse  : STD_LOGIC;
	SIGNAL out_pulse : STD_LOGIC;

BEGIN

	in_clk  <= NOT in_clk AFTER in_clk_period / 2;
	out_clk <= NOT out_clk AFTER out_clk_period / 2;

	p_in_stimuli : PROCESS
	BEGIN
		in_rst   <= '1';
		in_pulse <= '0';
		WAIT UNTIL rising_edge(in_clk);
		in_rst   <= '0';
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(in_clk);
		END LOOP;
		in_pulse <= '1';
		WAIT UNTIL rising_edge(in_clk);
		in_pulse <= '0';
		WAIT;
	END PROCESS;

	u_out_rst : ENTITY work.common_areset
		PORT MAP(
			in_rst  => in_rst,
			clk     => out_clk,
			out_rst => out_rst
		);

	u_spulse : ENTITY work.common_spulse
		GENERIC MAP(
			g_delay_len => c_meta_delay
		)
		PORT MAP(
			in_clk    => in_clk,
			in_rst    => in_rst,
			in_pulse  => in_pulse,
			out_clk   => out_clk,
			out_rst   => out_rst,
			out_pulse => out_pulse
		);

END tb;
