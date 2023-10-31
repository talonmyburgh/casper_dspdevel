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

library ieee, common_pkg_lib, common_components_lib, technology_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
USE technology_lib.technology_select_pkg.ALL;

entity rTwoBFStage is
	generic(
		-- generics for this stage
		g_nof_chan      : natural := 0; --! Exponent of nr of subbands (0 means 1 subband)
		g_stage         : natural;      --! The stage indices are ..., 3, 2, 1. The input stage has the highest index, the output stage has index 1.
		g_bf_lat        : natural := 1; --! Digital pipelining latency
		-- generics for rTwoBF
		g_bf_use_zdly   : natural := 1; --! >= 1. Stage high downto g_bf_use_zdly will will use g_bf_in_a_zdly and g_bf_out_zdly
		g_bf_in_a_zdly  : natural := 0; --! g_bf_in_a_zdly+g_bf_out_d_zdly must be <= the stage z^(-1) delay, note that stage 1 has only one z^(-1) delay
		g_bf_out_d_zdly : natural := 0; --! The stage z^(-1) delays are ..., 4, 2, 1.
		g_dsp_dly		: natural := 1	--! Butterfly units delay - expect timing failure for dsp_dly < 1 (ignored for non Xilinx designs)
	);
	port(
		clk     : in  std_logic;        --! Input clock source
		rst     : in  std_logic;        --! Reset signal
		in_re   : in  std_logic_vector; --! Real input
		in_im   : in  std_logic_vector; --! Imaginary input
		in_val  : in  std_logic;        --! Accept input value (for delay)
		in_sel  : in  std_logic;        --! Select input
		out_re  : out std_logic_vector; --! Real output
		out_im  : out std_logic_vector; --! Imaginary output
		ovflw   : out std_logic;		--! Overflow detected in butterfly add/sub
		out_val : out std_logic;        --! Output value valid signal
		out_sel : out std_logic         --! Select output
	);
end entity rTwoBFStage;

