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

-- Purpose: Single clock FIFO

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY common_fifo_sc IS
	GENERIC(
		g_note_is_ful    : BOOLEAN := TRUE; -- when TRUE report NOTE when FIFO goes full, fifo overflow is always reported as FAILURE
		g_fail_rd_emp    : BOOLEAN := FALSE; -- when TRUE report FAILURE when read from an empty FIFO
		g_use_lut        : BOOLEAN := FALSE; -- when TRUE then force using LUTs via Altera eab="OFF",
		                                     -- else use default eab="ON" and ram_block_type="AUTO", default ram_block_type="AUTO" is sufficient, because
		                                     --      there seems no need to force using RAM and there are two types of Stratix IV RAM (M9K and M144K)
		g_reset          : BOOLEAN := FALSE; -- when TRUE release FIFO reset some cycles after rst release, else use rst directly
		g_init           : BOOLEAN := FALSE; -- when TRUE force wr_req inactive for some cycles after FIFO reset release, else use wr_req as is
		g_dat_w          : NATURAL := 36; -- 36 * 256 = 1 M9K
		g_nof_words      : NATURAL := c_bram_m9k_fifo_depth;
		g_af_margin      : NATURAL := 0; -- FIFO almost full margin for wr_aful flagging
		g_fifo_primitive : STRING  := "auto"
	);
	PORT(
		rst     : IN  STD_LOGIC;
		clk     : IN  STD_LOGIC;
		wr_dat  : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		wr_req  : IN  STD_LOGIC;
		wr_ful  : OUT STD_LOGIC;
		wr_aful : OUT STD_LOGIC;        -- registered FIFO almost full flag
		rd_dat  : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		rd_req  : IN  STD_LOGIC;
		rd_emp  : OUT STD_LOGIC;
		rd_val  : OUT STD_LOGIC;
		usedw   : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
	);
END common_fifo_sc;

ARCHITECTURE str OF common_fifo_sc IS

    function set_fifo_primitive
        return STRING is
    begin
        if g_use_lut then
            return "distributed";
        else
            return g_fifo_primitive;
        end if;
    end function;

    CONSTANT c_fifo_primitive : STRING := set_fifo_primitive;
	CONSTANT c_use_eab : STRING := sel_a_b(g_use_lut, "OFF", "ON"); -- when g_use_lut=TRUE then force using LUTs via Altera eab="OFF", else default to ram_block_type = "AUTO"

	CONSTANT c_fifo_af_latency : NATURAL := 1; -- pipeline register wr_aful
	CONSTANT c_fifo_af_margin  : NATURAL := g_af_margin + c_fifo_af_latency; -- FIFO almost full level

	SIGNAL fifo_rst        : STD_LOGIC;
	SIGNAL fifo_init       : STD_LOGIC;
	SIGNAL fifo_wr_en      : STD_LOGIC;
	SIGNAL nxt_fifo_wr_en  : STD_LOGIC;
	SIGNAL fifo_wr_dat     : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	SIGNAL nxt_fifo_wr_dat : STD_LOGIC_VECTOR(fifo_wr_dat'RANGE);
	SIGNAL fifo_rd_en      : STD_LOGIC;
	SIGNAL fifo_full       : STD_LOGIC;
	SIGNAL fifo_empty      : STD_LOGIC;
	SIGNAL fifo_usedw      : STD_LOGIC_VECTOR(usedw'RANGE);

	SIGNAL nxt_wr_aful : STD_LOGIC;
	SIGNAL nxt_rd_val  : STD_LOGIC;

BEGIN

	-- Control logic copied from common_fifo_sc(virtex4).vhd

	gen_fifo_rst : IF g_reset = TRUE GENERATE
		-- Make sure the reset lasts at least 3 cycles (see fifo_generator_ug175.pdf). This is necessary in case
		-- the FIFO reset is also used functionally to flush it, so not only after power up.
		u_fifo_rst : ENTITY common_components_lib.common_areset
			GENERIC MAP(
				g_rst_level => '1',
				g_delay_len => 4
			)
			PORT MAP(
				in_rst  => rst,
				clk     => clk,
				out_rst => fifo_rst
			);
	END GENERATE;
	no_fifo_rst : IF g_reset = FALSE GENERATE
		fifo_rst <= rst;
	END GENERATE;

	gen_init : IF g_init = TRUE GENERATE
		-- Wait at least 3 cycles after reset release before allowing fifo_wr_en (see fifo_generator_ug175.pdf)
		u_fifo_init : ENTITY common_components_lib.common_areset
			GENERIC MAP(
				g_rst_level => '1',
				g_delay_len => 4
			)
			PORT MAP(
				in_rst  => fifo_rst,
				clk     => clk,
				out_rst => fifo_init
			);

		p_init_reg : PROCESS(fifo_rst, clk)
		BEGIN
			IF fifo_rst = '1' THEN
				fifo_wr_en <= '0';
			ELSIF rising_edge(clk) THEN
				fifo_wr_dat <= nxt_fifo_wr_dat;
				fifo_wr_en  <= nxt_fifo_wr_en;
			END IF;
		END PROCESS;

		nxt_fifo_wr_dat <= wr_dat;
		nxt_fifo_wr_en  <= wr_req AND NOT fifo_init; -- check on NOT full is not necessary according to fifo_generator_ug175.pdf
	END GENERATE;
	no_init : IF g_init = FALSE GENERATE
		fifo_wr_dat <= wr_dat;
		fifo_wr_en  <= wr_req;          -- check on NOT full is not necessary according to fifo_generator_ug175.pdf
	END GENERATE;

	wr_ful <= fifo_full;
	rd_emp <= fifo_empty;
	usedw  <= fifo_usedw;

	fifo_rd_en <= rd_req;               -- check on NOT empty is not necessary according to fifo_generator_ds317.pdf, so skip it to easy synthesis timing

	nxt_rd_val <= fifo_rd_en AND NOT fifo_empty; -- check on NOT empty is necessary for rd_val

	nxt_wr_aful <= '0' WHEN TO_UINT(fifo_usedw) < g_nof_words - c_fifo_af_margin ELSE '1';

	p_clk : PROCESS(fifo_rst, clk)
	BEGIN
		IF fifo_rst = '1' THEN
			wr_aful <= '0';
			rd_val  <= '0';
		ELSIF rising_edge(clk) THEN
			wr_aful <= nxt_wr_aful;
			rd_val  <= nxt_rd_val;
		END IF;
	END PROCESS;

	-- 0 < some threshold < usedw          < g_nof_words can be used as FIFO almost_full
	-- 0 <          usedw < some threshold < g_nof_words can be used as FIFO almost_empty
	u_fifo : ENTITY work.tech_fifo_sc
		GENERIC MAP(
			g_use_eab        => c_use_eab,
			g_dat_w          => g_dat_w,
			g_nof_words      => g_nof_words,
			g_fifo_primitive => c_fifo_primitive
		)
		PORT MAP(
			aclr  => fifo_rst,
			clock => clk,
			data  => fifo_wr_dat,
			rdreq => fifo_rd_en,
			wrreq => fifo_wr_en,
			empty => fifo_empty,
			full  => fifo_full,
			q     => rd_dat,
			usedw => fifo_usedw
		);

	proc_common_fifo_asserts("common_fifo_sc", g_note_is_ful, g_fail_rd_emp, fifo_rst, clk, fifo_full, fifo_wr_en, clk, fifo_empty, fifo_rd_en);

END str;
