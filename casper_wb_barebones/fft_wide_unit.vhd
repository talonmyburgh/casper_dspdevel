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
-- Purpose: Wideband FFT with Subband Statistics and streaming interfaces. 
--
-- Description: This unit connects an incoming array of streaming interfaces
--              to the wideband fft. The output of the wideband fft is 
--              connected to a set of subband statistics units. The statistics
--              can be read via the memory mapped interface. 
--              A control unit takes care of the correct composition of the
--              output streams(sync).
--
-- Remarks:   . The unit can handle only one sync at a time. Therfor the 
--              sync interval should be larger than the total pipeline
--              stages of the wideband fft. 

library ieee, common_pkg_lib, casper_ram_lib, dp_pkg_lib, r2sdf_fft_lib, casper_requantize_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;

entity fft_wide_unit is
	generic(
		g_fft          : t_fft          := c_fft; -- generics for the FFT
		g_pft_pipeline : t_fft_pipeline := c_fft_pipeline; -- For the pipelined part, defined in casper_r2sdf_fft_lib.rTwoSDFPkg
		g_fft_pipeline : t_fft_pipeline := c_fft_pipeline -- For the parallel part, defined in casper_r2sdf_fft_lib.rTwoSDFPkg
	);
	port(
		clken           : in  std_logic := '1';
		rst             : in  std_logic  := '0';
		clk             : in  std_logic := '1';
		in_bb_sosi_arr      : in  t_bb_sosi_arr_in(g_fft.wb_factor -1 downto 0);
		out_bb_sosi_arr     : out t_bb_sosi_arr_out(g_fft.wb_factor -1 downto 0)
	);
end entity fft_wide_unit;

architecture str of fft_wide_unit is
	
	signal fft_in_re_arr : t_fft_slv_arr_in(g_fft.wb_factor - 1 downto 0);
	signal fft_in_im_arr : t_fft_slv_arr_in(g_fft.wb_factor - 1 downto 0);

	signal fft_out_re_arr : t_fft_slv_arr_out(g_fft.wb_factor - 1 downto 0);
	signal fft_out_im_arr : t_fft_slv_arr_out(g_fft.wb_factor - 1 downto 0);
	signal fft_out_val    : std_logic;

	signal fft_out_bb_sosi_arr : t_bb_sosi_arr_out(g_fft.wb_factor - 1 downto 0);

	type reg_type is record
		in_bb_sosi_arr :  t_bb_sosi_arr_in(g_fft.wb_factor -1 downto 0);
	end record;

	signal r, rin : reg_type;

begin

	---------------------------------------------------------------
	-- INPUT REGISTER FOR THE INPUT SIGNALS
	---------------------------------------------------------------
	-- The complete set of input signals are registered.
	comb : process(r, in_bb_sosi_arr)
		variable v : reg_type;
	begin
		v             := r;
		v.in_bb_sosi_arr := in_bb_sosi_arr;
		rin           <= v;
	end process comb;

	regs : process(clk)
	begin
		if rising_edge(clk) then
			r <= rin;
		end if;
	end process;

	---------------------------------------------------------------
	-- PREPARE INPUT DATA FOR WIDEBAND FFT
	---------------------------------------------------------------
	-- Extract the data from the in_bb_sosi_arr records and resize it 
	-- to fit the format of the fft_r2_wide unit. Uses a default 32bit
	-- length... should probably try enable an optimisation to pick
	-- closest bitwidth.

	gen_prep_fft_data : for I in 0 to g_fft.wb_factor - 1 generate
		fft_in_re_arr(I) <= r.in_bb_sosi_arr(I).re(g_fft.in_dat_w - 1 downto 0);
		fft_in_im_arr(I) <= r.in_bb_sosi_arr(I).im(g_fft.in_dat_w - 1 downto 0);
	end generate;

	---------------------------------------------------------------
	-- THE WIDEBAND FFT
	---------------------------------------------------------------
	u_fft_wide : entity work.fft_r2_wide
		generic map(
			g_fft          => g_fft,    -- generics for the WFFT
			g_pft_pipeline => g_pft_pipeline,
			g_fft_pipeline => g_fft_pipeline
		)
		port map(
			clken      => clken,
			clk        => clk,
			rst        => rst,
			in_re_arr  => fft_in_re_arr,
			in_im_arr  => fft_in_im_arr,
			in_val     => r.in_bb_sosi_arr(0).valid,
			out_re_arr => fft_out_re_arr,
			out_im_arr => fft_out_im_arr,
			out_val    => fft_out_val
		);

	---------------------------------------------------------------
	-- FFT CONTROL UNIT
	---------------------------------------------------------------
	-- The fft control unit composes the output array in the dp-
	-- streaming format. 
	u_fft_control : entity work.fft_wide_unit_control
		generic map(
			g_fft => g_fft
		)
		port map(
			rst          => rst,
			clk          => clk,
			in_re_arr    => fft_out_re_arr,
			in_im_arr    => fft_out_im_arr,
			in_val       => fft_out_val,
			ctrl_sosi    => r.in_bb_sosi_arr(0),
			out_sosi_arr => fft_out_bb_sosi_arr
		);

	-- Connect to the outside world 
	gen_output : for I in 0 to g_fft.wb_factor - 1 generate
		out_bb_sosi_arr(I) <= fft_out_bb_sosi_arr(I);
	end generate;

end str;

