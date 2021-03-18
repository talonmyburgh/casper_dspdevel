library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library IEEE, common_pkg_lib, casper_ram_lib, casper_mm_lib;
    use IEEE.std_logic_1164.ALL;
    use IEEE.numeric_std.ALL;
    use common_pkg_lib.common_pkg.ALL; 
    use casper_ram_lib.common_ram_pkg.ALL;
    use work.fil_pkg.ALL;
    entity top_fil is generic (
    g_big_endian_wb_in  : boolean            := false;              -- input endian
    g_big_endian_wb_out : boolean            := false;              -- output endian
    g_in_dat_w          : natural            := 8;                   -- input data width
    g_coef_dat_w        : natural            := 12;                  -- coefficient data width
    g_out_dat_w         : natural            := 10;                  -- output data width
    g_wb_factor         : natural            := 1;                  -- wideband factor
    g_nof_chan          : natural            := 0;                  -- number of channels
    g_nof_bands         : natural            := 1024;               -- number of bands
    g_nof_taps          : natural            := 4;                  -- number of taps
    g_nof_streams       : natural            := 1;                  -- number of streams
    g_backoff_w         : natural            := 0;                  -- backoff width
    g_technology        : natural            := 0;                  -- 0 for Xilinx, 1 for Altera
    g_ram_primitive     : string             := "auto");            -- ram primitive function for use
    port(
    clk            : in  std_logic;
    ce             : in  std_logic           := '1';
    rst            : in  std_logic;
    in_val         : in  std_logic;
    out_val        : out std_logic;
    in_dat_0   : in std_logic_vector(in_dat_w-1 DOWNTO 0);
    out_dat_0  : out std_logic_vector(out_dat_w -1 DOWNTO 0)
    );
    end top_fil;

architecture rtl of top_fil is
    constant cc_fil_ppf : t_fil_ppf := (g_wb_factor, g_nof_chan, g_nof_bands, g_nof_taps, g_nof_streams, g_backoff_w, g_in_dat_w, g_out_dat_w, g_coef_dat_w);
    signal in_dat_arr : t_slv_arr_in(wb_factor -1 DOWNTO 0);
    signal out_dat_arr : t_slv_arr_out(wb_factor -1 DOWNTO 0);
    begin
    wide_ppf : entity work.fil_ppf_wide
    generic map(
    g_big_endian_wb_in  => false,
    g_big_endian_wb_out => false,
    g_fil_ppf           => cc_fil_ppf,
    g_fil_ppf_pipeline  => c_fil_ppf_pipeline,
    g_coefs_file        => c_coefs_file,
    g_technology        => g_technology,
    g_ram_primitive     => g_ram_primitive)
    port map(
    clk => clk,
    ce => ce,
    rst => rst,
    in_dat_arr => in_dat_arr,
    in_val => in_val,
    out_dat_arr => out_dat_arr,
    out_val => out_val);
    in_dat_arr(0) <= in_dat_0;
    out_dat_0 <= out_dat_arr(0);
end rtl;
