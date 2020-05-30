LIBRARY ieee, vunit_lib;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
context vunit_lib.vunit_context;

ENTITY ip_cmult_infer_tb IS
	generic(
		runner_cfg : string;
		a_wd       : positive;
		b_wd       : positive
	);
END ip_cmult_infer_tb;

ARCHITECTURE behavior OF ip_cmult_infer_tb IS

	-- Component Declaration for the Unit Under Test (UUT)

	component ip_cmult_infer
		generic(
			AWIDTH : positive;
			BWIDTH : positive
		);
		port(
			clk    : in  std_logic;
			ar, ai : in  std_logic_vector(AWIDTH - 1 downto 0);
			br, bi : in  std_logic_vector(BWIDTH - 1 downto 0);
			rst    : in  std_logic;
			clken  : in  std_logic;
			pr, pi : out std_logic_vector(AWIDTH + BWIDTH downto 0)
		);
	end component ip_cmult_infer;

	--Inputs
	signal clk : std_logic                           := '0';
	signal ar  : std_logic_vector(a_wd - 1 downto 0) := (others => '0');
	signal ai  : std_logic_vector(a_wd - 1 downto 0) := (others => '0');
	signal br  : std_logic_vector(b_wd - 1 downto 0) := (others => '0');
	signal bi  : std_logic_vector(b_wd - 1 downto 0) := (others => '0');

	--Outputs
	signal pr : std_logic_vector(a_wd + b_wd downto 0);
	signal pi : std_logic_vector(a_wd + b_wd downto 0);

	-- Clock period definitions
	constant clk_period : time      := 10 ns;
	signal rst          : std_logic := '0';
	signal clken        : std_logic := '0';

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : ip_cmult_infer
		generic map(
			AWIDTH => a_wd,
			BWIDTH => b_wd
		)
		port map(
			clk   => clk,
			ar    => ar,
			ai    => ai,
			br    => br,
			bi    => bi,
			rst   => rst,
			clken => clken,
			pr    => pr,
			pi    => pi
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
