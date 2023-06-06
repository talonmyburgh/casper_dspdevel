LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

-- Purpose: Requantize the input data to the output data width by removing
--          LSbits and/or MSbits. Derived from common_requantize to just perform
--          a single RSHIFT and requantize. 

ENTITY r_shift_requantize IS
  GENERIC (
    g_lsb_round           : t_rounding_mode  := ROUND;  -- = ROUND, ROUNDINF or TRUNCATE
    g_lsb_round_clip      : BOOLEAN := FALSE;     -- when true round clip to +max to avoid wrapping to output -min (signed) or 0 (unsigned) due to rounding
    g_in_dat_w            : NATURAL := 17;        -- input data width
    g_out_dat_w           : NATURAL := 18         -- output data width
  );
  PORT (
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    scale      : IN  STD_LOGIC := '1';  -- remove LSB by way of rshift
    in_dat     : IN  STD_LOGIC_VECTOR;  -- unconstrained slv to also support widths other than g_in_dat_w by only using [g_in_dat_w-1:0] from the in_dat slv
    out_dat    : OUT STD_LOGIC_VECTOR  -- unconstrained slv to also support widths other then g_out_dat_w by resizing the result [g_out_dat_w-1:0] to the out_dat slv
  );
END;

ARCHITECTURE str OF r_shift_requantize IS

  -- Use c_lsb_w > 0 to remove LSBits and support c_lsb < 0 to shift in zero value LSbits as a gain
  SIGNAL res_dat       : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);  -- resulting out_dat after removing the g_msb_w number of MSBits

BEGIN
  -- Replace common_round, since we only shift down or not at all. Furthermore, we don't use the pipeline in this case.
  shift_proc : process(scale, in_dat)
  begin
    if scale = '1' then
        res_dat <= RESIZE_SVEC(s_round(in_dat, 1, g_lsb_round_clip, g_lsb_round), g_in_dat_w);
    else
        res_dat <= in_dat;
    end if;
  end process;
  out_dat <= RESIZE_SVEC(res_dat, g_out_dat_w);
END str;