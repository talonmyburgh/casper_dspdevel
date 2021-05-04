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

-- Purpose:
--   Provide input ready control and use output ready control to the FIFO.
--   Pass sop and eop along with the data through the FIFO if g_use_ctrl=TRUE.
--   Default the RL=1, use g_fifo_rl=0 for a the show ahead FIFO.
-- Description:
--   Provide the sink ready for FIFO write control and use source ready for
--   FIFO read access. The sink ready output is derived from FIFO almost full.
--   Data without framing can use g_use_ctrl=FALSE to avoid implementing two
--   data bits for sop and eop in the FIFO word width. Idem for g_use_sync,
--   g_use_empty, g_use_channel and g_use_error.
-- Remark:
-- . The bsn, empty, channel and error fields are valid at the sop and or eop.
--   Therefore alternatively these fields can be passed on through a separate
--   FIFO, with only one entry per frame, to save FIFO memory in case
--   concatenating them makes the FIFO word width larger than a standard
--   memory data word width.
-- . The FIFO makes that the src_in.ready and snk_out.ready are not
--   combinatorially connected, so this can ease the timing closure for the
--   ready signal.

LIBRARY IEEE, common_pkg_lib, dp_components_lib, dp_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY dp_fifo_core IS
	GENERIC(
		g_note_is_ful    : BOOLEAN := TRUE; -- when TRUE report NOTE when FIFO goes full, fifo overflow is always reported as FAILURE
		g_use_dual_clock : BOOLEAN := FALSE;
		g_use_lut_sc     : BOOLEAN := FALSE; -- when TRUE then force using LUTs instead of block RAM for single clock FIFO (bot available for dual clock FIFO)
		g_data_w         : NATURAL := 16; -- Should be 2 times the c_complex_w if g_use_complex = TRUE
		g_data_signed    : BOOLEAN := FALSE; -- TRUE extends g_data_w bits with the sign bit, FALSE pads g_data_w bits with zeros.
		g_bsn_w          : NATURAL := 1;
		g_empty_w        : NATURAL := 1;
		g_channel_w      : NATURAL := 1;
		g_error_w        : NATURAL := 1;
		g_use_bsn        : BOOLEAN := FALSE;
		g_use_empty      : BOOLEAN := FALSE;
		g_use_channel    : BOOLEAN := FALSE;
		g_use_error      : BOOLEAN := FALSE;
		g_use_sync       : BOOLEAN := FALSE;
		g_use_ctrl       : BOOLEAN := TRUE; -- sop & eop
		g_use_complex    : BOOLEAN := FALSE; -- TRUE feeds the concatenated complex fields (im & re) through the FIFO instead of the data field.
		g_fifo_size      : NATURAL := 512; -- (16+2) * 512 = 1 M9K, g_data_w+2 for sop and eop
		g_fifo_af_margin : NATURAL := 4; -- >=4, Nof words below max (full) at which fifo is considered almost full
		g_fifo_rl        : NATURAL := 1;
		g_fifo_primitive : STRING  := "auto"
	);
	PORT(
		wr_rst   : IN  STD_LOGIC;
		wr_clk   : IN  STD_LOGIC;
		rd_rst   : IN  STD_LOGIC;
		rd_clk   : IN  STD_LOGIC;
		-- Monitor FIFO filling
		wr_ful   : OUT STD_LOGIC;       -- corresponds to the carry bit of wr_usedw when FIFO is full
		wr_usedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_fifo_size) - 1 DOWNTO 0);
		rd_usedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_fifo_size) - 1 DOWNTO 0);
		rd_emp   : OUT STD_LOGIC;
		-- ST sink
		snk_out  : OUT t_dp_siso;
		snk_in   : IN  t_dp_sosi;
		-- ST source
		src_in   : IN  t_dp_siso;
		src_out  : OUT t_dp_sosi
	);
END dp_fifo_core;

