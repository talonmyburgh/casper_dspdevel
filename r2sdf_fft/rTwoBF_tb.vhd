library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use common_pkg_lib.common_pkg.all;

entity rTwoBF_tb is
	generic(
		-- generics for tb
		g_width : natural := 8;
		-- generics for rTwoBF
		g_in_a_zdly  : natural := 0;    --! default 0, 1
		g_out_d_zdly : natural := 0     --! default 0, optionally use 1
	);
end entity rTwoBF_tb;

architecture arch of rTwoBF_tb is
	constant c_lower : integer := -1*(2**(g_width-1));
	constant c_upper : integer := 1*(2**(g_width-1));

	constant c_clk_period : time := 20 ns;
	signal tb_end : std_logic                     := '0';


	signal clk     : std_logic := '0';  --! Input clock source
	signal a    : std_logic_vector(g_width-1 downto 0);  --! Input signal A
	signal b    : std_logic_vector(g_width-1 downto 0);  --! Input signal B
	signal sel  : std_logic;         --! Select input
	signal val  : std_logic;  --! Select input for delay
	signal ovflw   : std_logic;			--! Overflow flag for addition/subtraction
	signal c   : std_logic_vector(g_width-1 downto 0);  --! Output signal c
	signal d   : std_logic_vector(g_width-1 downto 0);   --! Output signal d
	signal gold_ovflw : std_logic;			--! Overflow flag for addition/subtraction
begin

	clk    <= (not clk) or tb_end after c_clk_period / 2;

	r2BF : entity work.rTwoBF 
		generic map (
			g_in_a_zdly  => g_in_a_zdly,
			g_out_d_zdly => g_out_d_zdly
		)
		port map (
			clk    => clk,
			in_a   => a,
			in_b   => b,
			in_sel => sel,
			in_val => val,
			ovflw  => ovflw,
			out_c  => c,
			out_d  => d
	);
	
	stimuli : process--(clk)
		variable v_sum : integer;
		variable v_sub : integer;
	begin
		sel <= '1';
		val <= '0';
		gold_ovflw <= '0';
		a_loop : for a_iter in 0 to (2**g_width)-1 loop
			a <= TO_SVEC(a_iter - c_upper, g_width);
			b_loop : for b_iter in 0 to (2**g_width)-1 loop
				b <= TO_SVEC(b_iter - c_upper, g_width);
				v_sum := a_iter + b_iter - 2*c_upper;
				v_sub := a_iter - b_iter;

				if v_sum >= c_lower and v_sum < c_upper
				and v_sub >= c_lower and v_sub < c_upper then
					gold_ovflw <= '0';
				else
					gold_ovflw <= '1';
				end if;
				
				wait for 0.5*c_clk_period;
				assert ovflw = gold_ovflw severity failure;
				wait for 0.5*c_clk_period;
			end loop; -- b
		end loop; -- a

		tb_end <= '1';
		wait;
	end process stimuli;

end arch; -- arch
