-- A VHDL implementation of the CASPER bus_accumulator block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
context vunit_lib.vunit_context;

ENTITY bus_accumulator_stringgenerics is
  generic (
    g_data_type : string := "SIGNED"; -- or "UNSIGNED"
    g_bus_constituent_widths : string;
    g_bus_constituent_expansion_widths : string
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    rst    : in std_logic_vector;
    en    : in std_logic_vector;

    din  : in std_logic_vector;
    dout   : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of bus_accumulator_stringgenerics is
  
	impure function decode(encoded_natural_vector : string) return t_nat_natural_arr is
		variable parts : lines_t := split(encoded_natural_vector, ",");
		variable return_value : t_nat_natural_arr(parts'range);
	begin
		for i in parts'range loop
			return_value(i) := natural'value(parts(i).all);
		end loop;

		return return_value;
	end;

	CONSTANT c_bus_constituent_widths : t_nat_natural_arr := decode(g_bus_constituent_widths);
	CONSTANT c_bus_constituent_expansion_widths : t_nat_natural_arr := decode(g_bus_constituent_expansion_widths);
begin
  u_bu : ENTITY work.bus_accumulator
    generic map(
      g_data_type => g_data_type,
      g_bus_constituent_widths => c_bus_constituent_widths,
      g_bus_constituent_expansion_widths => c_bus_constituent_expansion_widths
    )
    port map (
      clk => clk,
      ce  => ce,
  
      rst => rst,
      en  => en,
  
      din => din,
      dout=> dout
    );
end ARCHITECTURE;
