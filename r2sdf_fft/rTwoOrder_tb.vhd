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

-- Purpose: Test bench for rTwoOrder
-- Features:
--
-- Usage:
-- > as 10
-- > run -all
-- Observe manually in Wave Window that out_dat is the previous page in_dat.
-- Use g_bit_flip=false to ease manualy interpretation of out_dat. 

LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY rTwoOrder_tb IS
END rTwoOrder_tb;

ARCHITECTURE tb OF rTwoOrder_tb IS

	CONSTANT c_clk_period : TIME := 10 ns;

	CONSTANT c_nof_points : NATURAL := 8;
	CONSTANT c_dat_w      : NATURAL := 10;

	SIGNAL tb_end : STD_LOGIC := '0';
	SIGNAL rst    : STD_LOGIC;
	SIGNAL clk    : STD_LOGIC := '1';
	SIGNAL ce     : STD_LOGIC := '1';

	SIGNAL random_0 : STD_LOGIC_VECTOR(14 DOWNTO 0) := (OTHERS => '0'); -- use different lengths to have different random sequences

	SIGNAL in_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0) := TO_UVEC(1, c_dat_w);
	SIGNAL in_val : STD_LOGIC;

	SIGNAL out_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);
	SIGNAL out_val : STD_LOGIC;

BEGIN

	clk <= (NOT clk) OR tb_end AFTER c_clk_period / 2;
	rst <= '1', '0' AFTER c_clk_period * 3;

	random_0 <= func_common_random(random_0) WHEN rising_edge(clk);

	in_dat <= INCR_UVEC(in_dat, 1) when rising_edge(clk) and in_val = '1';

	-- run 1 us
	p_stimuli : PROCESS
	BEGIN
		in_val <= '0';
		WAIT UNTIL rst = '0';
		proc_common_wait_some_cycles(clk, 3);

		FOR J IN 0 TO 7 LOOP
			-- wait some time
			--       in_val <= '0';
			--       FOR I IN 0 TO 1 LOOP WAIT UNTIL rising_edge(clk); END LOOP;

			-- one block
			in_val <= NOT in_val;       -- toggling
			FOR I IN 0 TO c_nof_points - 1 LOOP
				--in_val <= NOT in_val;                 -- toggling
				--in_val <= random_0(random_0'HIGH);    -- random
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;

		in_val <= '0';

		proc_common_wait_some_cycles(clk, 10);
		tb_end <= '1';
		WAIT;
	END PROCESS;

	-- device under test
	u_dut : ENTITY work.rTwoOrder
		GENERIC MAP(
			g_nof_points => c_nof_points,
			g_bit_flip   => false,
			g_nof_chan   => 7
		)
		port map(
			clk     => clk,
			ce      => ce,
			rst     => rst,
			in_dat  => in_dat,
			in_val  => in_val,
			out_dat => out_dat,
			out_val => out_val
		);

END tb;
