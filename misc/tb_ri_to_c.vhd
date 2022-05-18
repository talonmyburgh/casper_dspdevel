LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE IEEE.numeric_std.ALL;
USE STD.TEXTIO.ALL;

ENTITY tb_ri_to_c is
    GENERIC(
        g_async : BOOLEAN := FALSE;
        g_re_in_w : NATURAL := 4;
        g_im_in_w : NATURAL := 5;
        g_re_in_val : INTEGER := 12;
        g_im_in_val : INTEGER := -4
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_ri_to_c;

ARCHITECTURE rtl of tb_ri_to_c is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk     : STD_LOGIC := '0';
    SIGNAL ce      : STD_LOGIC := '0';
    SIGNAL tb_end  : STD_LOGIC := '0';
    SIGNAL s_re_in : STD_LOGIC_VECTOR(g_re_in_w - 1 DOWNTO 0);
    SIGNAL s_im_in : STD_LOGIC_VECTOR(g_im_in_w - 1 DOWNTO 0);
    SIGNAL s_c_out : STD_LOGIC_VECTOR(g_re_in_w + g_im_in_w - 1 DOWNTO 0);
    SIGNAL s_cat_res : STD_LOGIC_VECTOR(g_re_in_w + g_im_in_w - 1 DOWNTO 0);

begin
    
   clk       <= NOT clk OR tb_end AFTER clk_period / 2;

   o_rst <= not ce;
	o_clk <= clk;
	o_tb_end <= tb_end;

   s_cat_res <= s_re_in & s_im_in;

    p_stimuli : PROCESS
    VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE v_test_pass : BOOLEAN := True;
    BEGIN
        wait until falling_edge(clk);
        ce <= '1';
        s_re_in <= std_logic_vector(unsigned(to_signed(g_re_in_val,g_re_in_w)));
        s_im_in <= std_logic_vector(unsigned(to_signed(g_im_in_val,g_im_in_w)));
        if not g_async THEN
            WAIT for clk_period;
            WAIT UNTIL rising_edge(clk);
        end if;
        v_test_pass := s_c_out = s_cat_res;
        IF not v_test_pass THEN
           v_test_msg := pad("wrong RTL result, expected: " & to_hstring(s_cat_res) & " but got: " & to_hstring(s_c_out), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF;      
        o_test_pass <= v_test_pass;
        wait for clk_period;
        tb_end <= '1';
        wait;
    END PROCESS;

    -- DUT
    u_dut : ENTITY work.ri_to_c
    GENERIC MAP(
        g_async => g_async
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        re_in => s_re_in,
        im_in => s_im_in,
        c_out => s_c_out
    );
end rtl;