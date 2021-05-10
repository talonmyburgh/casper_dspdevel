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

-- Purpose: Dual clock FIFO

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY common_fifo_dc IS
	GENERIC(
		g_note_is_ful    : BOOLEAN := TRUE; -- when TRUE report NOTE when FIFO goes full, fifo overflow is always reported as FAILURE
		g_fail_rd_emp    : BOOLEAN := FALSE; -- when TRUE report FAILURE when read from an empty FIFO
		g_dat_w          : NATURAL := 36;
		g_nof_words      : NATURAL := 256; -- 36 * 256 = 1 M9K
		g_fifo_primitive : STRING  := "auto"
	);
	PORT(
		rst     : IN  STD_LOGIC;
		wr_clk  : IN  STD_LOGIC;
		wr_dat  : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		wr_req  : IN  STD_LOGIC;
		wr_ful  : OUT STD_LOGIC;
		wrusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0);
		rd_clk  : IN  STD_LOGIC;
		rd_dat  : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		rd_req  : IN  STD_LOGIC;
		rd_emp  : OUT STD_LOGIC;
		rdusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0);
		rd_val  : OUT STD_LOGIC := '0'
	);
END common_fifo_dc;

ARCHITECTURE str of common_fifo_dc IS

	CONSTANT c_nof_words : NATURAL := 2**ceil_log2(g_nof_words); -- ensure size is power of 2 for dual clock FIFO

	SIGNAL wr_rst  : STD_LOGIC;
	SIGNAL wr_init : STD_LOGIC;
	SIGNAL wr_en   : STD_LOGIC;
	SIGNAL rd_en   : STD_LOGIC;
	SIGNAL ful     : STD_LOGIC;
	SIGNAL emp     : STD_LOGIC;

	SIGNAL nxt_rd_val : STD_LOGIC;

BEGIN

	-- Control logic copied from LOFAR common_fifo_dc(virtex4).vhd

	-- Need to make sure the reset lasts at least 3 cycles (see fifo_generator_ug175.pdf)
	-- Wait at least 4 cycles after reset release before allowing FIFO wr_en (see fifo_generator_ug175.pdf)

	-- Use common_areset to:
	-- . asynchronously detect rst even when the wr_clk is stopped
	-- . synchronize release of rst to wr_clk domain
	-- Using common_areset is equivalent to using common_async with same signal applied to rst and din.
	u_wr_rst : ENTITY common_components_lib.common_areset
		GENERIC MAP(
			g_rst_level => '1',
			g_delay_len => 3
		)
		PORT MAP(
			in_rst  => rst,
			clk     => wr_clk,
			out_rst => wr_rst
		);

	-- Delay wr_init to ensure that FIFO ful has gone low after reset release
	u_wr_init : ENTITY common_components_lib.common_areset
		GENERIC MAP(
			g_rst_level => '1',
			g_delay_len => 4
		)
		PORT MAP(
			in_rst  => wr_rst,
			clk     => wr_clk,
			out_rst => wr_init          -- assume init has finished g_delay_len cycles after release of wr_rst
		);

	-- The FIFO under read and over write protection are kept enabled in the MegaWizard
	wr_en <= wr_req AND NOT wr_init;    -- check on NOT ful is not necessary when overflow_checking="ON" (Altera) or according to fifo_generator_ug175.pdf (Xilinx)
	rd_en <= rd_req;                    -- check on NOT emp is not necessary when underflow_checking="ON" (Altera)

	nxt_rd_val <= rd_req AND NOT emp;   -- check on NOT emp is necessary for rd_val

	wr_ful <= ful WHEN wr_init = '0' ELSE '0';

	rd_emp <= emp;

	p_rd_clk : PROCESS(rd_clk)
	BEGIN
		IF rising_edge(rd_clk) THEN
			rd_val <= nxt_rd_val;
		END IF;
	END PROCESS;

	u_fifo : ENTITY work.tech_fifo_dc
		GENERIC MAP(
			g_dat_w          => g_dat_w,
			g_nof_words      => c_nof_words,
			g_fifo_primitive => g_fifo_primitive
		)
		PORT MAP(
			aclr    => wr_rst,          -- MegaWizard fifo_dc seems to use aclr synchronous with wr_clk
			data    => wr_dat,
			rdclk   => rd_clk,
			rdreq   => rd_en,
			wrclk   => wr_clk,
			wrreq   => wr_en,
			q       => rd_dat,
			rdempty => emp,
			rdusedw => rdusedw,
			wrfull  => ful,
			wrusedw => wrusedw
		);

	proc_common_fifo_asserts("common_fifo_dc", g_note_is_ful, g_fail_rd_emp, wr_rst, wr_clk, ful, wr_en, rd_clk, emp, rd_en);

END str;
