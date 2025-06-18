----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/31/2023 12:31:29 PM
-- Design Name: 
-- Module Name: top - top_arch
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee, r2sdf_fft_lib,wb_fft_lib,common_pkg_lib;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use common_pkg_lib.common_pkg.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity wb_wrapper is
    generic(
        g_wb_factor     : integer := 32
    );   
    port(
        i_clk           : in  std_logic;     --! Clock
        i_rst           : in  std_logic := '0'; --! Reset
        i_shiftreg      : in  std_logic_vector(17  DOWNTO 0); --! Shift register
        i_re_arr        : in  t_slv_44_arr(g_wb_factor-1 downto 0); --! Input real data (wb_factor wide)
        i_im_arr        : in  t_slv_44_arr(g_wb_factor-1 downto 0); --! Input imag data (wb_factor wide)
        i_val           : in  std_logic := '1'; --! In data valid
        o_re_arr        : out t_slv_64_arr(g_wb_factor-1 downto 0); --! Output real data (wb_factor wide)
        o_im_arr        : out t_slv_64_arr(g_wb_factor-1 downto 0); --! Output imag data (wb_factor wide)
        o_ovflw         : out std_logic_vector(17 DOWNTO 0) := (others => '0'); --! Overflow register
        o_val           : out std_logic      --! Out data valid
    );
end wb_wrapper;

architecture wb_wrapper_arch of wb_wrapper is
        
constant c_fft_test : t_fft :=  (
                                  use_reorder         => false, 
                                  use_fft_shift       => false, 
                                  use_separate        => false,  -- we'll actually use seperate on ngVLA but let's start with complex 
                                  nof_chan            => 0, 
                                  wb_factor           => g_wb_factor, 
                                  nof_points          => 131072, 
                                  in_dat_w            => 18, 
                                  out_dat_w           => 18, 
                                  out_gain_w          => 0, 
                                  stage_dat_w         => 18, 
                                  twiddle_dat_w       => 18, 
                                  max_addr_w          => c_max_addr_w,
                                  guard_w             => 0,
                                  guard_enable        => true,
                                  stat_data_w         => 56,
                                  stat_data_sz        => 2,
                                  pipe_reo_in_place   => false
                                );

signal shiftreg      : std_logic_vector(ceil_log2(c_fft_test.nof_points) - 1 DOWNTO 0); --! Shift register
signal re_arr        : t_slv_44_arr(g_wb_factor-1 downto 0); --! Input real data (wb_factor wide)
signal im_arr        : t_slv_44_arr(g_wb_factor-1 downto 0); --! Input imag data (wb_factor wide)
signal vald          : std_logic := '1'; --! In data valid

										  
begin


reg_inputs : process(i_clk)
begin
	if rising_edge(i_clk) then
		re_arr		<= i_re_arr;
		im_arr		<= i_im_arr;
		shiftreg 	<= i_shiftreg(shiftreg'length-1 downto 0);
		vald		<= i_val;
	end if;
end process;


fft_r2_wide_inst : entity wb_fft_lib.fft_r2_wide
  generic map(
    g_fft               => c_fft_test,
    g_pft_pipeline      => c_fft_pipeline, -- r2sdf_fft_lib.rTwoSDFPkg
    g_fft_pipeline      => c_fft_pipeline, -- r2sdf_fft_lib.rTwoSDFPkg
    g_alt_output        => true,
    g_use_variant       => "4DSP",
    g_use_dsp           => "yes",
    g_ovflw_behav       => "SATURATE",
    g_round             => ROUND,
    g_use_mult_round    => ROUND,
    g_ram_primitive     => "auto",
    g_twid_file_stem    => "UNUSED"
  )
  port map(
    clken               => '1', -- let's not use clock enables...
    clk                 => i_clk,
    rst                 => i_rst,
    shiftreg            => shiftreg,
    in_re_arr           => re_arr,
    in_im_arr           => im_arr,
    in_val              => vald,
    out_re_arr          => o_re_arr,
    out_im_arr          => o_im_arr,
    ovflw               => o_ovflw(ceil_log2(c_fft_test.nof_points)-1 downto 0),
    out_val             => o_val
  );


end wb_wrapper_arch;
