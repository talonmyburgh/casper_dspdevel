-- A VHDL implementation of the CASPER bus_create block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, std, common_pkg_lib, common_slv_arr_pkg_lib;
USE IEEE.std_logic_1164.all;
USE STD.TEXTIO.ALL;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

ENTITY tb_bus_create is
    generic (
        g_values : t_natural_arr := (0, 3, 2, 3);
        g_div_bit_w : NATURAL := 4 
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end ENTITY;

ARCHITECTURE rtl of tb_bus_create is
    -- CONSTANT c_div_bit_w : NATURAL := c_bus_create_division_bit_width;
    CONSTANT bit_width : NATURAL := g_div_bit_w*(g_values'length);
    
    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL en : std_logic;
    SIGNAL tb_end  : std_logic := '0';

    -- SIGNAL s_in : t_bus_create_slv_arr(0 to g_values'LENGTH-1);
    SIGNAL s_in : t_slv_arr(g_values'RANGE, g_div_bit_w-1 downto 0);
    SIGNAL s_out, s_exp : std_logic_vector(bit_width-1 downto 0);
begin

    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- Generate SLV values as per generics
---------------------------------------------------------------------
    g_vals : for I in g_values'RANGE GENERATE
        -- constant c_uvec_value : std_logic_vector(s_in'RANGE(2)) := TO_UVEC(g_values(I), g_div_bit_w);
    BEGIN
        g_bits : for bit_i in s_in'RANGE(2) GENERATE
            s_in(I, bit_i) <= TO_UVEC(g_values(I), g_div_bit_w)(bit_i);
        end GENERATE;
        s_exp(s_exp'high-(I*g_div_bit_w) downto s_exp'high+1-(I+1)*g_div_bit_w) <= TO_UVEC(g_values(I), g_div_bit_w);
    end GENERATE;

---------------------------------------------------------------------
-- Verification process
---------------------------------------------------------------------
    p_verify : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := True;
    begin
        -- Setup
        o_test_pass <= v_test_pass;
        WAIT for clk_period*2;
        ce <= '1';
        en <= '1';

        -- Verify
        v_test_pass := s_out = s_exp;
        IF not v_test_pass THEN
            v_test_msg := pad("bus_create failed, expected: " & to_hstring(s_exp) & " but got: " & to_hstring(s_out), o_test_msg'length, '.');
            REPORT "ERROR: " & v_test_msg severity failure;
        END IF;

        -- End
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end <= '1';
        WAIT;
    end process;

---------------------------------------------------------------------
-- bus_create module
---------------------------------------------------------------------
    u_bus_create : entity work.bus_create
    port map (
        clk => clk,
        ce => ce,
        din => s_in,
        dout => s_out
    );

end ARCHITECTURE;
