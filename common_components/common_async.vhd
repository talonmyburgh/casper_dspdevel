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

-- Purpose: Clock an asynchronous din into the clk clock domain
-- Description:
--   The delay line combats the potential meta-stability of clocked in data.

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_async IS
	GENERIC(
		g_rising_edge : BOOLEAN   := TRUE;
		g_rst_level   : STD_LOGIC := '0';
		g_delay_len   : POSITIVE  := c_meta_delay_len -- use common_pipeline if g_delay_len=0 for wires only is also needed
	);
	PORT(
		rst  : IN  STD_LOGIC := '0';
		clk  : IN  STD_LOGIC;
		din  : IN  STD_LOGIC;
		dout : OUT STD_LOGIC
	);
END;

ARCHITECTURE rtl OF common_async IS

	SIGNAL din_meta : STD_LOGIC_VECTOR(0 TO g_delay_len - 1) := (OTHERS => g_rst_level);

	-- Synthesis constraint to ensure that register is kept in this instance region
	attribute preserve : boolean;
	attribute preserve of din_meta : signal is true;

BEGIN

	p_clk : PROCESS(rst, clk)
	BEGIN
		IF g_rising_edge = TRUE THEN
			-- Default use rising edge
			IF rst = '1' THEN
				din_meta <= (OTHERS => g_rst_level);
			ELSIF rising_edge(clk) THEN
				din_meta <= din & din_meta(0 TO din_meta'HIGH - 1);
			END IF;
		ELSE
			-- also support using falling edge
			IF rst = '1' THEN
				din_meta <= (OTHERS => g_rst_level);
			ELSIF falling_edge(clk) THEN
				din_meta <= din & din_meta(0 TO din_meta'HIGH - 1);
			END IF;
		END IF;
	END PROCESS;

	dout <= din_meta(din_meta'HIGH);

END rtl;