ARCHITECTURE str OF dp_fifo_core IS

	CONSTANT c_use_data : BOOLEAN := TRUE;
	CONSTANT c_ctrl_w   : NATURAL := 2; -- sop and eop

	CONSTANT c_complex_w : NATURAL := smallest(c_dp_stream_dsp_data_w, g_data_w / 2); -- needed to cope with g_data_w > 2*c_dp_stream_dsp_data_w

	CONSTANT c_fifo_almost_full : NATURAL := g_fifo_size - g_fifo_af_margin; -- FIFO almost full level for snk_out.ready
	CONSTANT c_fifo_dat_w       : NATURAL := func_slv_concat_w(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl,
	                                                           g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w); -- concat via FIFO

	SIGNAL nxt_snk_out : t_dp_siso := c_dp_siso_rst;

	SIGNAL arst : STD_LOGIC;

	SIGNAL wr_data_complex : STD_LOGIC_VECTOR(2 * c_complex_w - 1 DOWNTO 0);
	SIGNAL wr_data         : STD_LOGIC_VECTOR(g_data_w - 1 DOWNTO 0);
	SIGNAL rd_data         : STD_LOGIC_VECTOR(g_data_w - 1 DOWNTO 0);

	SIGNAL fifo_wr_dat   : STD_LOGIC_VECTOR(c_fifo_dat_w - 1 DOWNTO 0);
	SIGNAL fifo_wr_req   : STD_LOGIC;
	SIGNAL fifo_wr_ful   : STD_LOGIC;
	SIGNAL fifo_wr_usedw : STD_LOGIC_VECTOR(wr_usedw'RANGE);

	SIGNAL fifo_rd_dat   : STD_LOGIC_VECTOR(c_fifo_dat_w - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL fifo_rd_val   : STD_LOGIC;
	SIGNAL fifo_rd_req   : STD_LOGIC;
	SIGNAL fifo_rd_emp   : STD_LOGIC;
	SIGNAL fifo_rd_usedw : STD_LOGIC_VECTOR(rd_usedw'RANGE);

	SIGNAL wr_sync : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL rd_sync : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL wr_ctrl : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL rd_ctrl : STD_LOGIC_VECTOR(1 DOWNTO 0);

	SIGNAL rd_siso : t_dp_siso;
	SIGNAL rd_sosi : t_dp_sosi := c_dp_sosi_rst; -- initialize default values for unused sosi fields

BEGIN

	-- Output monitor FIFO filling
	wr_ful   <= fifo_wr_ful;
	wr_usedw <= fifo_wr_usedw;
	rd_usedw <= fifo_rd_usedw;
	rd_emp   <= fifo_rd_emp;

	p_wr_clk : PROCESS(wr_clk, wr_rst)
	BEGIN
		IF wr_rst = '1' THEN
			snk_out <= c_dp_siso_rst;
		ELSIF rising_edge(wr_clk) THEN
			snk_out <= nxt_snk_out;
		END IF;
	END PROCESS;

	wr_sync(0) <= snk_in.sync;
	wr_ctrl    <= snk_in.sop & snk_in.eop;

	-- Assign the snk_in data field or concatenated complex fields to the FIFO wr_data depending on g_use_complex
	wr_data_complex <= snk_in.im(c_complex_w - 1 DOWNTO 0) & snk_in.re(c_complex_w - 1 DOWNTO 0);
	wr_data         <= snk_in.data(g_data_w - 1 DOWNTO 0) WHEN g_use_complex = FALSE ELSE RESIZE_UVEC(wr_data_complex, g_data_w);

	-- fifo wr wires
	fifo_wr_req <= snk_in.valid;
	fifo_wr_dat <= func_slv_concat(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl,
	                               wr_data,
	                               snk_in.bsn(g_bsn_w - 1 DOWNTO 0),
	                               snk_in.empty(g_empty_w - 1 DOWNTO 0),
	                               snk_in.channel(g_channel_w - 1 DOWNTO 0),
	                               snk_in.err(g_error_w - 1 DOWNTO 0),
	                               wr_sync,
	                               wr_ctrl);

	-- pass on frame level flow control
	nxt_snk_out.xon <= src_in.xon;

	-- up stream use fifo almost full to control snk_out.ready
	nxt_snk_out.ready <= '1' WHEN UNSIGNED(fifo_wr_usedw) < c_fifo_almost_full ELSE '0';

	gen_common_fifo_sc : IF g_use_dual_clock = FALSE GENERATE
		u_common_fifo_sc : ENTITY work.common_fifo_sc
			GENERIC MAP(
				g_note_is_ful    => g_note_is_ful,
				g_use_lut        => g_use_lut_sc,
				g_dat_w          => c_fifo_dat_w,
				g_nof_words      => g_fifo_size,
				g_fifo_primitive => g_fifo_primitive
			)
			PORT MAP(
				rst    => rd_rst,
				clk    => rd_clk,
				wr_dat => fifo_wr_dat,
				wr_req => fifo_wr_req,
				wr_ful => fifo_wr_ful,
				rd_dat => fifo_rd_dat,
				rd_req => fifo_rd_req,
				rd_emp => fifo_rd_emp,
				rd_val => fifo_rd_val,
				usedw  => fifo_rd_usedw
			);

		fifo_wr_usedw <= fifo_rd_usedw;
	END GENERATE;

	gen_common_fifo_dc : IF g_use_dual_clock = TRUE GENERATE
		u_common_fifo_dc : ENTITY work.common_fifo_dc
			GENERIC MAP(
				g_dat_w          => c_fifo_dat_w,
				g_nof_words      => g_fifo_size,
				g_fifo_primitive => g_fifo_primitive
			)
			PORT MAP(
				rst     => arst,
				wr_clk  => wr_clk,
				wr_dat  => fifo_wr_dat,
				wr_req  => fifo_wr_req,
				wr_ful  => fifo_wr_ful,
				wrusedw => fifo_wr_usedw,
				rd_clk  => rd_clk,
				rd_dat  => fifo_rd_dat,
				rd_req  => fifo_rd_req,
				rd_emp  => fifo_rd_emp,
				rdusedw => fifo_rd_usedw,
				rd_val  => fifo_rd_val
			);

		arst <= wr_rst OR rd_rst;
	END GENERATE;

	-- Extract the data from the wide FIFO output SLV. rd_data will be assigned to rd_sosi.data or rd_sosi.im & rd_sosi.re depending on g_use_complex.
	rd_data <= func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 0);

	-- fifo rd wires
	-- SISO
	fifo_rd_req <= rd_siso.ready;

	-- SOSI
	rd_sosi.data    <= RESIZE_DP_SDATA(rd_data) WHEN g_data_signed = TRUE ELSE RESIZE_DP_DATA(rd_data);
	rd_sosi.re      <= RESIZE_DP_DSP_DATA(rd_data(c_complex_w - 1 DOWNTO 0));
	rd_sosi.im      <= RESIZE_DP_DSP_DATA(rd_data(2 * c_complex_w - 1 DOWNTO c_complex_w));
	rd_sosi.bsn     <= RESIZE_DP_BSN(func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 1));
	rd_sosi.empty   <= RESIZE_DP_EMPTY(func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 2));
	rd_sosi.channel <= RESIZE_DP_CHANNEL(func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 3));
	rd_sosi.err     <= RESIZE_DP_ERROR(func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 4));
	rd_sync         <= func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 5);
	rd_ctrl         <= func_slv_extract(c_use_data, g_use_bsn, g_use_empty, g_use_channel, g_use_error, g_use_sync, g_use_ctrl, g_data_w, g_bsn_w, g_empty_w, g_channel_w, g_error_w, 1, c_ctrl_w, fifo_rd_dat, 6);

	rd_sosi.sync  <= fifo_rd_val AND rd_sync(0);
	rd_sosi.valid <= fifo_rd_val;
	rd_sosi.sop   <= fifo_rd_val AND rd_ctrl(1);
	rd_sosi.eop   <= fifo_rd_val AND rd_ctrl(0);

	u_ready_latency : ENTITY dp_components_lib.dp_latency_adapter
		GENERIC MAP(
			g_in_latency  => 1,
			g_out_latency => g_fifo_rl
		)
		PORT MAP(
			rst     => rd_rst,
			clk     => rd_clk,
			-- ST sink
			snk_out => rd_siso,
			snk_in  => rd_sosi,
			-- ST source
			src_in  => src_in,
			src_out => src_out
		);

END str;
