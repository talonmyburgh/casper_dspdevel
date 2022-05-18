-- A VHDL implementation of the CASPER c_to_ri block.
-- @author: Mydon Solutions.

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity c_to_ri is
    generic(
        g_async : BOOLEAN := FALSE;
        g_bit_width : NATURAL := 8
    );
    port (
        clk : IN std_logic;
        ce :  IN std_logic;
        c_in : IN std_logic_vector;
        re_out : OUT std_logic_vector(g_bit_width - 1 DOWNTO 0);
        im_out : OUT std_logic_vector(g_bit_width - 1 DOWNTO 0)
    );
end c_to_ri;

architecture rtl of c_to_ri is
    constant c_c_in_len : NATURAL := c_in'LENGTH;
    signal s_re_out : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);
    signal s_im_out : STD_LOGIC_VECTOR(g_bit_width - 1 DOWNTO 0);
    signal s_c_in   : STD_LOGIC_VECTOR(c_in'RANGE);

begin
    assert g_bit_width <= c_c_in_len report "Cannot request a bit_width larger than c_in'RANGE" severity failure;
    --------------------------------------------------------
    -- Asynchronous operation
    --------------------------------------------------------
    async : IF g_async = TRUE GENERATE
        s_re_out <= c_in(c_c_in_len - 1 DOWNTO c_c_in_len - g_bit_width);    
        s_im_out <= c_in(g_bit_width -1 DOWNTO 0);    
    END GENERATE;

    --------------------------------------------------------
    -- Synchronous operation
    --------------------------------------------------------
    sync : IF g_async = FALSE GENERATE
        sync_process: PROCESS (clk, ce)
        begin
            s_c_in <= c_in;
            if rising_edge(clk) and ce='1' THEN
                s_re_out <= s_c_in(c_c_in_len - 1 DOWNTO c_c_in_len - g_bit_width);    
                s_im_out <= s_c_in(g_bit_width -1 DOWNTO 0);
            end if;
        end PROCESS;
    END GENERATE;
    
    re_out <= s_re_out;
    im_out <= s_im_out;

end architecture;