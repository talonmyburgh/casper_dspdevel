LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_edge_detect is
    GENERIC(
        g_dat_w : NATURAL := 1;
        g_dat_val : NATURAL := 1
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_edge_detect;

ARCHITECTURE rtl of tb_edge_detect is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk                 : STD_LOGIC := '0';
    SIGNAL ce                  : STD_LOGIC := '0';
    SIGNAL tb_end              : STD_LOGIC := '0';
    SIGNAL s_in_sig            : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_test              : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_rise_high     : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_rise_low      : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_fall_low      : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_fall_high     : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_both_high     : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_dut_both_low      : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);

begin
    
    clk         <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst       <= NOT ce;
    o_clk       <= clk;
    o_tb_end    <= tb_end;

    p_stimuli : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN;
    BEGIN
        WAIT FOR clk_period;
        WAIT UNTIL falling_edge(clk);
        ce <= '1';
        WAIT FOR clk_period;
        -- Check for rising edge, high output detection
        s_in_sig <= (others=>'0');
        WAIT FOR clk_period;
        s_in_sig <= TO_SVEC(g_dat_val, g_dat_w);
        s_test   <= TO_SVEC(g_dat_val, g_dat_w);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := v_test_pass or (s_test = s_dut_rise_high);
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for rising edge detection, high output, expected: " 
                            & to_hstring(s_test) & " but got: " 
                            & to_hstring(s_dut_rise_high), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        v_test_pass := v_test_pass or (s_test = s_dut_both_high);
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for both edge detection, high output, expected: " 
                            & to_hstring(s_test) & " but got: " 
                            & to_hstring(s_dut_both_high), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        -- Check for falling edge, high output detection
        WAIT FOR clk_period;
        WAIT UNTIL rising_edge(clk);
        s_in_sig <= TO_SVEC(0, g_dat_w);
        s_test   <= TO_SVEC(g_dat_val, g_dat_w);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := v_test_pass or (s_test = s_dut_fall_high);
        IF NOT v_test_pass THEN
        v_test_msg := pad("wrong RTL result for falling edge detection, high output, expected: "
                         & to_hstring(s_test) & " but got: " 
                         & to_hstring(s_dut_fall_high), o_test_msg'length, '.');
            o_test_msg <= v_test_msg;
            report "Error: " & v_test_msg severity error;
        END IF; 
        v_test_pass := v_test_pass or (s_test = s_dut_both_high);
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for both edge detection, high output, expected: " 
                            & to_hstring(s_test) & " but got: " 
                            & to_hstring(s_dut_both_high), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        -- Check for rising edge, low output detection
        WAIT FOR clk_period;
        WAIT UNTIL rising_edge(clk);
        s_in_sig <= TO_SVEC(g_dat_val, g_dat_w);
        s_test   <= (others=>'0');
        WAIT UNTIL rising_edge(clk);
        v_test_pass := v_test_pass or (s_test = s_dut_rise_low);
        IF NOT v_test_pass THEN
        v_test_msg := pad("wrong RTL result for rising edge detection, low output, expected: "
                         & to_hstring(s_test) & " but got: " 
                         & to_hstring(s_dut_rise_low), o_test_msg'length, '.');
            o_test_msg <= v_test_msg;
            report "Error: " & v_test_msg severity error;
        END IF; 
        v_test_pass := v_test_pass or (s_test = s_dut_both_low);
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for both edge detection, low output, expected: " 
                            & to_hstring(s_test) & " but got: " 
                            & to_hstring(s_dut_both_low), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        -- Check for falling edge, low output detection
        WAIT FOR clk_period;
        WAIT UNTIL rising_edge(clk);
        s_in_sig <= TO_SVEC(0, g_dat_w);
        s_test   <= (others=>'0');
        WAIT UNTIL rising_edge(clk);
        v_test_pass := v_test_pass or (s_test = s_dut_fall_low);
        IF NOT v_test_pass THEN
        v_test_msg := pad("wrong RTL result for falling edge detection, low output, expected: "
                         & to_hstring(s_test) & " but got: " 
                         & to_hstring(s_dut_fall_low), o_test_msg'length, '.');
            o_test_msg <= v_test_msg;
            report "Error: " & v_test_msg severity error;
        END IF; 
        v_test_pass := v_test_pass or (s_test = s_dut_both_low);
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for both edge detection, low output, expected: " 
                            & to_hstring(s_test) & " but got: " 
                            & to_hstring(s_dut_both_low), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        o_test_pass <= v_test_pass;
        WAIT for clk_period *2;
        tb_end <= '1';
        WAIT;
    END PROCESS;

    u_fall_low : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "falling",
        g_output_pol => "low"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_fall_low
    );

    u_fall_high : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "falling",
        g_output_pol => "high"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_fall_high
    );

    u_rise_high : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "rising",
        g_output_pol => "high"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_rise_high
    );

    u_rise_low : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "rising",
        g_output_pol => "low"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_rise_low
    );

    u_both_low : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "both",
        g_output_pol => "low"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_both_low
    );

    u_both_high : ENTITY work.edge_detect
    GENERIC MAP(
        g_edge_type => "both",
        g_output_pol => "high"
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_sig => s_in_sig,
        out_sig => s_dut_both_high
    );
end rtl;