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

entity top is
        
    port(
        i_clk           : in  std_logic;     --! Clock
        i_rst           : in  std_logic := '0'; --! Reset
        i_shiftreg      : in  std_logic_vector(17  DOWNTO 0); --! Shift register
        i_re_arr        : in  t_slv_44_arr(31 downto 0); --! Input real data (wb_factor wide)
        i_im_arr        : in  t_slv_44_arr(31 downto 0); --! Input imag data (wb_factor wide)
        i_val           : in  std_logic := '1'; --! In data valid
        o_re_arr        : out t_slv_64_arr(31 downto 0); --! Output real data (wb_factor wide)
        o_im_arr        : out t_slv_64_arr(31 downto 0); --! Output imag data (wb_factor wide)
        o_ovflw         : out std_logic_vector(17 DOWNTO 0); --! Overflow register
        o_val           : out std_logic      --! Out data valid
    );
end top;

architecture top_arch of top is

component wb_wrapper is
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
end component wb_wrapper;
constant c_wb_factor : integer := 4;
begin


wb_wrapper_inst : wb_wrapper
  generic map(
    g_wb_factor => c_wb_factor)
  port map(
    i_clk                 => i_clk,
    i_rst                 => i_rst,
    i_shiftreg            => i_shiftreg,
    i_re_arr           => i_re_arr(c_wb_factor-1 downto 0),
    i_im_arr           => i_im_arr(c_wb_factor-1 downto 0),
    i_val              => i_val,
    o_re_arr          => o_re_arr(c_wb_factor-1 downto 0),
    o_im_arr          => o_im_arr(c_wb_factor-1 downto 0),
    o_ovflw               => o_ovflw,
    o_val             => o_val
  );


end top_arch;
