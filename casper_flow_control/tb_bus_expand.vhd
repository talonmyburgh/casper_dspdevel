-- A VHDL implementation of the CASPER bus_expand block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE STD.TEXTIO.ALL;
USE common_pkg_lib.common_pkg.all;
USE work.bus_expand_pkg.all;

ENTITY tb_bus_expand is
    generic (
        g_values : t_natural_arr := (0, 3, 2, 3)
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end ENTITY;

ARCHITECTURE rtl of tb_bus_expand is
    CONSTANT c_div_bit_w : NATURAL := c_bus_expand_division_bit_width;
    CONSTANT bit_width : NATURAL := c_div_bit_w*g_values'length;
    
    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL en : std_logic;
    SIGNAL tb_end  : std_logic := '0';

    SIGNAL s_in : std_logic_vector(bit_width-1 downto 0);
    SIGNAL s_out : t_bus_expand_slv_arr(0 to g_values'LENGTH-1);
    SIGNAL s_exp : t_bus_expand_slv_arr(0 to g_values'LENGTH-1);
begin

    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- Generate SLV values as per generics
---------------------------------------------------------------------
    g_vals : for I in 0 to g_values'length-1 GENERATE
        s_in(s_in'high-(I*c_div_bit_w) downto s_in'high+1-(I+1)*c_div_bit_w) <= TO_UVEC(g_values(g_values'low + I), c_div_bit_w);
        s_exp(s_exp'low+I) <= TO_UVEC(g_values(g_values'LOW+I), c_div_bit_w);
    end GENERATE;

---------------------------------------------------------------------
-- Verification process
---------------------------------------------------------------------
    p_verify : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := True;
        VARIABLE v_out : std_logic_vector(c_div_bit_w-1 downto 0);
        VARIABLE v_exp : std_logic_vector(c_div_bit_w-1 downto 0);
    begin
        -- Setup
        o_test_pass <= v_test_pass;
        WAIT for clk_period*2;
        ce <= '1';
        en <= '1';

        -- Verify
        l_div : for i in s_exp'range loop
            v_out := s_out(i);
            v_exp := s_exp(i);
            v_test_pass := v_out = v_exp;
            IF not v_test_pass THEN
                v_test_msg := pad("bus_expand failed at " & integer'image(i) & ", expected: " & to_hstring(v_exp) & " but got: " & to_hstring(v_out), o_test_msg'length, '.');
                REPORT "ERROR: " & v_test_msg severity failure;
            END IF;
            exit l_div when not v_test_pass;
        END loop;

        -- End
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end <= '1';
        WAIT;
    end process;

---------------------------------------------------------------------
-- bus_expand module
---------------------------------------------------------------------
    u_bus_expand : entity work.bus_expand
    generic map (
        g_divisions => g_values'length
    )
    port map (
        din => s_in,
        dout => s_out
    );

end ARCHITECTURE;
