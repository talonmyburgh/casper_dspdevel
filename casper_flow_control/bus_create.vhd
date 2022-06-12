-- A VHDL implementation of the CASPER bus_create block (with each in-port being equal).
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;

PACKAGE bus_create_pkg is 
  CONSTANT c_bus_create_division_bit_width : NATURAL := 4;
  TYPE t_bus_create_slv_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_bus_create_division_bit_width-1 DOWNTO 0);
END PACKAGE;

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE work.bus_create_pkg.all;

ENTITY bus_create is
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    din  : in t_bus_create_slv_arr;
    dout   : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of bus_create is
  alias dout_v : STD_LOGIC_VECTOR (dout'length-1 downto 0) is dout;
  CONSTANT c_bit_w : NATURAL := c_bus_create_division_bit_width;
begin

  g_concat : FOR I IN 0 to din'length-1 GENERATE
  begin
     dout_v(dout_v'length-1-i*c_bit_w downto dout_v'length-(i+1)*c_bit_w) <= din(I);
  end GENERATE;

end ARCHITECTURE;
