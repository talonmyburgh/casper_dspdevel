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

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, casper_pipeline_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE common_lib.all;     
USE common_pkg_lib.common_pkg.ALL;

-- Purpose: Requantize the data in the re, im or data field of the sosi record.
-- Description:
--   See common_requantize.vhd 
-- Remarks:
-- . It does not take into account the ready signal from the siso record. 

ENTITY dp_requantize IS
	GENERIC(
		g_complex             : BOOLEAN := TRUE; -- when true, the re and im field are processed, when false, the data field is processed
		g_representation      : STRING  := "SIGNED"; -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)         
		g_lsb_w               : INTEGER := 4; -- when > 0, number of LSbits to remove from in_dat
		                                      -- when < 0, number of LSBits to insert as a gain before resize to out_dat'LENGTH
		                                      -- when 0 then no effect
		g_lsb_round           : BOOLEAN := TRUE; -- when true ROUND else TRUNCATE the input LSbits                                                                
		g_lsb_round_clip      : BOOLEAN := FALSE; -- when true round clip to +max to avoid wrapping to output -min (signed) or 0 (unsigned) due to rounding        
		g_msb_clip            : BOOLEAN := TRUE; -- when true CLIP else WRAP the input MSbits                                                                     
		g_msb_clip_symmetric  : BOOLEAN := FALSE; -- when TRUE clip signed symmetric to +c_smax and -c_smax, else to +c_smax and c_smin_symm                       
		                                          -- for wrapping when g_msb_clip=FALSE the g_msb_clip_symmetric is ignored, so signed wrapping is done asymmetric 
		g_gain_w              : NATURAL := 0; -- do not use, must be 0, use negative g_lsb_w instead
		g_pipeline_remove_lsb : NATURAL := 0; -- >= 0                                                                                                          
		g_pipeline_remove_msb : NATURAL := 0; -- >= 0, use g_pipeline_remove_lsb=0 and g_pipeline_remove_msb=0 for combinatorial output                        
		g_in_dat_w            : NATURAL := 36; -- input data width                                                                                              
		g_out_dat_w           : NATURAL := 18 -- output data width                                                                                             
	);
	PORT(
		rst     : IN  STD_LOGIC;
		clk     : IN  STD_LOGIC;
		-- ST sink
		snk_in  : IN  t_dp_sosi;
		-- ST source
		src_out : OUT t_dp_sosi;
		-- 
		out_ovr : OUT std_logic         -- out_ovr is '1' when the removal of MSbits causes clipping or wrapping
	);
END dp_requantize;

ARCHITECTURE str OF dp_requantize IS

	CONSTANT c_pipeline : NATURAL := g_pipeline_remove_lsb + g_pipeline_remove_msb;

	SIGNAL snk_in_piped : t_dp_sosi;

	SIGNAL quantized_data : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0);
	SIGNAL quantized_re   : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0);
	SIGNAL quantized_im   : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0);
	SIGNAL out_ovr_re     : STD_LOGIC;
	SIGNAL out_ovr_im     : STD_LOGIC;

BEGIN

	ASSERT g_gain_w = 0 REPORT "dp_requantize: must use g_gain_w = 0, because gain is now supported via negative g_lsb_w." SEVERITY FAILURE;

	---------------------------------------------------------------
	-- Requantize the sosi data field
	---------------------------------------------------------------
	gen_requantize_data : IF g_complex = FALSE GENERATE
		u_requantize_data : ENTITY work.common_requantize
			GENERIC MAP(
				g_representation      => g_representation,
				g_lsb_w               => g_lsb_w,
				g_lsb_round           => g_lsb_round,
				g_lsb_round_clip      => g_lsb_round_clip,
				g_msb_clip            => g_msb_clip,
				g_msb_clip_symmetric  => g_msb_clip_symmetric,
				g_pipeline_remove_lsb => g_pipeline_remove_lsb,
				g_pipeline_remove_msb => g_pipeline_remove_msb,
				g_in_dat_w            => g_in_dat_w,
				g_out_dat_w           => g_out_dat_w
			)
			PORT MAP(
				clk     => clk,
				in_dat  => snk_in.data,
				out_dat => quantized_data,
				out_ovr => out_ovr
			);
	END GENERATE;

	---------------------------------------------------------------
	-- Requantize the sosi complex fields
	---------------------------------------------------------------
	gen_requantize_complex : IF g_complex = TRUE GENERATE
		u_requantize_re : ENTITY work.common_requantize
			GENERIC MAP(
				g_representation      => g_representation,
				g_lsb_w               => g_lsb_w,
				g_lsb_round           => g_lsb_round,
				g_lsb_round_clip      => g_lsb_round_clip,
				g_msb_clip            => g_msb_clip,
				g_msb_clip_symmetric  => g_msb_clip_symmetric,
				g_pipeline_remove_lsb => g_pipeline_remove_lsb,
				g_pipeline_remove_msb => g_pipeline_remove_msb,
				g_in_dat_w            => g_in_dat_w,
				g_out_dat_w           => g_out_dat_w
			)
			PORT MAP(
				clk     => clk,
				in_dat  => snk_in.re,
				out_dat => quantized_re,
				out_ovr => out_ovr_re
			);

		u_requantize_im : ENTITY work.common_requantize
			GENERIC MAP(
				g_representation      => g_representation,
				g_lsb_w               => g_lsb_w,
				g_lsb_round           => g_lsb_round,
				g_lsb_round_clip      => g_lsb_round_clip,
				g_msb_clip            => g_msb_clip,
				g_msb_clip_symmetric  => g_msb_clip_symmetric,
				g_pipeline_remove_lsb => g_pipeline_remove_lsb,
				g_pipeline_remove_msb => g_pipeline_remove_msb,
				g_in_dat_w            => g_in_dat_w,
				g_out_dat_w           => g_out_dat_w
			)
			PORT MAP(
				clk     => clk,
				in_dat  => snk_in.im,
				out_dat => quantized_im,
				out_ovr => out_ovr_im
			);

		out_ovr <= out_ovr_re OR out_ovr_im;
	END GENERATE;

	--------------------------------------------------------------
	-- Pipeline to align the other sosi fields
	--------------------------------------------------------------
	u_dp_pipeline : ENTITY casper_pipeline_lib.dp_pipeline
		GENERIC MAP(
			g_pipeline => c_pipeline    -- 0 for wires, > 0 for registers, 
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			-- ST sink
			snk_in  => snk_in,
			-- ST source
			src_out => snk_in_piped
		);

	PROCESS(snk_in_piped, quantized_data, quantized_re, quantized_im)
	BEGIN
		src_out <= snk_in_piped;
		IF g_complex = FALSE THEN
			IF g_representation = "UNSIGNED" THEN
				src_out.data <= RESIZE_DP_DATA(quantized_data);
			ELSE
				src_out.data <= RESIZE_DP_SDATA(quantized_data);
			END IF;
		ELSE
			src_out.re <= RESIZE_DP_DSP_DATA(quantized_re);
			src_out.im <= RESIZE_DP_DSP_DATA(quantized_im);
		END IF;
	END PROCESS;

END str;
