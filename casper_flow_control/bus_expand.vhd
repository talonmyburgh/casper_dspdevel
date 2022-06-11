-- A VHDL implementation of the CASPER bus_expand block (in equal mode).
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;

PACKAGE bus_expand_pkg is 
  CONSTANT c_bus_expand_division_bit_width : NATURAL := 4;
  TYPE t_bus_expand_slv_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_bus_expand_division_bit_width-1 DOWNTO 0);
END PACKAGE;

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE work.bus_expand_pkg.all;

ENTITY bus_expand is
  generic (
    g_divisions : NATURAL := 4
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    din   : in std_logic_vector;
    dout  : out t_bus_expand_slv_arr
  );
end ENTITY;

ARCHITECTURE rtl of bus_expand is
  alias din_v : STD_LOGIC_VECTOR (din'length-1 downto 0) is din;
  CONSTANT c_bit_w : NATURAL := c_bus_expand_division_bit_width;
begin

  g_split : FOR I IN 0 to g_divisions-1 GENERATE
  begin
    dout(dout'low + I) <= din(din'length-1-i*c_bit_w downto din'length-(i+1)*c_bit_w);
  end GENERATE;

end ARCHITECTURE;
