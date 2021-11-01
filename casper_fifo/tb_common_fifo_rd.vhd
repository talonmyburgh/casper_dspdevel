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
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;

ENTITY tb_common_fifo_rd IS
	GENERIC(
		g_random_control : BOOLEAN := TRUE -- use TRUE for random rd_req control
	);
	PORT(
		o_rst    		: out STD_LOGIC;
		o_clk    		: out STD_LOGIC;
		o_tb_end 		: out STD_LOGIC;
		o_test_msg	: OUT STRING(1 to 64);
		o_test_pass	: OUT BOOLEAN
	);
END tb_common_fifo_rd;

-- Run -all, observe rd_dat in wave window

ARCHITECTURE tb OF tb_common_fifo_rd IS

	CONSTANT clk_period : TIME    := 10 ns;
	CONSTANT c_dat_w    : NATURAL := 16;
	CONSTANT c_fifo_rl  : NATURAL := 1; -- FIFO has RL = 1
	CONSTANT c_read_rl  : NATURAL := 0; -- show ahead FIFO has RL = 0

	SIGNAL rst    : STD_LOGIC;
	SIGNAL clk    : STD_LOGIC := '0';
	SIGNAL tb_end : STD_LOGIC := '0';

	SIGNAL fifo_req : STD_LOGIC;
	SIGNAL fifo_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);
	SIGNAL fifo_val : STD_LOGIC;

	SIGNAL rd_req : STD_LOGIC;
	SIGNAL rd_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);
	SIGNAL rd_val : STD_LOGIC;

	SIGNAL enable      : STD_LOGIC                     := '1';
	SIGNAL random      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL verify_en   : STD_LOGIC                     := '1';
	SIGNAL prev_rd_req : STD_LOGIC;
	SIGNAL prev_rd_dat : STD_LOGIC_VECTOR(c_dat_w - 1 DOWNTO 0);
	
	SIGNAL data_test_pass : BOOLEAN;
	SIGNAL valid_test_pass : BOOLEAN;
	SIGNAL data_test_msg : STRING(o_test_msg'range);
	SIGNAL valid_test_msg : STRING(o_test_msg'range);
BEGIN
	o_rst <= rst;
	o_clk <= clk;
	o_tb_end <= tb_end;
	o_test_pass <= data_test_pass and valid_test_pass;
	o_test_msg <= sel_a_b(not valid_test_pass, valid_test_msg, data_test_msg);


	rst    <= '1', '0' AFTER clk_period * 7;
	clk    <= NOT clk OR tb_end AFTER clk_period / 2;
	tb_end <= '0', '1' AFTER 20 us;

	verify_en <= '0', '1' AFTER clk_period * 35;

	-- Model FIFO output with c_rl = 1 and counter data starting at 0
	proc_common_gen_data(c_fifo_rl, 0, rst, clk, enable, fifo_req, fifo_dat, fifo_val);

	-- Model rd_req
	random <= func_common_random(random) WHEN rising_edge(clk);
	rd_req <= random(random'HIGH) WHEN g_random_control = TRUE ELSE '1';

	-- Verify dut output incrementing data
	proc_common_verify_data(c_read_rl, clk, verify_en, rd_req, rd_val, rd_dat, prev_rd_dat, data_test_msg, data_test_pass);

	-- Verify dut output stream ready - valid relation, prev_rd_req is an auxiliary signal needed by the proc
	proc_common_verify_valid(c_read_rl, clk, verify_en, rd_req, prev_rd_req, rd_val, valid_test_msg, valid_test_pass);

	u_dut : ENTITY work.common_fifo_rd
		GENERIC MAP(
			g_dat_w => c_dat_w
		)
		PORT MAP(
			rst      => rst,
			clk      => clk,
			-- ST sink: RL = 1
			fifo_req => fifo_req,
			fifo_dat => fifo_dat,
			fifo_val => fifo_val,
			-- ST source: RL = 0
			rd_req   => rd_req,
			rd_dat   => rd_dat,
			rd_val   => rd_val
		);

END tb;
