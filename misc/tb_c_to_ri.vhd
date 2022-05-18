LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE IEEE.numeric_std.ALL;
USE STD.TEXTIO.ALL;

ENTITY tb_c_to_ri is
    GENERIC(
        g_async : BOOLEAN := FALSE;
        g_bit_width : NATURAL := 8;
        g_c_in_val : INTEGER := 12
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_c_to_ri;

ARCHITECTURE rtl of tb_c_to_ri is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk          : STD_LOGIC := '0';
    SIGNAL ce           : STD_LOGIC := '0';
    SIGNAL tb_end       : STD_LOGIC := '0';
    SIGNAL s_c_in       : STD_LOGIC_VECTOR((g_bit_width * 2) - 1 DOWNTO 0);
    SIGNAL s_re_out     : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);
    SIGNAL s_im_out     : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);
    SIGNAL s_re_slice   : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);
    SIGNAL s_im_slice   : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);

begin
    
    clk       <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst <= not ce;
    o_clk <= clk;
    o_tb_end <= tb_end;

    s_re_slice <= s_c_in(s_c_in'LENGTH - 1 DOWNTO g_bit_width);
    s_im_slice <= s_c_in(g_bit_width - 1 DOWNTO 0);

    p_stimuli : PROCESS
    VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE v_test_re_pass : BOOLEAN := True;
    VARIABLE v_test_im_pass : BOOLEAN := True;
    BEGIN
        wait until falling_edge(clk);
        ce <= '1';
        s_c_in <= std_logic_vector(to_signed(g_c_in_val, g_bit_width*2));
        if not g_async THEN
            WAIT for clk_period;
            WAIT UNTIL rising_edge(clk);
        end if;
        v_test_re_pass := s_re_slice = s_re_out;
        IF not v_test_re_pass THEN
           v_test_msg := pad("wrong RTL result for re_out, expected: " & to_hstring(s_re_slice) & " but got: " & to_hstring(s_re_out), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF;
        v_test_im_pass := s_im_slice = s_im_out;
        IF not v_test_im_pass THEN
           v_test_msg := pad("wrong RTL result for im_out, expected: " & to_hstring(s_im_slice) & " but got: " & to_hstring(s_im_out), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF;    
        o_test_pass <= v_test_re_pass or v_test_im_pass;
        wait for clk_period;
        tb_end <= '1';
        wait;
    END PROCESS;

    -- DUT
    u_dut : ENTITY work.c_to_ri
    GENERIC MAP(
        g_async => g_async,
        g_bit_width => g_bit_width
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        c_in => s_c_in,
        re_out => s_re_out,
        im_out => s_im_out
    );
end rtl;