LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY simple_accumulator IS
	GENERIC(
		g_representation  : STRING  := "SIGNED" --! "SIGNED" or "UNSIGNED"
	);
	PORT(
		clk     : IN  STD_LOGIC;        --! input clock source
		ce      : IN  STD_LOGIC := '1'; --! enable process triggering on clock rising edge
		rst     : IN  STD_LOGIC := '0'; --! reset accumulation
		in_b    : IN  STD_LOGIC_VECTOR; --! input value B
		result  : OUT STD_LOGIC_VECTOR --! result
	);
END simple_accumulator;

architecture rtl of simple_accumulator is
    signal s_buf : STD_LOGIC_VECTOR(result'range) := (others => '0');
begin

    result <= s_buf;

    process (clk)
    begin
        if rising_edge(clk) then
            IF rst = '1' then
                s_buf <= (others => '0');
            elsif ce = '1' then
                IF g_representation = "SIGNED" THEN
                    s_buf <= ADD_SVEC(in_b, s_buf, result'length);
                ELSE
                    s_buf <= ADD_UVEC(in_b, s_buf, result'length);
                END IF;
            end if;
        end if;
    end process;

    

end architecture;