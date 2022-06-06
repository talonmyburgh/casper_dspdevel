-- A VHDL implementation of the CASPER munge block.
-- @author: Mydon Solutions.

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE STD.TEXTIO.ALL;
USE common_pkg_lib.common_pkg.all;

ENTITY tb_munge is
    generic (
        g_number_of_divisions : NATURAL := 4;
        g_division_size_bits : NATURAL := 4;
        g_order : t_natural_arr := (3, 1, 2, 0);
        g_values : t_natural_arr := (0, 3, 2, 3)
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 255);
        o_test_pass : out BOOLEAN  
    );
end ENTITY;

ARCHITECTURE rtl of tb_munge is
    CONSTANT bit_width : NATURAL := g_number_of_divisions*g_division_size_bits;
    
    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL en : std_logic;
    SIGNAL tb_end  : std_logic := '0';

    SIGNAL s_in : std_logic_vector(bit_width-1 downto 0);
    SIGNAL s_out : std_logic_vector(bit_width-1 downto 0);
    SIGNAL s_exp : std_logic_vector(bit_width-1 downto 0);
begin

    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- Generate SLV values as per generics
---------------------------------------------------------------------
    g_vals : for I in 0 to g_number_of_divisions-1 GENERATE
        s_in((I+1)*g_division_size_bits-1 downto I*g_division_size_bits) <= TO_UVEC(g_values(g_values'LOW+I), g_division_size_bits);
        s_exp((I+1)*g_division_size_bits-1 downto I*g_division_size_bits) <= TO_UVEC(g_values(g_values'LOW+g_order(g_order'LOW+I)), g_division_size_bits);
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
            v_test_msg := pad("Munge failed, expected: " & to_hstring(s_exp) & " but got: " & to_hstring(s_out), o_test_msg'length, '.');
            REPORT "ERROR: " & v_test_msg severity warning;
        END IF;

        -- End
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end <= '1';
        WAIT;
    end process;

---------------------------------------------------------------------
-- Munge module
---------------------------------------------------------------------
    u_munge : entity work.munge
    generic map (
        g_number_of_divisions => g_number_of_divisions,
        g_division_size_bits => g_division_size_bits,
        g_packing_order => g_order
    )
    port map (
        din => s_in,
        dout => s_out
    );

end ARCHITECTURE;
