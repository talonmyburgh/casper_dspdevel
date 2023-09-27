
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_cmult_infer_rtl is 
    GENERIC(
        g_in_a_w           : POSITIVE := 8;    --! A input bit width
		g_in_b_w           : POSITIVE := 8;    --! B input bit width
        g_conjugate_b      : BOOLEAN  := FALSE --! Whether or not to conjugate B value
    );
    PORT(
        clk       : IN  STD_LOGIC;                                      --! Input clock signal
        in_ar     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);        --! Real input A
		in_ai     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0);        --! Imaginary input A
		in_br     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);        --! Real input B
		in_bi     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0);        --! Imaginary input B
        result_re : OUT STD_LOGIC_VECTOR(g_in_a_w + g_in_b_w DOWNTO 0); --! Real result
		result_im : OUT STD_LOGIC_VECTOR(g_in_a_w + g_in_b_w DOWNTO 0)  --! Imaginary result
    );
end entity ip_cmult_infer_rtl;

architecture RTL of ip_cmult_infer_rtl is
-- Insert the below before begin keyword in architecture
    signal ai_d, ai_dd, ai_ddd, ai_dddd                 : signed(g_in_a_w-1 downto 0);
    signal ar_d, ar_dd, ar_ddd, ar_dddd                 : signed(g_in_a_w-1 downto 0);
    signal bi_d, bi_dd, bi_ddd, br_d, br_dd, br_ddd     : signed(g_in_b_w-1 downto 0);
    signal addcommon                                    : signed(g_in_a_w downto 0);
    signal addr, addi                                   : signed(g_in_b_w downto 0);
    signal mult0, multr, multi, pr_int, pi_int          : signed(g_in_a_w+g_in_b_w downto 0);
    signal common, commonr1, commonr2                   : signed(g_in_a_w+g_in_b_w downto 0);
begin

-- Insert the below after begin keyword in architecture
process(clk)
 begin
   if rising_edge(clk) then
      ar_d   <= signed(in_ar);
      ar_dd  <= signed(ar_d);
      ai_d   <= signed(in_ai);
      ai_dd  <= signed(ai_d);
      br_d   <= signed(in_br);
      br_dd  <= signed(br_d);
      br_ddd <= signed(br_dd);
      bi_d   <= signed(in_bi);
      bi_dd  <= signed(bi_d);
      bi_ddd <= signed(bi_dd);
   end if;
end process;

-- Common factor (ar - ai) x bi, shared for the calculations
-- of the real and imaginary final products.
process(clk)
 begin
  if rising_edge(clk) then
      addcommon <= resize(ar_d, g_in_a_w+1) - resize(ai_d, g_in_a_w+1);
      mult0     <= addcommon * bi_dd;
      common    <= mult0;
 end if;
end process;

-- Real product
process(clk)
 begin
  if rising_edge(clk) then
      ar_ddd   <= ar_dd;
      ar_dddd  <= ar_ddd;
      addr     <= resize(br_ddd, g_in_b_w+1) - resize(bi_ddd, g_in_b_w+1);
      multr    <= addr * ar_dddd;
      commonr1 <= common;
      pr_int   <= multr + commonr1;
  end if;
end process;

-- Imaginary product
out_imag_conj : if g_conjugate_b generate
    process(clk)
    begin
    if rising_edge(clk) then
        ai_ddd   <= ai_dd;
        ai_dddd  <= - ai_ddd;
        addi     <= resize(br_ddd, g_in_b_w+1) + resize(bi_ddd, g_in_b_w+1);
        multi    <= addi * ai_dddd;
        commonr2 <= common;
        pi_int   <= multi - commonr2;
    end if;
    end process;
end generate;
out_imag : if g_conjugate_b=FALSE generate
    process(clk)
    begin
    if rising_edge(clk) then
        ai_ddd   <= ai_dd;
        ai_dddd  <= ai_ddd;
        addi     <= resize(br_ddd, g_in_b_w+1) + resize(bi_ddd, g_in_b_w+1);
        multi    <= addi * ai_dddd;
        commonr2 <= common;
        pi_int   <= multi + commonr2;
    end if;
    end process;
end generate;

result_re <= std_logic_vector(pr_int);
result_im <= std_logic_vector(pi_int);

end architecture RTL;
