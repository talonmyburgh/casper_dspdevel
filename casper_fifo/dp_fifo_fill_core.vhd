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
--------------------------------------------------------------------------------

-- Purpose:
--   The FIFO starts outputting data when the output is ready and it has been
--   filled with more than g_fifo_fill words. Given a fixed frame length, this
--   is useful when the in_val is throttled while the out_val should not be
--   inactive valid between out_sop to out_eop. This is necessary for frame
--   transport over a PHY link without separate data valid signal.
-- Description:
--   The FIFO is filled sufficiently for each input frame, as defined by the
--   sop and then read until the eop.
--   The rd_fill_32b control input is used for dynamic control of the fill
--   level on the read side of the FIFO. The rd_fill_32b defaults to
--   g_fifo_fill, so if rd_fill_32b is not connected then the fill level is
--   fixed to g_fifo_fill. A g_fifo_fill disables the fifo fill mechanism.
--   The rd_fill_32b signal must be stable in the rd_clk domain.
-- Remarks:
-- . Reuse from LOFAR rad_frame_scheduler.vhd and rad_frame_scheduler(rtl).vhd
-- . For g_fifo_fill=0 this dp_fifo_fill_core defaults to dp_fifo_core.
-- . The architecture offers two implementations via g_fifo_rl. Use 0 for show
--   ahead FIFO or 1 for normal FIFO. At the output of dp_fifo_fill_core the
--   RL=1 independent of g_fifo_rl, the g_fifo_rl only applies to the internal
--   FIFO. The show ahead FIFO uses the dp_latency_adapter to get to RL 0
--   internally. The normal FIFO is prefered, because it uses less logic. It
--   keeps the RL internally also at 1.
-- . Note that the structure of p_state is idendical in both architectures
--   for both g_fifo_rl=0 or 1. Hence the implementation of g_fifo_rl=1 with
--   dp_input_hold is an example of how to use dp_input_hold to get the same
--   behaviour as if the input had g_fifo_rl=0 as with the show ahead FIFO.
-- . To view the similarity of the p_state process for both g_fifo_rl e.g.
--   open the file in two editors or do repeatedly find (F3) on a text
--   section like 'WHEN s_fill  =>' that only occurs one in each p_state.
-- . The next_src_out = pend_src_out when src_in.ready='1'. However it is more
--   clear to only use pend_src_out and explicitely write the condition on
--   src_in.ready in the code, because then the structure of p_state is the
--   same for both g_fifo_rl=0 or 1. Furthermore using pend_src_out and 
--   src_in.ready is often more clear to comprehend then using next_src_out
--   directly.

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, dp_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY dp_fifo_fill_core IS
	GENERIC(
		g_use_dual_clock : BOOLEAN := FALSE;
		g_data_w         : NATURAL := 16;
		g_bsn_w          : NATURAL := 1;
		g_empty_w        : NATURAL := 1;
		g_channel_w      : NATURAL := 1;
		g_error_w        : NATURAL := 1;
		g_use_bsn        : BOOLEAN := FALSE;
		g_use_empty      : BOOLEAN := FALSE;
		g_use_channel    : BOOLEAN := FALSE;
		g_use_error      : BOOLEAN := FALSE;
		g_use_sync       : BOOLEAN := FALSE;
		g_use_complex    : BOOLEAN := FALSE; -- TRUE feeds the concatenated complex fields (im & re) through the FIFO instead of the data field.
		g_fifo_fill      : NATURAL := 0;
		g_fifo_size      : NATURAL := 256; -- (32+2) * 256 = 1 M9K, g_data_w+2 for sop and eop
		g_fifo_af_margin : NATURAL := 4; -- Nof words below max (full) at which fifo is considered almost full
		g_fifo_rl        : NATURAL := 1 -- use RL=0 for internal show ahead FIFO, default use RL=1 for internal normal FIFO
	);
	PORT(
		wr_rst       : IN  STD_LOGIC;
		wr_clk       : IN  STD_LOGIC;
		rd_rst       : IN  STD_LOGIC;
		rd_clk       : IN  STD_LOGIC;
		-- Monitor FIFO filling
		wr_ful       : OUT STD_LOGIC;   -- corresponds to the carry bit of wr_usedw when FIFO is full
		wr_usedw     : OUT STD_LOGIC_VECTOR(ceil_log2(largest(g_fifo_size, g_fifo_fill + g_fifo_af_margin + 2)) - 1 DOWNTO 0); -- = ceil_log2(c_fifo_size)-1 DOWNTO 0
		rd_usedw     : OUT STD_LOGIC_VECTOR(ceil_log2(largest(g_fifo_size, g_fifo_fill + g_fifo_af_margin + 2)) - 1 DOWNTO 0); -- = ceil_log2(c_fifo_size)-1 DOWNTO 0
		rd_emp       : OUT STD_LOGIC;
		-- MM control FIFO filling (assume 32 bit MM interface)
		wr_usedw_32b : OUT STD_LOGIC_VECTOR(c_word_w - 1 DOWNTO 0); -- = wr_usedw
		rd_usedw_32b : OUT STD_LOGIC_VECTOR(c_word_w - 1 DOWNTO 0); -- = rd_usedw
		rd_fill_32b  : IN  STD_LOGIC_VECTOR(c_word_w - 1 DOWNTO 0) := TO_UVEC(g_fifo_fill, c_word_w);
		-- ST sink
		snk_out      : OUT t_dp_siso;
		snk_in       : IN  t_dp_sosi;
		-- ST source
		src_in       : IN  t_dp_siso;
		src_out      : OUT t_dp_sosi
	);
