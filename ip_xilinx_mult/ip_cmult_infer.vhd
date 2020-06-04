--! @file
--! @brief Inference Complex Multiplier

--! Library IEEE
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
----------------------------------------------------------------------
--  DSP48 CMULT inference module for Xilinx chips
----------------------------------------------------------------------
--! Complex Multiplier:
--!    (pr+i.pi) = (ar+i.ai)*(br+i.bi)
--! This inference module is likely to be implemented in DSP48 elements
--! in Xilinx chips.

--! @dot 
--! digraph ip_mult_infer {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! ip_mult_infer;
--! node [shape=plaintext];
--! ar;
--! ai;
--! br;
--! bi;
--! clk;
--! rst;
--! clken;
--! pr;
--! pi;
--! clk -> ip_mult_infer;
--! clken -> ip_mult_infer;
--! ar -> ip_mult_infer;
--! ai -> ip_mult_infer;
--! br -> ip_mult_infer;
--! bi -> ip_mult_infer;
--! rst -> ip_mult_infer;
--! ip_mult_infer -> pr;
--! ip_mult_infer -> pi;
--!}
--! @enddot

entity ip_cmult_infer is
	generic(AWIDTH : natural := 18; --! A input bit width 
			BWIDTH : natural := 18 --! B input bit width
			);
	port(clk    : in  std_logic; --! Clock input
	     ar, ai : in  std_logic_vector(AWIDTH - 1 downto 0); --! Real and imaginary A inputs
	     br, bi : in  std_logic_vector(BWIDTH - 1 downto 0); --! Real and imaginary B inputs
	     rst    : in  std_logic; --! Reset signal
	     clken  : in  std_logic; --! Clock enable signal
		 pr, pi : out std_logic_vector(AWIDTH + BWIDTH downto 0) --! Real and imaginary Outputs
		 ); 

end ip_cmult_infer;
architecture rtl of ip_cmult_infer is
	signal ai_d, ai_dd, ai_ddd, ai_dddd             : signed(AWIDTH - 1 downto 0);
	signal ar_d, ar_dd, ar_ddd, ar_dddd             : signed(AWIDTH - 1 downto 0);
	signal bi_d, bi_dd, bi_ddd, br_d, br_dd, br_ddd : signed(BWIDTH - 1 downto 0);
	signal addcommon                                : signed(AWIDTH downto 0);
	signal addr, addi                               : signed(BWIDTH downto 0);
	signal mult0, multr, multi, pr_int, pi_int      : signed(AWIDTH + BWIDTH downto 0);
	signal common, commonr1, commonr2               : signed(AWIDTH + BWIDTH downto 0);

begin
	process(clk)
	begin
		report "reached clock tick on infer cmult for 0";
		if rising_edge(clk) then
			ar_d   <= signed(ar);
			ar_dd  <= signed(ar_d);
			ai_d   <= signed(ai);
			ai_dd  <= signed(ai_d);
			br_d   <= signed(br);
			br_dd  <= signed(br_d);
			br_ddd <= signed(br_dd);
			bi_d   <= signed(bi);
			bi_dd  <= signed(bi_d);
			bi_ddd <= signed(bi_dd);
		end if;
	end process;
	-- Common factor (ar - ai) x bi, shared for the calculations
	-- of the real and imaginary final products.
	--
	process(clk)
	begin
		report "reached clock tick on infer cmult for 1";
		if rising_edge(clk) then
			if (clken = '1') then
				addcommon <= resize(ar_d, AWIDTH + 1) - resize(ai_d, AWIDTH + 1);
				mult0     <= addcommon * bi_dd;
				common    <= mult0;
			elsif (rst = '1') then
				addcommon <= (others => '0');
				mult0     <= (others => '0');
				common    <= (others => '0');
			end if;
		end if;
	end process;
	-- Real product
	--
	process(clk)
	begin
		report "reached clock tick on infer cmult for 2";
		if rising_edge(clk) then
			if (clken = '1') then
				ar_ddd   <= ar_dd;
				ar_dddd  <= ar_ddd;
				addr     <= resize(br_ddd, BWIDTH + 1) - resize(bi_ddd, BWIDTH + 1);
				multr    <= addr * ar_dddd;
				commonr1 <= common;
				pr_int   <= multr + commonr1;
			elsif (rst = '1') then
				ar_ddd   <= (others => '0');
				ar_dddd  <= (others => '0');
				addr     <= (others => '0');
				multr    <= (others => '0');
				commonr1 <= (others => '0');
				pr_int   <= (others => '0');
			end if;
		end if;
	end process;
	-- Imaginary product
	--
	process(clk)
	begin
		report "reached clock tick on infer cmult for 3";
		if rising_edge(clk) then
			if (clken = '1') then
				report "reached clock enable on ip_cmult_infer";
				ai_ddd   <= ai_dd;
				ai_dddd  <= ai_ddd;
				addi     <= resize(br_ddd, BWIDTH + 1) + resize(bi_ddd, BWIDTH + 1);
				multi    <= addi * ai_dddd;
				commonr2 <= common;
				pi_int   <= multi + commonr2;
			elsif (rst = '1') then
				report "reached reset on ip_cmult_infer";
				ai_ddd   <= (others => '0');
				ai_dddd  <= (others => '0');
				addi     <= (others => '0');
				multi    <= (others => '0');
				commonr2 <= (others => '0');
				pi_int   <= (others => '0');
			end if;
		end if;
	end process;
	
	-- VHDL type conversion for output
	--
	pr <= std_logic_vector(pr_int);
	pi <= std_logic_vector(pi_int);
end rtl;