LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY lpm;
USE lpm.lpm_components.ALL;

-- Comments:
-- . Directly instantiate LPM component, because MegaWizard does so too, see dsp_mult.vhd.
-- . Use MegaWizard to learn more about the generics.
-- . Strangely the MegaWizard does not support setting the rounding and saturation mode
 ENTITY  ip_stratixiv_mult IS 
  GENERIC (
    g_in_a_w           : POSITIVE := 18;
    g_in_b_w           : POSITIVE := 18;
    g_out_p_w          : POSITIVE := 36;      -- c_prod_w = g_in_a_w+g_in_b_w, use smaller g_out_p_w to truncate MSbits, or larger g_out_p_w to extend MSbits
    g_nof_mult         : POSITIVE := 1;       -- using 2 for 18x18, 4 for 9x9 may yield better results when inferring * is used
    g_pipeline_input   : NATURAL  := 1;        -- 0 or 1
    g_pipeline_product : NATURAL  := 1;        -- 0 or 1
    g_pipeline_output  : NATURAL  := 1;        -- >= 0
    g_representation   : STRING   := "SIGNED"   -- or "UNSIGNED"
  );
  PORT (
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    in_a       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_a_w-1 DOWNTO 0);
    in_b       : IN  STD_LOGIC_VECTOR(g_nof_mult*g_in_b_w-1 DOWNTO 0);
    out_p      : OUT STD_LOGIC_VECTOR(g_nof_mult*(g_in_a_w+g_in_b_w)-1 DOWNTO 0)
  );
 END ip_stratixiv_mult;


ARCHITECTURE str OF ip_stratixiv_mult IS
  
  CONSTANT c_pipeline : NATURAL := g_pipeline_input + g_pipeline_product + g_pipeline_output;
  
  -- When g_out_p_w < g_in_a_w+g_in_b_w then the LPM_MULT truncates the LSbits of the product. Therefore
  -- define c_prod_w to be able to let common_mult truncate the LSBits of the product.
  CONSTANT c_prod_w : NATURAL := g_in_a_w + g_in_b_w;
  
  SIGNAL prod  : STD_LOGIC_VECTOR(g_nof_mult*c_prod_w-1 DOWNTO 0);
  
BEGIN

  gen_mult : FOR I IN 0 TO g_nof_mult-1 GENERATE
    m : lpm_mult
    GENERIC MAP (
      lpm_hint => "MAXIMIZE_SPEED=5",   -- default "UNUSED"
      lpm_pipeline => c_pipeline,
      lpm_representation => g_representation,
      lpm_type => "LPM_MULT",
      lpm_widtha => g_in_a_w,
      lpm_widthb => g_in_b_w,
      lpm_widthp => c_prod_w
    )
    PORT MAP (
      clock => clk,
      datab => in_b((I+1)*g_in_b_w-1 DOWNTO I*g_in_b_w),
      clken => clken,
      dataa => in_a((I+1)*g_in_a_w-1 DOWNTO I*g_in_a_w),
      result => prod((I+1)*c_prod_w-1 DOWNTO I*c_prod_w)
    );

    
    out_p <= prod;
---- Truncate MSbits, also for signed (common_pkg.vhd for explanation of RESIZE_SVEC)
--    out_p((I+1)*g_out_p_w-1 DOWNTO I*g_out_p_w) <= RESIZE_SVEC(prod((I+1)*c_prod_w-1 DOWNTO I*c_prod_w), g_out_p_w) WHEN g_representation="SIGNED" ELSE
--                                                   RESIZE_UVEC(prod((I+1)*c_prod_w-1 DOWNTO I*c_prod_w), g_out_p_w);
  END GENERATE;
  
END str;