architecture str of rTwoBFStage is

	-- Optionally move some z-1 delay into this BF stage, default 0
	constant c_bf_in_a_zdly  : natural := sel_a_b(g_stage >= g_bf_use_zdly, g_bf_in_a_zdly, 0);
	constant c_bf_out_b_zdly : natural := sel_a_b(g_stage >= g_bf_use_zdly, g_bf_out_d_zdly, 0);

	constant c_use_dsp_dly : boolean := c_tech_select_default = c_tech_xpm or c_tech_select_default = c_tech_versal;
	constant c_dsp_dly : natural := sel_a_b(c_use_dsp_dly, g_dsp_dly, 0);
	constant c_bf_zdly       : natural := c_bf_in_a_zdly + c_bf_out_b_zdly ;
	constant c_feedback_zdly : natural := pow2(g_stage - 1);

	-- The BF adds, subtracts or passes the data on, so typically c_out_dat_w = c_in_dat_w + 1
	constant c_in_dat_w  : natural := in_re'length; -- re and im have same width
	constant c_out_dat_w : natural := out_re'length; -- re and im have same width

	-- Concatenate im & re into complex data to potentially ease synthesis to make more efficient use of block RAM memory for z-1 data feedback line
	signal bf_complex     : std_logic_vector(c_nof_complex * c_in_dat_w - 1 downto 0);
	signal bf_complex_dly : std_logic_vector(bf_complex'range);
	signal bf_re          : std_logic_vector(in_re'range);
	signal bf_re_dly      : std_logic_vector(in_re'range);
	signal bf_im          : std_logic_vector(in_im'range);
	signal bf_im_dly      : std_logic_vector(in_im'range);
	signal bf_sel         : std_logic;
	signal bf_val         : std_logic;
	signal bf_val_dly     : std_logic;

	signal stage_complex     : std_logic_vector(c_nof_complex * c_out_dat_w - 1 downto 0);
	signal stage_complex_dly : std_logic_vector(stage_complex'range);
	signal stage_re          : std_logic_vector(out_re'range);
	signal stage_im          : std_logic_vector(out_im'range);
	signal stage_sel         : std_logic;
	signal stage_val         : std_logic;
	signal in_val_d1		 : std_logic;

	signal ovflw_det		 : std_logic_vector(1 DOWNTO 0);

begin

	------------------------------------------------------------------------------
	-- butterfly
	------------------------------------------------------------------------------

	u_bf_re : entity work.rTwoBF
		generic map(
			g_in_a_zdly  => c_bf_in_a_zdly,
			g_out_d_zdly => c_bf_out_b_zdly,
			g_dsp_dly    => c_dsp_dly
		)
		port map(
			clk    => clk,
			in_a   => bf_re_dly,
			in_b   => in_re,
			in_sel => in_sel,
			in_val => in_val,
			ovflw  => ovflw_det(0),
			out_c  => stage_re,
			out_d  => bf_re
		);

	u_bf_im : entity work.rTwoBF
		generic map(
			g_in_a_zdly  => c_bf_in_a_zdly,
			g_out_d_zdly => c_bf_out_b_zdly,
			g_dsp_dly    => c_dsp_dly
		)
		port map(
			clk    => clk,
			in_a   => bf_im_dly,
			in_b   => in_im,
			in_sel => in_sel,
			in_val => in_val,
			ovflw  => ovflw_det(1),
			out_c  => stage_im,
			out_d  => bf_im
		);
	
	registered_ovflw : process (clk)
	begin
		if rising_edge(clk) then
			ovflw <= (ovflw_det(0) or ovflw_det(1));
		end if;
	end process;
	------------------------------------------------------------------------------
	-- feedback fifo
	------------------------------------------------------------------------------

	bf_sel <= in_sel;
	bf_val <= in_val;

	bf_complex <= bf_im & bf_re;
	bf_re_dly  <= bf_complex_dly(c_in_dat_w - 1 downto 0);
	bf_im_dly  <= bf_complex_dly(2 * c_in_dat_w - 1 downto c_in_dat_w);

	-- share FIFO for Im & Re
	u_feedback : entity common_components_lib.common_delay
		generic map(
			g_dat_w => bf_complex'length,
			g_depth => c_feedback_zdly * (2**g_nof_chan) - c_bf_zdly
		)
		port map(
            clk     => clk,
            in_val  => bf_val,
            in_dat  => bf_complex,
            out_dat => bf_complex_dly
		);

	-- compensate for feedback fifo
	u_stage_sel : entity common_components_lib.common_bit_delay
		generic map(
			g_depth => c_feedback_zdly * (2**g_nof_chan)
		)
		port map(
            clk     => clk,
            rst     => rst,
            in_clr  => '0',
            in_bit  => bf_sel,
            in_val  => bf_val,
            out_bit => stage_sel
		);

	-- compensate for feedback fifo
	u_stage_val : entity common_components_lib.common_bit_delay
		generic map(
			g_depth => c_feedback_zdly * (2**g_nof_chan)
		)
		port map(
            clk     => clk,
            rst     => rst,
            in_clr  => '0',
            in_bit  => bf_val,
            in_val  => bf_val,
            out_bit => bf_val_dly
		);


	-- after the z^(-1) stage delay the bf_val_dly goes high and remains high and acts as an enable for in_val to out_val
	stage_val <= in_val and bf_val_dly;
	------------------------------------------------------------------------------
	-- stage output pipelining
	------------------------------------------------------------------------------

	stage_complex <= stage_im & stage_re;

	u_pipeline_out : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_bf_lat,
			g_in_dat_w  => stage_complex'length,
			g_out_dat_w => stage_complex'length
		)
		port map(
			clk     => clk,
			in_dat  => stage_complex,
			out_dat => stage_complex_dly
		);

	out_re <= stage_complex_dly(c_out_dat_w - 1 downto 0);
	out_im <= stage_complex_dly(2 * c_out_dat_w - 1 downto c_out_dat_w);

	u_out_sel : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_bf_lat+g_dsp_dly
		)
		port map(
			clk     => clk,
			in_dat  => stage_sel,
			out_dat => out_sel
		);

	u_out_val : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_bf_lat+g_dsp_dly
		)
		port map(
			clk     => clk,
			in_dat  => stage_val,
			out_dat => out_val
		);

end str;
