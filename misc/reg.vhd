-- A VHDL implementation of the Xilinx register block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, casper_counter_lib;
USE IEEE.std_logic_1164.all;

ENTITY reg is
  generic (
    g_initial_value  : std_logic_vector
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;

    i_reset  : in std_logic := '0';
    i_en  : in std_logic := '1';
    i_d  : in std_logic_vector;
    o_q  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of reg is
begin
  p_register : process(clk)
  BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
      IF i_reset /= '1' and i_en = '1' THEN
        o_q <= i_d;
      ELSE
        o_q <= g_initial_value;
      END IF;
    END IF;
  END PROCESS;
end ARCHITECTURE;
