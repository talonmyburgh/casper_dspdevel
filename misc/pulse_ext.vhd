-- A VHDL implementation of the CASPER pulse_ext block.
-- @author: Mydon Solutions.

LIBRARY IEEE; --, common_pkg_lib;
USE IEEE.std_logic_1164.all;
-- USE common_pkg_lib.common_pkg.all;

ENTITY pulse_ext is
  generic (
    g_extension : NATURAL := 4
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    i_pulse   : in std_logic;
    o_pulse  : out std_logic
  );
end ENTITY;

ARCHITECTURE rtl of pulse_ext is
  SIGNAL s_count : NATURAL := g_extension;
BEGIN

  PROCESS(clk, i_pulse)
  BEGIN
    IF falling_edge(i_pulse) THEN
      s_count <= g_extension;
    END IF;
    
    IF ce = '1' and rising_edge(clk) THEN
      IF s_count > 0 THEN
        s_count <= s_count -1;
      END IF;
    END IF;
  END PROCESS;

  o_pulse <= i_pulse when s_count = 0 else '1';

end ARCHITECTURE;
