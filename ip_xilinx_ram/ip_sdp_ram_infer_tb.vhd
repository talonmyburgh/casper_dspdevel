library ieee, vunit_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
context vunit_lib.vunit_context;

entity ip_sdp_ram_infer_tb is
	generic(
	runner_cfg : string
	);
end entity ip_sdp_ram_infer_tb;

architecture RTL of ip_sdp_ram_infer_tb is
	-- Component Declaration for the Unit Under Test (UUT)

	component ip_sdp_ram_infer
		generic(
			addressWidth : natural;
			dataWidth    : natural
		);
		port(
			clkA  : in  std_logic;
			clkB  : in  std_logic;
			enA   : in  std_logic;
			enB   : in  std_logic;
			weA   : in  std_logic;
			addrA : in  std_logic_vector(addressWidth - 1 downto 0);
			addrB : in  std_logic_vector(addressWidth - 1 downto 0);
			diA   : in  std_logic_vector(dataWidth - 1 downto 0);
			doB   : out std_logic_vector(dataWidth - 1 downto 0)
		);
	end component ip_sdp_ram_infer;

	--Inputs
	signal addrA : std_logic_vector(4 downto 0) := (others => '0');
	signal addrB : std_logic_vector(4 downto 0) := (others => '0');
	signal clkA  : std_logic                    := '0';
	signal clkB  : std_logic                    := '0';
	signal diA   : std_logic_vector(7 downto 0) := (others => '0');
	signal enA   : std_logic                    := '0';
	signal enB   : std_logic                    := '0';
	signal weA   : std_logic                    := '0';

	--Outputs
	signal doB : std_logic_vector(7 downto 0);

	-- Clock period definitions
	constant clockA_period : time := 10 ns;
	constant clockB_period : time := 10 ns;

	constant add_w  : natural := 5;
	constant data_w : natural := 8;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : component ip_sdp_ram_infer
		generic map(
			addressWidth => add_w,
			dataWidth    => data_w
		)
		port map(
			clkA  => clkA,
			clkB  => clkB,
			enA   => enA,
			enB   => enB,
			weA   => weA,
			addrA => addrA,
			addrB => addrB,
			diA   => diA,
			doB   => doB
		);

	-- Clock process definitions
	clockA_process : process
	begin
		clkA <= '0';
		wait for clockA_period / 2;
		clkA <= '1';
		wait for clockA_period / 2;
	end process;

	clockB_process : process
	begin
		clkB <= '0';
		wait for clockB_period / 2;
		clkB <= '1';
		wait for clockB_period / 2;
	end process;

	-- Stimulus process
	stim_proc : process
	begin
		test_runner_setup(runner,runner_cfg);
		-- hold reset state for 100 ns.
		wait for 100 ns;

		wait for clockA_period * 10;

		-- insert stimulus here 
		enA   <= '1';
		weA   <= '1';
		addrA <= "00000";
		diA   <= "10101010";
		wait for clockA_period*2;
		diA   <= "11110000";
		addrA <= "00001";
		wait for clockA_period*2;
		diA   <= "00001111";
		addrA <= "00010";
		wait for clockA_period*2;
		enB   <= '1';
		addrB <= "00001";
		wait for clockB_period*2;
		check(doB = "11110000","data not read correctly from port A @ address "&to_string(addrB));
		wait for clockB_period*2;
		addrB <= "00000";
		wait for clockA_period*2;
		check(doB = "10101010","data not read correctly from port A @ address "&to_string(addrB));
		addrB <= "00010";
		wait for clockA_period*2;
		check(doB = "00001111","data not read correctly from port A @ address "&to_string(addrB));
		test_runner_cleanup(runner);
	end process;

end architecture RTL;
