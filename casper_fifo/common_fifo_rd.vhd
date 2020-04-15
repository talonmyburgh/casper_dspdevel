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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

-- Purpose: Adapt from ready latency 1 to 0 to make a look ahead FIFO
-- Description: -
-- Remark:
-- . Derived from dp_latency_adapter.vhd.
-- . There is no need for a rd_emp output signal, because a show ahead FIFO
--   will have rd_val='0' when it is empty.

ENTITY common_fifo_rd IS
	GENERIC(
		g_dat_w : NATURAL := 18
	);
	PORT(
		rst      : IN  STD_LOGIC;
		clk      : IN  STD_LOGIC;
		-- ST sink: RL = 1
		fifo_req : OUT STD_LOGIC;
		fifo_dat : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		fifo_val : IN  STD_LOGIC := '0';
		-- ST source: RL = 0
		rd_req   : IN  STD_LOGIC;
		rd_dat   : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		rd_val   : OUT STD_LOGIC
	);
END common_fifo_rd;

ARCHITECTURE wrap OF common_fifo_rd IS

BEGIN

	u_rl0 : ENTITY work.common_rl_decrease
		GENERIC MAP(
			g_adapt => TRUE,
			g_dat_w => g_dat_w
		)
		PORT MAP(
			rst           => rst,
			clk           => clk,
			-- ST sink: RL = 1
			snk_out_ready => fifo_req,
			snk_in_dat    => fifo_dat,
			snk_in_val    => fifo_val,
			-- ST source: RL = 0
			src_in_ready  => rd_req,
			src_out_dat   => rd_dat,
			src_out_val   => rd_val
		);

END wrap;
