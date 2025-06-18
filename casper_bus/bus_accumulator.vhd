-- A VHDL implementation of the CASPER bus_accumulator block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_accumulators_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY bus_accumulator is
  generic (
    g_data_type : string := "SIGNED"; -- or "UNSIGNED"
    g_bus_constituent_widths : t_nat_natural_arr;
    g_bus_constituent_expansion_widths : t_nat_natural_arr
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

ARCHITECTURE rtl of bus_accumulator is
  alias din_v : STD_LOGIC_VECTOR (func_sum(g_bus_constituent_widths)-1 downto 0) is din;
  alias dout_v : STD_LOGIC_VECTOR (func_sum(g_bus_constituent_expansion_widths)-1 downto 0) is dout;

begin
    assert not din'ascending; -- assumes downto

    ASSERT rst'left = en'left;
    ASSERT rst'right = en'right;
    ASSERT not rst'ascending;

    ASSERT rst'length = g_bus_constituent_widths'length;
    ASSERT g_bus_constituent_widths'ascending;
    ASSERT g_bus_constituent_widths'left = g_bus_constituent_expansion_widths'left;
    ASSERT g_bus_constituent_widths'right = g_bus_constituent_expansion_widths'right;

    ASSERT din'length = func_sum(g_bus_constituent_widths);
    ASSERT dout'length = func_sum(g_bus_constituent_expansion_widths);

    g_expand : FOR I IN g_bus_constituent_widths'RANGE GENERATE
        CONSTANT c_preceding_index : natural := din'length-func_sum(
            g_bus_constituent_widths(g_bus_constituent_widths'left to I-1)
        );  
        CONSTANT c_preceding_expansion_index : natural := dout'length-func_sum(
            g_bus_constituent_expansion_widths(g_bus_constituent_expansion_widths'left to I-1)
        );
        CONSTANT c_descending_index : natural := rst'left - (I - g_bus_constituent_widths'left);
    begin
        ASSERT g_bus_constituent_widths(I) <= g_bus_constituent_expansion_widths(I);

        u_acc : ENTITY casper_accumulators_lib.simple_accumulator
            GENERIC MAP (
                g_representation => g_data_type
            )
            port map (
                clk         => clk,
                ce          => ce,
                rst         => rst(c_descending_index),
                in_b        => din(c_preceding_index-1 downto c_preceding_index-g_bus_constituent_widths(I)),
                -- valid       
                result      => dout(c_preceding_expansion_index-1 downto c_preceding_expansion_index-g_bus_constituent_expansion_widths(I))
            );
    end GENERATE;

end ARCHITECTURE;
