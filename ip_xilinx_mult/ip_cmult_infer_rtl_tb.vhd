LIBRARY ieee,vunit_lib;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
context vunit_lib.vunit_context;

ENTITY ip_cmult_infer_tb IS
	generic(
		runner_cfg: string
	);
END ip_cmult_infer_tb;
 
ARCHITECTURE behavior OF ip_cmult_infer_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    component ip_cmult_infer_rtl
    	generic(
    		AWIDTH : natural;
    		BWIDTH : natural
    	);
    	port(
    		clk    : in  std_logic;
    		ar, ai : in  std_logic_vector(AWIDTH - 1 downto 0);
    		br, bi : in  std_logic_vector(BWIDTH - 1 downto 0);
    		rst    : in  std_logic;
    		clken  : in  std_logic;
    		pr, pi : out std_logic_vector(AWIDTH + BWIDTH downto 0)
    	);
    end component ip_cmult_infer_rtl;
    

   --Inputs
   signal clk : std_logic := '0';
   signal ar : std_logic_vector(17 downto 0) := (others => '0');
   signal ai : std_logic_vector(17 downto 0) := (others => '0');
   signal br : std_logic_vector(17 downto 0) := (others => '0');
   signal bi : std_logic_vector(17 downto 0) := (others => '0');

 	--Outputs
   signal pr : std_logic_vector(36 downto 0);
   signal pi : std_logic_vector(36 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
   signal rst : std_logic;
   signal clken : std_logic;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: ip_cmult_infer_rtl 	generic map(
   		AWIDTH => 18,
   		BWIDTH => 18
   	)
   PORT MAP (
          clk => clk,
          ar => ar,
          ai => ai,
          br => br,
          bi => bi,
          rst => rst,
          clken => clken,
          pr => pr,
          pi => pi
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin
   	test_runner_setup(runner, runner_cfg);		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 
        ar <= 18x"3E8";
        ai <= 18x"A";
        br <= 18x"A";
        bi <= 18x"3E8";
      	wait for clk_period*6;
      	check(pr = 37x"00", "Real multiplication incorrectly performed. Expected 37x00 but got "&to_hstring(pr));
      	check(pi = 37x"F42A4", "Imaginary multiplication incorrectly performed. Exepected 37xF42A4 but got "&to_hstring(pr));
      	test_runner_cleanup(runner);
   end process;

END;