END dp_fifo_fill_core;

ARCHITECTURE rtl OF dp_fifo_fill_core IS

	CONSTANT c_fifo_rl          : NATURAL := sel_a_b(g_fifo_fill = 0, 1, g_fifo_rl);
	CONSTANT c_fifo_fill_margin : NATURAL := g_fifo_af_margin + 2; -- add +2 extra margin, with tb_dp_fifo_fill it follows that +1 is also enough to avoid almost full when fifo is operating near g_fifo_fill level
	CONSTANT c_fifo_size        : NATURAL := largest(g_fifo_size, g_fifo_fill + c_fifo_fill_margin);
	CONSTANT c_fifo_size_w      : NATURAL := ceil_log2(c_fifo_size); -- = wr_usedw'LENGTH = rd_usedw'LENGTH

	-- The FIFO filling relies on framed data, so contrary to dp_fifo_sc the sop and eop need to be used.
	CONSTANT c_use_ctrl : BOOLEAN := TRUE;

	-- Define t_state as slv to avoid Modelsim warning "Nonresolved signal 'nxt_state' may have multiple sources". Due to that g_fifo_rl = 0 or 1 ar both supported.
	--TYPE t_state IS (s_idle, s_fill, s_output, s_xoff);
	CONSTANT s_idle   : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
	CONSTANT s_fill   : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
	CONSTANT s_output : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
	CONSTANT s_xoff   : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";

	SIGNAL state     : STD_LOGIC_VECTOR(1 DOWNTO 0); -- t_state
	SIGNAL nxt_state : STD_LOGIC_VECTOR(1 DOWNTO 0); -- t_state

	SIGNAL xon_reg     : STD_LOGIC;
	SIGNAL nxt_xon_reg : STD_LOGIC;

	SIGNAL rd_siso : t_dp_siso;
	SIGNAL rd_sosi : t_dp_sosi := c_dp_sosi_rst; -- initialize default values for unused sosi fields;

	SIGNAL wr_fifo_usedw : STD_LOGIC_VECTOR(c_fifo_size_w - 1 DOWNTO 0); -- = wr_usedw'RANGE
	SIGNAL rd_fifo_usedw : STD_LOGIC_VECTOR(c_fifo_size_w - 1 DOWNTO 0); -- = rd_usedw'RANGE
	SIGNAL rd_fill_ctrl  : STD_LOGIC_VECTOR(c_fifo_size_w - 1 DOWNTO 0); -- used to resize rd_fill_32b to actual maximum width

	SIGNAL i_src_out   : t_dp_sosi;
	SIGNAL nxt_src_out : t_dp_sosi;

	-- Signals for g_fifo_rl=1
	SIGNAL hold_src_in  : t_dp_siso;
	SIGNAL pend_src_out : t_dp_sosi;

