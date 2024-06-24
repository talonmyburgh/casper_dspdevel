-- A VHDL implementation of the CASPER bus_create block (with each in-port being equal).
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_slv_arr_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

ENTITY bus_create is
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    din  : in t_slv_arr;
    dout   : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of bus_create is
  alias dout_v : STD_LOGIC_VECTOR (din'LENGTH(2)*din'LENGTH(1)-1 downto 0) is dout;
  CONSTANT c_bit_w : NATURAL := din'LENGTH(2);
begin
  ASSERT dout'length = din'LENGTH(2)*din'LENGTH(1);

  g_concat : FOR I IN din'RANGE(1) GENERATE
  begin
    dout_v(dout_v'length-1-i*c_bit_w downto dout_v'length-(i+1)*c_bit_w) <= slv_arr_index(din, I);
  end GENERATE;

end ARCHITECTURE;
