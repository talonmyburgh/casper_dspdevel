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

-- Purpose: Get in_pulse from in_clk to out_pulse in the out_clk domain.
-- Description:
--   The in_pulse is captured in the in_clk domain and then transfered to the
--   out_clk domain. The out_pulse is also only one cycle wide and transfered
--   back to the in_clk domain to serve as an acknowledge signal to ensure
--   that the in_pulse was recognized also in case the in_clk is faster than
--   the out_clk. The in_busy is active during the entire transfer. Hence the
--   rate of pulses that can be transfered is limited by g_delay_len and by
--   the out_clk rate.

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_spulse IS
	GENERIC(
		g_delay_len : NATURAL := c_meta_delay_len
	);
	PORT(
		in_rst    : IN  STD_LOGIC := '0';
		in_clk    : IN  STD_LOGIC;
		in_clken  : IN  STD_LOGIC := '1';
		in_pulse  : IN  STD_LOGIC;
		in_busy   : OUT STD_LOGIC;
		out_rst   : IN  STD_LOGIC := '0';
		out_clk   : IN  STD_LOGIC;
		out_clken : IN  STD_LOGIC := '1';
		out_pulse : OUT STD_LOGIC
	);
END;

ARCHITECTURE rtl OF common_spulse IS

	SIGNAL in_level       : STD_LOGIC;
	SIGNAL meta_level     : STD_LOGIC_VECTOR(0 TO g_delay_len - 1);
	SIGNAL out_level      : STD_LOGIC;
	SIGNAL prev_out_level : STD_LOGIC;
	SIGNAL meta_ack       : STD_LOGIC_VECTOR(0 TO g_delay_len - 1);
	SIGNAL pulse_ack      : STD_LOGIC;
	SIGNAL nxt_out_pulse  : STD_LOGIC;

BEGIN

	capture_in_pulse : ENTITY work.common_switch
		PORT MAP(
			clk         => in_clk,
			clken       => in_clken,
			rst         => in_rst,
			switch_high => in_pulse,
			switch_low  => pulse_ack,
			out_level   => in_level
		);

	in_busy <= in_level OR pulse_ack;

	p_out_clk : PROCESS(out_rst, out_clk)
	BEGIN
		IF out_rst = '1' THEN
			meta_level     <= (OTHERS => '0');
			out_level      <= '0';
			prev_out_level <= '0';
			out_pulse      <= '0';
		ELSIF RISING_EDGE(out_clk) THEN
			IF out_clken = '1' THEN
				meta_level     <= in_level & meta_level(0 TO meta_level'HIGH - 1);
				out_level      <= meta_level(meta_level'HIGH);
				prev_out_level <= out_level;
				out_pulse      <= nxt_out_pulse;
			END IF;
		END IF;
	END PROCESS;

	p_in_clk : PROCESS(in_rst, in_clk)
	BEGIN
		IF in_rst = '1' THEN
			meta_ack  <= (OTHERS => '0');
			pulse_ack <= '0';
		ELSIF RISING_EDGE(in_clk) THEN
			IF in_clken = '1' THEN
				meta_ack  <= out_level & meta_ack(0 TO meta_ack'HIGH - 1);
				pulse_ack <= meta_ack(meta_ack'HIGH);
			END IF;
		END IF;
	END PROCESS;

	nxt_out_pulse <= out_level AND NOT prev_out_level;

END rtl;
