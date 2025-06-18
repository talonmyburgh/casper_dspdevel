LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_sample_and_hold is
    GENERIC(
        g_period  : NATURAL := 1;
        g_dat_w   : NATURAL := 8;
        g_dat_val : INTEGER := 1
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_sample_and_hold;

ARCHITECTURE rtl of tb_sample_and_hold is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk       : STD_LOGIC := '0';
    SIGNAL ce        : STD_LOGIC := '0';
    SIGNAL tb_end    : STD_LOGIC := '0';
    SIGNAL s_in_sig  : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_out_sig : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
    SIGNAL s_exp_sig : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0) := (OTHERS => 'U');
    SIGNAL s_sync    : STD_LOGIC := '0';

begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= NOT ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    p_stimuli : PROCESS
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := TRUE;
    BEGIN
        s_exp_sig <= (OTHERS => '0');
        WAIT FOR clk_period;
        WAIT UNTIL falling_edge(clk);
        ce          <= '1';
        WAIT FOR clk_period;
        s_in_sig    <= TO_SVEC(g_dat_val, g_dat_w);
        WAIT UNTIL rising_edge(clk);
        s_sync      <= '1';
        WAIT FOR clk_period;

        s_sync      <= '0';
        s_exp_sig   <= TO_SVEC(g_dat_val, g_dat_w);
        s_in_sig    <= TO_SVEC(g_dat_val+1, g_dat_w);
        -- SIGNAL input should be held on output until period is over
        FOR I IN 0 TO g_period - 1 LOOP
            WAIT FOR clk_period;
        END LOOP;
        
        s_exp_sig   <= TO_SVEC(g_dat_val+1, g_dat_w);

        WAIT FOR clk_period;

        WAIT for clk_period * 2;
        tb_end      <= '1';
        WAIT;
    END PROCESS;

    
    p_verify : PROCESS(clk)
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    BEGIN
        v_test_pass := s_out_sig = s_exp_sig;
        if not v_test_pass then
            v_test_msg := pad("Sample and hold failed. Expected: " & to_hstring(s_exp_sig) & " but got: " & to_hstring(s_out_sig), o_test_msg'length, '.');
            REPORT "Sample and hold failed. Expected: " & to_hstring(s_exp_sig) & " but got: " & to_hstring(s_out_sig) severity failure;
        end if;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
    END PROCESS;

    u_sample_hold : ENTITY work.sample_and_hold
        GENERIC MAP(
            g_period => g_period
        )
        PORT MAP(
            clk     => clk,
            ce      => ce,
            in_sig  => s_in_sig,
            sync    => s_sync,
            out_sig => s_out_sig
        );
end rtl;
