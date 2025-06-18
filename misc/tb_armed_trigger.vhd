LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_armed_trigger is
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_armed_trigger;

ARCHITECTURE rtl of tb_armed_trigger is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk          : STD_LOGIC := '0';
    SIGNAL ce           : STD_LOGIC := '0';
    SIGNAL tb_end       : STD_LOGIC := '0';
    SIGNAL s_arm        : STD_LOGIC := '0';
    SIGNAL s_trig_in    : STD_LOGIC := '0';
    SIGNAL s_trig_out   : STD_LOGIC := '0';

begin
    
    clk         <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst       <= NOT ce;
    o_clk       <= clk;
    o_tb_end    <= tb_end;

    p_stimuli : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN;
    BEGIN
        WAIT UNTIL falling_edge(clk);
        ce <= '1';
        WAIT FOR clk_period;
        s_arm <= '1';
        WAIT FOR clk_period;
        s_trig_in <= '1';
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_trig_out = '1';
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for re_out, expected: " & std_logic'image('1') & " but got: " & std_logic'image(s_trig_out), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF;
        WAIT FOR clk_period;
        s_arm <= '0';
        WAIT FOR clk_period;
        s_trig_in <= '1';
        WAIT UNTIL rising_edge(clk);
        v_test_pass := v_test_pass or (s_trig_out = '0');
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for re_out, expected: " & std_logic'image('0') & " but got: " & std_logic'image(s_trig_out), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        o_test_pass <= v_test_pass;
        WAIT for clk_period;
        tb_end <= '1';
        WAIT;
    END PROCESS;

    -- DUT
    u_dut : ENTITY work.armed_trigger
    PORT MAP(
        clk => clk,
        ce => ce,
        arm => s_arm,
        trig_in => s_trig_in,
        trig_out => s_trig_out
    );
end rtl;