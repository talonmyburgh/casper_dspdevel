LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

entity edge_detect is
    generic (
        g_edge_type   : STRING := "rising";
        g_output_pol  : STRING := "high"
    );
    port (
        clk         : IN std_logic;
        ce          : IN std_logic;
        in_sig      : IN std_logic_vector;
        out_sig     : OUT std_logic_vector
    );
END edge_detect;

architecture rtl of edge_detect is
   SIGNAL s_not_in_sig : std_logic_vector(in_sig'RANGE) := (others=>'0');
   SIGNAL s_delayed_in_sig : std_logic_vector(in_sig'RANGE) := (others=>'0');
   SIGNAL s_out_sig  : std_logic_vector(in_sig'RANGE);
begin

    s_not_in_sig <= not in_sig;

--------------------------------------------------------------
-- one clock cycle delay
--------------------------------------------------------------
one_clk_delay : process(clk, ce)
BEGIN
    IF rising_edge(clk) and ce = '1' THEN
        s_delayed_in_sig <= in_sig;
    END IF;
END PROCESS;

--------------------------------------------------------------
-- generated logic gate
--------------------------------------------------------------
nor_gate_gen: if g_edge_type = "rising" and g_output_pol = "high" generate
     s_out_sig <= s_not_in_sig nor s_delayed_in_sig;
end generate;
or_gate_gen: if g_edge_type = "rising" and g_output_pol = "low" generate
     s_out_sig <= s_not_in_sig or s_delayed_in_sig;
end generate;
nand_gate_gen: if g_edge_type = "falling" and g_output_pol = "low" generate
     s_out_sig <= s_not_in_sig nand s_delayed_in_sig;
end generate;
and_gate_gen: if g_edge_type = "falling" and g_output_pol = "high" generate
     s_out_sig <= s_not_in_sig and s_delayed_in_sig;
end generate;
xnor_gate_gen: if g_edge_type = "both" and g_output_pol = "high" generate
     s_out_sig <= s_not_in_sig xnor s_delayed_in_sig;
end generate;
xor_gate_gen: if g_edge_type = "both" and g_output_pol = "low" generate
     s_out_sig <= s_not_in_sig xor s_delayed_in_sig;
end generate;

--------------------------------------------------------------
-- output
--------------------------------------------------------------

out_sig <= s_out_sig;

END architecture;