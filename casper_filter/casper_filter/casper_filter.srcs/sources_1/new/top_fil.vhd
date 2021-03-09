library IEEE, common_pkg_lib;
use IEEE.STD_LOGIC_1164.ALL;
--Purpose: A Simulink necessary wrapper for the wide_fil_unit. Serves to expose all signals and generics individually.

entity top_fil is
    generic(
        wb_factor : natural := 1;
        nof_chan : natural := 0;
        nof_bands : natural := 1024;
        nof_taps : natural := 4;
        backoff_w : natural : 0;
        c_coefs_file : string := "filtercoeff.mem"
    );
    port(
        clk             : in std_logic;
        rst             : in std_logic;
        
    
    
    
    
    );
end top_fil;

architecture Behavioral of top_fil is

begin


end Behavioral;
