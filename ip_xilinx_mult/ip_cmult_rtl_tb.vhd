LIBRARY ieee, vunit_lib;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
context vunit_lib.vunit_context;

ENTITY ip_cmult_rtl_tb IS
	generic(
		a_wd       : positive := 8;
		b_wd       : positive := 8;
		runner_cfg : string
	);
END ip_cmult_rtl_tb;

ARCHITECTURE behavior OF ip_cmult_rtl_tb IS

	-- Component Declaration for the Unit Under Test (UUT)

	component ip_cmult_rtl
		generic(
			g_in_a_w           : POSITIVE;
			g_in_b_w           : POSITIVE;
			g_out_p_w          : POSITIVE;
			g_conjugate_b      : BOOLEAN;
			g_pipeline_input   : NATURAL;
			g_pipeline_product : NATURAL;
			g_pipeline_adder   : NATURAL;
			g_pipeline_output  : NATURAL
		);
		port(
			rst       : IN  STD_LOGIC;
			clk       : IN  STD_LOGIC;
			clken     : IN  STD_LOGIC;
			in_ar     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);
			in_ai     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);
			in_br     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);
			in_bi     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);
			result_re : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0);
			result_im : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0)
		);
	end component ip_cmult_rtl;

	--Inputs
	signal clk : std_logic                           := '0';
	signal ar  : std_logic_vector(a_wd - 1 downto 0) := (others => '0');
	signal ai  : std_logic_vector(a_wd - 1 downto 0) := (others => '0');
	signal br  : std_logic_vector(b_wd - 1 downto 0) := (others => '0');
	signal bi  : std_logic_vector(b_wd - 1 downto 0) := (others => '0');

	--Outputs
	signal pr : std_logic_vector(a_wd + b_wd - 1 downto 0);
	signal pi : std_logic_vector(a_wd + b_wd - 1 downto 0);

	-- Clock period definitions
	constant clk_period : time      := 10 ns;
	signal rst          : std_logic := '0';
	signal clken        : std_logic := '0';

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : ip_cmult_rtl
		generic map(
			g_in_a_w           => a_wd,
			g_in_b_w           => b_wd,
			g_out_p_w          => a_wd + b_wd,
			g_conjugate_b      => FALSE,
			g_pipeline_input   => 1,
			g_pipeline_product => 0,
			g_pipeline_adder   => 1,
			g_pipeline_output  => 1
		)
		port map(
			rst       => rst,
			clk       => clk,
			clken     => clken,
			in_ar     => ar,
			in_ai     => ai,
			in_br     => br,
			in_bi     => bi,
			result_re => pr,
			result_im => pi
		);

	-- Clock process definitions
	clk_process : process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process;

	-- Stimulus process
	stim_proc : process
	begin
		test_runner_setup(runner, runner_cfg);
		-- hold reset state for 100 ns.
		wait for 100 ns;
		clken <= '1';
		rst   <= '1';
		wait for clk_period * 5;
		rst   <= '0';
		wait for clk_period * 5;

		-- insert stimulus here 
		ar <= std_logic_vector(to_signed(13, a_wd));
		ai <= std_logic_vector(to_signed(-4, a_wd));
		br <= std_logic_vector(to_signed(13, b_wd));
		bi <= std_logic_vector(to_signed(4, b_wd));

		wait for clk_period * 6;

		check(to_integer(signed(pr)) = 185, "Real multiplication incorrectly performed. Expected 185 but got " & to_hstring(pr));
		check(to_integer(signed(pi)) = 0, "Imaginary multiplication incorrectly performed. Exepected 0 but got " & to_hstring(pr));
		
		test_runner_cleanup(runner);
	end process;

END;
