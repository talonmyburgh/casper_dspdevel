library ieee, vunit_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
context vunit_lib.vunit_context;

entity ip_tdp_ram_infer_tb is
	generic(
		runner_cfg : string
	);
end entity ip_tdp_ram_infer_tb;

architecture RTL of ip_tdp_ram_infer_tb is
	-- Component Declaration for the Unit Under Test (UUT)

	component ip_tdp_ram_infer
		generic(
			addressWidth : natural;
			dataWidth    : natural
		);
		port(
			addressA, addressB : in  std_logic_vector(addressWidth - 1 downto 0);
			clockA, clockB     : in  std_logic;
			dataA, dataB       : in  std_logic_vector(dataWidth - 1 downto 0);
			enA, enB   : in  std_logic;
			weA, weB       : in  std_logic;
			qA, qB             : out std_logic_vector(dataWidth - 1 downto 0)
		);
	end component ip_tdp_ram_infer;

	--Inputs
	signal addressA : std_logic_vector(4 downto 0) := (others => '0');
	signal addressB : std_logic_vector(4 downto 0) := (others => '0');
	signal clockA   : std_logic                    := '0';
	signal clockB   : std_logic                    := '0';
	signal dataA    : std_logic_vector(7 downto 0) := (others => '0');
	signal dataB    : std_logic_vector(7 downto 0) := (others => '0');
	signal enA  : std_logic                    := '0';
	signal enB  : std_logic                    := '0';
	signal weA    : std_logic                    := '0';
	signal weB    : std_logic                    := '0';

	--Outputs
	signal qA : std_logic_vector(7 downto 0);
	signal qB : std_logic_vector(7 downto 0);

	-- Clock period definitions
	constant clockA_period : time := 10 ns;
	constant clockB_period : time := 10 ns;

	constant add_w  : natural := 5;
	constant data_w : natural := 8;

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : ip_tdp_ram_infer
		generic map(
			addressWidth => add_w,
			dataWidth    => data_w
		)
		PORT MAP(
			addressA => addressA,
			addressB => addressB,
			clockA   => clockA,
			clockB   => clockB,
			dataA    => dataA,
			dataB    => dataB,
			enA  => enA,
			enB  => enB,
			weA    => weA,
			weB    => weB,
			qA       => qA,
			qB       => qB
		);

	-- Clock process definitions
	clockA_process : process
	begin
		clockA <= '0';
		wait for clockA_period / 2;
		clockA <= '1';
		wait for clockA_period / 2;
	end process;

	clockB_process : process
	begin
		clockB <= '0';
		wait for clockB_period / 2;
		clockB <= '1';
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
		enA <='1';
		enB <='1';
		addressA <= "00000";
		addressB <= "00001";
		dataA    <= "10101010";
		dataB    <= "11110000";
		wait for clockA_period*2;
		weA    <= '1';
		weB    <= '1';
		wait for clockB_period*2;
		weA <='0';
		weB <= '0';
		wait for clockA_period*2;
		addressA<="00001";
		addressB<="00000";
		wait for clockA_period*2;
		check(qA = dataB, "data not read correctly from port A, got "&to_hstring(qA)&" not "&to_hstring(dataB));
		check(qB = dataA,"data not read correctly from port B, got "&to_hstring(qB)&" not "&to_hstring(dataA));
		test_runner_cleanup(runner);
	end process;

end architecture RTL;