BEGIN

	-- Output monitor FIFO filling
	wr_usedw <= wr_fifo_usedw;
	rd_usedw <= rd_fifo_usedw;

	-- Control FIFO fill level
	wr_usedw_32b <= RESIZE_UVEC(wr_fifo_usedw, c_word_w);
	rd_usedw_32b <= RESIZE_UVEC(rd_fifo_usedw, c_word_w);

	rd_fill_ctrl <= rd_fill_32b(c_fifo_size_w - 1 DOWNTO 0);

	gen_dp_fifo_sc : IF g_use_dual_clock = FALSE GENERATE
		u_dp_fifo_sc : ENTITY work.dp_fifo_sc
			GENERIC MAP(
				g_data_w         => g_data_w,
				g_bsn_w          => g_bsn_w,
				g_empty_w        => g_empty_w,
				g_channel_w      => g_channel_w,
				g_error_w        => g_error_w,
				g_use_bsn        => g_use_bsn,
				g_use_empty      => g_use_empty,
				g_use_channel    => g_use_channel,
				g_use_error      => g_use_error,
				g_use_sync       => g_use_sync,
				g_use_ctrl       => c_use_ctrl,
				g_use_complex    => g_use_complex,
				g_fifo_size      => c_fifo_size,
				g_fifo_af_margin => g_fifo_af_margin,
				g_fifo_rl        => c_fifo_rl
			)
			PORT MAP(
				rst     => rd_rst,
				clk     => rd_clk,
				-- Monitor FIFO filling
				wr_ful  => wr_ful,
				usedw   => rd_fifo_usedw,
				rd_emp  => rd_emp,
				-- ST sink
				snk_out => snk_out,
				snk_in  => snk_in,
				-- ST source
				src_in  => rd_siso,     -- for RL = 0 rd_siso.ready acts as read acknowledge, for RL = 1 rd_siso.ready acts as read request
				src_out => rd_sosi
			);

		wr_fifo_usedw <= rd_fifo_usedw;
	END GENERATE;

	gen_dp_fifo_dc : IF g_use_dual_clock = TRUE GENERATE
		u_dp_fifo_dc : ENTITY work.dp_fifo_dc
			GENERIC MAP(
				g_data_w         => g_data_w,
				g_bsn_w          => g_bsn_w,
				g_empty_w        => g_empty_w,
				g_channel_w      => g_channel_w,
				g_error_w        => g_error_w,
				g_use_bsn        => g_use_bsn,
				g_use_empty      => g_use_empty,
				g_use_channel    => g_use_channel,
				g_use_error      => g_use_error,
				g_use_sync       => g_use_sync,
				g_use_ctrl       => c_use_ctrl,
				--g_use_complex    => g_use_complex,
				g_fifo_size      => c_fifo_size,
				g_fifo_af_margin => g_fifo_af_margin,
				g_fifo_rl        => c_fifo_rl
			)
			PORT MAP(
				wr_rst   => wr_rst,
				wr_clk   => wr_clk,
				rd_rst   => rd_rst,
				rd_clk   => rd_clk,
				-- Monitor FIFO filling
				wr_ful   => wr_ful,
				wr_usedw => wr_fifo_usedw,
				rd_usedw => rd_fifo_usedw,
				rd_emp   => rd_emp,
				-- ST sink
				snk_out  => snk_out,
				snk_in   => snk_in,
				-- ST source
				src_in   => rd_siso,    -- for RL = 0 rd_siso.ready acts as read acknowledge, -- for RL = 1 rd_siso.ready acts as read request
				src_out  => rd_sosi
			);
	END GENERATE;

	no_fill : IF g_fifo_fill = 0 GENERATE
		rd_siso <= src_in;              -- SISO
		src_out <= rd_sosi;             -- SOSI
	END GENERATE;                       -- no_fill

	gen_fill : IF g_fifo_fill > 0 GENERATE

		src_out <= i_src_out;

		p_rd_clk : PROCESS(rd_clk, rd_rst)
		BEGIN
			IF rd_rst = '1' THEN
				xon_reg   <= '0';
				state     <= s_idle;
				i_src_out <= c_dp_sosi_rst;
			ELSIF rising_edge(rd_clk) THEN
				xon_reg   <= nxt_xon_reg;
				state     <= nxt_state;
				i_src_out <= nxt_src_out;
			END IF;
		END PROCESS;

		nxt_xon_reg <= src_in.xon;      -- register xon to easy timing closure

		gen_rl_0 : IF g_fifo_rl = 0 GENERATE
			p_state : PROCESS(state, rd_sosi, src_in, xon_reg, rd_fifo_usedw, rd_fill_ctrl)
			BEGIN
				nxt_state <= state;

				rd_siso <= src_in;      -- default acknowledge (RL=1) this input when output is ready

				-- The output register stage increase RL=0 to 1, so it matches RL = 1 for src_in.ready
				nxt_src_out       <= rd_sosi;
				nxt_src_out.valid <= '0'; -- default no output
				nxt_src_out.sop   <= '0';
				nxt_src_out.eop   <= '0';
				nxt_src_out.sync  <= '0';

				CASE state IS
					WHEN s_idle =>
						IF xon_reg = '0' THEN
							nxt_state <= s_xoff;
						ELSE
							-- read the FIFO until the sop is pending at the output, so discard any valid data between eop and sop
							IF rd_sosi.sop = '0' THEN
								rd_siso <= c_dp_siso_rdy; -- acknowledge (RL=0) this input independent of output ready
							ELSE
								rd_siso   <= c_dp_siso_hold; -- stop the input, hold the rd_sosi.sop at FIFO output (RL=0)
								nxt_state <= s_fill;
							END IF;
						END IF;
					WHEN s_fill =>
						IF xon_reg = '0' THEN
							nxt_state <= s_xoff;
						ELSE
							-- stop reading until the FIFO has been filled sufficiently
							IF UNSIGNED(rd_fifo_usedw) < UNSIGNED(rd_fill_ctrl) THEN
								rd_siso <= c_dp_siso_hold; -- stop the input, hold the pend_src_out.sop
							ELSE
								-- if the output is ready, then start outputting the frame
								IF src_in.ready = '1' THEN
									nxt_src_out <= rd_sosi; -- output sop that is still at FIFO output (RL=0)
									nxt_state   <= s_output;
								END IF;
							END IF;
						END IF;
					WHEN s_output =>
						-- if the output is ready continue outputting the frame, ignore xon_reg during this frame
						IF src_in.ready = '1' THEN
							nxt_src_out <= rd_sosi; -- output valid
							IF rd_sosi.eop = '1' THEN
								nxt_state <= s_idle; -- output eop, so stop reading the FIFO
							END IF;
						END IF;
					WHEN OTHERS =>      -- s_xoff
					-- Flush the fill FIFO when xon='0'
						rd_siso <= c_dp_siso_flush;
						IF xon_reg = '1' THEN
							nxt_state <= s_idle;
						END IF;
				END CASE;

				-- Pass on frame level flow control
				rd_siso.xon <= src_in.xon;
			END PROCESS;
		END GENERATE;                   -- gen_rl_0

		gen_rl_1 : IF g_fifo_rl = 1 GENERATE
			-- Use dp_hold_input to get equivalent implementation with default RL=1 FIFO.

			-- Hold the sink input for source output
			u_snk : ENTITY dp_components_lib.dp_hold_input
				PORT MAP(
					rst          => rd_rst,
					clk          => rd_clk,
					-- ST sink
					snk_out      => rd_siso, -- SISO ready
					snk_in       => rd_sosi, -- SOSI
					-- ST source
					src_in       => hold_src_in, -- SISO ready
					next_src_out => OPEN, -- SOSI
					pend_src_out => pend_src_out,
					src_out_reg  => i_src_out
				);

			p_state : PROCESS(state, src_in, xon_reg, pend_src_out, rd_fifo_usedw, rd_fill_ctrl)
			BEGIN
				nxt_state <= state;

				hold_src_in <= src_in;  -- default request (RL=1) new input when output is ready

				-- The output register stage matches RL = 1 for src_in.ready
				nxt_src_out       <= pend_src_out;
				nxt_src_out.valid <= '0'; -- default no output
				nxt_src_out.sop   <= '0';
				nxt_src_out.eop   <= '0';
				nxt_src_out.sync  <= '0';

				CASE state IS
					WHEN s_idle =>
						IF xon_reg = '0' THEN
							nxt_state <= s_xoff;
						ELSE
							-- read the FIFO until the sop is pending at the output, so discard any valid data between eop and sop
							IF pend_src_out.sop = '0' THEN
								hold_src_in <= c_dp_siso_rdy; -- request (RL=1) new input independent of output ready
							ELSE
								hold_src_in <= c_dp_siso_hold; -- stop the input, hold the pend_src_out.sop in dp_hold_input
								nxt_state   <= s_fill;
							END IF;
						END IF;
					WHEN s_fill =>
						IF xon_reg = '0' THEN
							nxt_state <= s_xoff;
						ELSE
							-- stop reading until the FIFO has been filled sufficiently
							IF UNSIGNED(rd_fifo_usedw) < UNSIGNED(rd_fill_ctrl) THEN
								hold_src_in <= c_dp_siso_hold; -- stop the input, hold the pend_src_out.sop
							ELSE
								-- if the output is ready, then start outputting the input frame
								IF src_in.ready = '1' THEN
									nxt_src_out <= pend_src_out; -- output sop that is still pending in dp_hold_input
									nxt_state   <= s_output;
								END IF;
							END IF;
						END IF;
					WHEN s_output =>
						-- if the output is ready continue outputting the input frame, ignore xon_reg during this frame
						IF src_in.ready = '1' THEN
							nxt_src_out <= pend_src_out; -- output valid
							IF pend_src_out.eop = '1' THEN
								nxt_state <= s_idle; -- output eop, so stop reading the FIFO
							END IF;
						END IF;
					WHEN OTHERS =>      -- s_xon
					-- Flush the fill FIFO when xon='0'
						hold_src_in <= c_dp_siso_flush;
						IF xon_reg = '1' THEN
							nxt_state <= s_idle;
						END IF;
				END CASE;

				-- Pass on frame level flow control
				hold_src_in.xon <= src_in.xon;
			END PROCESS;
		END GENERATE;                   -- gen_rl_1

	END GENERATE;                       -- gen_fill
END rtl;
