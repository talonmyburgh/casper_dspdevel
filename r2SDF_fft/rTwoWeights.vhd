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

-- Purpose: Get twiddles from ROM
-- Description:
--   The twiddles ROM is generated twiddlesPkg.vhd.
-- Remark:
-- . Default use g_lat=1 as for synthesis to improve fmax.
-- . Use g_lat=0 for no digital latency to show the pure functional behavior
--   of a pipelined FFT.  
-- . When the pipelined FFT is used in a Wideband FFT configuration the 
--   rTwoWeights unit compensates for this by estimating the virtual stage and
--   applying the twiddle-offset and the stage-offset. 

library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use work.twiddlesPkg.all;

entity rTwoWeights is
	generic(
		g_stage          : natural := 4; -- The stage number of the pft
		g_lat            : natural := 1; -- latency 0 or 1
		g_twiddle_offset : natural := 0; -- The twiddle offset: 0 for normal FFT. Other than 0 in wideband FFT
		g_stage_offset   : natural := 0 -- The Stage offset: 0 for normal FFT. Other than 0 in wideband FFT
	);
	port(
		clk       : in  std_logic;
		in_wAdr   : in  std_logic_vector;
		weight_re : out wTyp;
		weight_im : out wTyp
	);
end;

architecture rtl of rTwoWeights is

	constant c_virtual_stage : integer := g_stage + g_stage_offset; -- Virtual stage based on the real stage and the stage_offset.
	constant c_nof_shifts    : integer := -1 * g_stage_offset; -- Shift factor when fft is used in wfft configuration  

	signal nxt_weight_re  : wTyp;
	signal nxt_weight_im  : wTyp;
	signal wAdr_shift     : std_logic_vector(c_virtual_stage - 1 downto 1);
	signal wAdr_unshift   : std_logic_vector(c_virtual_stage - 1 downto 1);
	signal wAdr_tw_offset : integer := 0;

begin

	-- Estimate the correct twiddle address. 
	-- In case of a wfft configuration the address will be shifted and the twiddle offset will be added. 
	wAdr_unshift   <= RESIZE_UVEC(in_wAdr, wAdr_unshift'length);
	wAdr_shift     <= SHIFT_UVEC(wAdr_unshift, c_nof_shifts) when in_wAdr'length > 0 else (others => '0');
	wAdr_tw_offset <= TO_UINT(wAdr_shift) + g_twiddle_offset when in_wAdr'length > 0 else g_twiddle_offset;

	-- functionality
	p_get_weights : process(wAdr_tw_offset)
	begin
		if c_virtual_stage = 1 then
			nxt_weight_re <= wRe(wMap(0, 1));
			nxt_weight_im <= wIm(wMap(0, 1));
		else
			nxt_weight_re <= wRe(wMap(wAdr_tw_offset, c_virtual_stage));
			nxt_weight_im <= wIm(wMap(wAdr_tw_offset, c_virtual_stage));
		end if;
	end process;

	-- latency
	no_reg : if g_lat = 0 generate
		weight_re <= nxt_weight_re;
		weight_im <= nxt_weight_im;
	end generate;

	gen_reg : if g_lat = 1 generate
		p_clk : process(clk)
		begin
			if rising_edge(clk) then
				weight_re <= nxt_weight_re;
				weight_im <= nxt_weight_im;
			end if;
		end process;
	end generate;

	assert g_lat <= 1 report "rTwoWeights : g_lat must be 0 or 1" severity failure;

end rtl;
