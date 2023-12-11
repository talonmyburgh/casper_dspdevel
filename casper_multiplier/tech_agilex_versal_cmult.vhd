--------------------------------------------------------------------------------
-- NRAO ngVLA
-- SiriusHDL Library
-- 
--------------------------------------------------------------------------------
--
-- Unit name:   math_complex_mult_1_0
-- Created by: Matthew Schiller
-- Created on: December 28, 2022
-- Description: Implements a complex multiplier
-- Features
-- Input A = 19 bits or less (Intel =19, Xilinx = 18)
-- Input B = 18 bits or less 
--
-- Inputs can be full complex (seperate I/Q inputs) or
-- The I input can be time-multiplexed I/Q (use I/Q input to indicate which)
-- (Multiplication always should start with I)
-- 
-- Intended for use with Intel AGILEX DSPs in Intel mode and Versal Premium in Xilinx MOde
--------------------------------------------------------------------------------
-- Copyright NRAO 12/28/2022
--------------------------------------------------------------------------------
--
--
-- Interface when in Time-multiplex mode (g_use_timemultiplexed_IQ=true)
--                   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┆┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  
--i_clk            : ┘  └──┘  └──┘  └──┘  └──┘  └──┆┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
--                   xxxxxxxxxxxx╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxx╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataA_real     : xxxxxxxxxxxx╲AI1 ╱╲AQ1 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxx╲AI2 ╱╲AQ2 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataA_imag     : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxx╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxx╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataB_real     : xxxxxxxxxxxx╲BI1 ╱╲BQ1 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxx╲BI2 ╱╲BQ2 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataB_imag     : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                               ┌───────────┐                             ┆      ┌───────────┐                             
--i_data_valid     : ────────────┘           └─────────────────────────────┆──────┘           └─────────────────────────────
--                                     ┌─────┐                             ┆            ┌─────┐                             
--i_time_mult_flag : ──────────────────┘     └─────────────────────────────┆────────────┘     └─────────────────────────────
--
--                   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╱    ╲╱    ╲xxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╱    ╲╱    ╲xxxxxx
--o_data_real      : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╲OI1 ╱╲OQ1 ╱xxxxxx┆xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╲OI2 ╱╲OQ2 ╱xxxxxx
--                                                       ┌───────────┐     ┆                              ┌───────────┐     
--o_data_valid     : ────────────────────────────────────┘           └─────┆──────────────────────────────┘           └─────
--                                                             ┌─────┐     ┆                                    ┌─────┐     
--o_time_mult_flag : ──────────────────────────────────────────┘     └─────┆────────────────────────────────────┘     └─────
--
-- Note: The I/Q pairs MUST occur as pairs  It's an error to provide I and then drop the valid between I/Q
-- The multiplier will assert an error if this occurs and will produce invalid data.


--
-- Interface when in Normal Multiplier Mode (g_use_timemultiplexed_IQ=false))
--                   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┆┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  
--i_clk            : ┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┆┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
--                   xxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataA_real     : xxxxxxxxxxxx╲AI1 ╱╲AI2 ╱╲AI3 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╲AI4 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataA_imag     : xxxxxxxxxxxx╲AQ1 ╱╲AQ2 ╱╲AQ3 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╲AQ4 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataB_real     : xxxxxxxxxxxx╲BI1 ╱╲BI2 ╱╲BI3 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╲BI4 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   xxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╱    ╲xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--i_dataB_imag     : xxxxxxxxxxxx╲BQ1 ╱╲BQ2 ╱╲BQ3 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx┆╲BQ5 ╱xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--                   ┐           ┌─────────────────┐                             ┆┌─────┐                             
--i_data_valid     : ────────────┘                 └─────────────────────────────┆┘     └─────────────────────────────
--
--                   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxx┆xxxxxxxxxxxxxxxxxx╱    ╲xxxxxxxxxxxx
--o_data_real      : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╲OI1 ╱╲OI2 ╱╲OI3 ╱xxxxxx┆xxxxxxxxxxxxxxxxxx╲OI4 ╱xxxxxxxxxxxx
--                   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╱    ╲╱    ╲╱    ╲xxxxxx┆xxxxxxxxxxxxxxxxxx╱    ╲xxxxxxxxxxxx
--o_data_imag      : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx╲OQ1 ╱╲OQ2 ╱╲OQ3 ╱xxxxxx┆xxxxxxxxxxxxxxxxxx╲OQ4 ╱xxxxxxxxxxxx
--                                                       ┌─────────────────┐     ┆                  ┌─────┐           
--o_data_valid     : ────────────────────────────────────┘                 └─────┆──────────────────┘     └───────────

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library common_pkg_lib;
use common_pkg_lib.common_pkg.all;

entity tech_agilex_versal_cmult is
  generic (
    g_is_xilinx               : boolean;  -- When true= a Xilinx (versal) is targeted, when false = an Intel AgileX is targeted
    g_inputA_width            : integer range 1 to 19;  
    g_inputB_width            : integer range 1 to 18;
    g_desired_pipedelay       : integer;
    g_pipe_width              : natural := 1

    );
  
  port(
    i_clk                     : in  std_logic;
    --i_reset                   : in  std_logic;
    
    i_dataA_real              : in  signed(g_inputA_width-1 downto 0);  --aka "a" in (a+bj) * (c+dj)
    i_dataA_imag              : in  signed(g_inputA_width-1 downto 0);  --aka "b" in (a+bj) * (c+dj)
    i_dataB_real              : in  signed(g_inputB_width-1 downto 0);  --aka "c" in (a+bj) * (c+dj)
    i_dataB_imag              : in  signed(g_inputB_width-1 downto 0);  --aka "d" in (a+bj) * (c+dj)
    i_data_valid              : in  std_logic;  -- when g_use_timemultiplexed_IQ=false this is only pipelined through and does not affect logic.
    i_pipe                    : in  std_logic_vector(g_pipe_width-1 downto 0) := (others => '0');
    
    
    o_data_real               : out signed(g_inputA_width+g_inputB_width downto 0);
    o_data_imag               : out signed(g_inputA_width+g_inputB_width downto 0);
    o_data_valid              : out std_logic; -- when 0 output is "real" (I) when '1' output is "imag" (Q).  Basically TLAST for each pair.
    o_pipe                    : out std_logic_vector(g_pipe_width-1 downto 0)

  );
end entity tech_agilex_versal_cmult;

architecture tech_agilex_versal_cmult_arch of tech_agilex_versal_cmult is
begin

versal_generate_notm_gen : if g_is_xilinx  generate

-- Note on UltraScale if you use this block (set g_is_xilinx=true) this should create
-- a 3 multiplier complex multiplier
-- But on Versal this should target the special complex multiplier mode.

  -- This code was based on a vivado 2022.2 Language Template.
  constant c_versal_max_width : integer := 18;
  constant c_versal_pipe_delay: integer := 4;
  type t_pipe_slv is array (c_versal_pipe_delay-1 downto 0) of std_logic_vector(g_pipe_width downto 0);
  signal pipe_d               : t_pipe_slv;
  signal  ar                  : signed(c_versal_max_width-1 downto 0); 
  signal  ai                  : signed(c_versal_max_width-1 downto 0); 
  signal  br                  : signed(c_versal_max_width-1 downto 0); 
  signal  bi                  : signed(c_versal_max_width-1 downto 0); 

  signal	pr 	                : signed (c_versal_max_width+c_versal_max_width downto 0) ; 
  signal	pi 	                : signed (c_versal_max_width+c_versal_max_width downto 0) ; 

  signal ar_d,ar_dd           : signed (c_versal_max_width-1 downto 0) ;
  signal ai_d,ai_dd           : signed (c_versal_max_width-1 downto 0) ;
  signal br_d                 : signed (c_versal_max_width-1 downto 0) ;
  signal bi_d,bi_dd           : signed (c_versal_max_width-1 downto 0) ;

  signal addcommon            : signed (c_versal_max_width downto 0) ;
  signal addr			            : signed (c_versal_max_width downto 0) ;
  signal addi			            : signed (c_versal_max_width downto 0) ;

  signal multcommon	          : signed (c_versal_max_width+c_versal_max_width downto 0) ;
  signal multr			          : signed (c_versal_max_width+c_versal_max_width downto 0) ;
  signal multi			          : signed (c_versal_max_width+c_versal_max_width downto 0) ;

  signal multcommon_d	        : signed (c_versal_max_width+c_versal_max_width downto 0) ;
  signal multr_d			        : signed (c_versal_max_width+c_versal_max_width downto 0) ;
  signal multi_d			        : signed (c_versal_max_width+c_versal_max_width downto 0) ;

  attribute keep              : string;
  attribute keep of ar        : signal is "true";
  attribute keep of br        : signal is "true";
  attribute keep of ai        : signal is "true";
  attribute keep of bi        : signal is "true";
  begin
    assert g_desired_pipedelay=c_versal_pipe_delay report " In Versal mode only pipe depth 4 is supported!" severity failure;
    assert g_inputA_width<=18 report "In Versal mode the complex multiplier must be 18x18 or smaller!" severity failure;
    ar                      <= resize(i_dataA_real,ar'length);
    ai                      <= resize(i_dataA_imag,ai'length);
    bi                      <= resize(i_dataB_imag,bi'length);
    br                      <= resize(i_dataB_real,br'length);
    --Inputs are registered AREG=BREG=2
    cmplmult_input_regs_versal : process(i_clk)
    begin
      if i_clk'event and i_clk = '1' then
        pipe_d(0)                         <= i_pipe & i_data_valid;
        pipe_d(pipe_d'length-1 downto 1)  <= pipe_d(pipe_d'length-2 downto 0);
        ar_d                              <= ar; 
        ar_dd                             <= ar_d;
        ai_d                              <= ai;
        ai_dd                             <= ai_d;
        bi_d                              <= bi;
        bi_dd                             <= bi_d;
        br_d                              <= br; 
      end if;
    end process cmplmult_input_regs_versal;

    --Fully Pipelined ADREG=1
    cmplmult_adreg_versal : process(i_clk)
    begin
      if i_clk'event and i_clk = '1' then
        addcommon                         <= resize(ar_d,c_versal_max_width+1) - resize(ai_d,c_versal_max_width+1);
        addr                              <= resize(br_d,c_versal_max_width+1) - resize(bi_d,c_versal_max_width+1);
        addi                              <= resize(br_d,c_versal_max_width+1) + resize(bi_d,c_versal_max_width+1);
      end if;     
    end process cmplmult_adreg_versal;


    --Common factor (ar-ai)*bi, shared for calculations of real & imaginary final
    --products
    multcommon                            <= bi_dd * addcommon;

    multr                                 <= ar_dd * addr;
    multi                                 <= ai_dd * addi;

    --Multiplier output is registered MREG=1
   cmplmult_mreg_versal : process(i_clk)
    begin
      if i_clk'event and i_clk ='1' then
        multcommon_d                      <= multcommon;
        multr_d                           <= multr;
        multi_d                           <= multi;
      end if;
    end process;

    --Complex outputs are registered PREG=1
    cmplmult_oreg_versal : process(i_clk)
    begin
      if i_clk'event and i_clk = '1' then
        pr                                <=  multcommon_d + multr_d ;
        pi                                <=  multcommon_d + multi_d ;
      end if;
    end process cmplmult_oreg_versal;
    o_data_real                           <= pr(o_data_real'length-1 downto 0);
    o_data_imag                           <= pi(o_data_imag'length-1 downto 0);
    o_pipe                                <= pipe_d(c_versal_pipe_delay-1)(g_pipe_width downto 1);
    o_data_valid                          <= pipe_d(c_versal_pipe_delay-1)(0);
end generate versal_generate_notm_gen; 

agilex_generate_notm_gen : if g_is_xilinx=false generate
  constant c_agilex_max_width : integer := 18;
  constant c_agilex_pipe_delay: integer := 4;
  type t_pipe_slv is array (c_agilex_pipe_delay-1 downto 0) of std_logic_vector(g_pipe_width downto 0);
  type t_data_sa_wp1 is array (2 downto 0) of signed(c_agilex_max_width downto 0);
  type t_data_sa is array (2 downto 0) of signed(c_agilex_max_width-1 downto 0);
  signal pipe_d               : t_pipe_slv;
  signal ar_d_dsp0            : t_data_sa_wp1; -- The A input on AgileX can be 19 bits,
  signal ai_d_dsp0            : t_data_sa_wp1; 
  signal br_d_dsp0            : t_data_sa; -- The B input can not exceed 18 bits on AgileX
  signal bi_d_dsp0            : t_data_sa; 
  signal ar_d_dsp1            : t_data_sa_wp1; -- The A input on AgileX can be 19 bits,
  signal ai_d_dsp1            : t_data_sa_wp1; 
  signal br_d_dsp1            : t_data_sa; -- The B input can not exceed 18 bits on AgileX
  signal bi_d_dsp1            : t_data_sa;   
  signal multI1               : signed(c_agilex_max_width+c_agilex_max_width downto 0);
  signal multI2               : signed(c_agilex_max_width+c_agilex_max_width downto 0);
  signal multQ1               : signed(c_agilex_max_width+c_agilex_max_width downto 0);
  signal multQ2               : signed(c_agilex_max_width+c_agilex_max_width downto 0);
  signal out_real             : signed(c_agilex_max_width+c_agilex_max_width+1 downto 0);
  signal out_imag             : signed(c_agilex_max_width+c_agilex_max_width+1 downto 0);
  signal  ar                  : signed(c_agilex_max_width downto 0); 
  signal  ai                  : signed(c_agilex_max_width downto 0); 
  signal  br                  : signed(c_agilex_max_width-1 downto 0); 
  signal  bi                  : signed(c_agilex_max_width-1 downto 0); 
  attribute keep              : string;
  attribute keep of ar        : signal is "true";
  attribute keep of br        : signal is "true";
  attribute keep of ai        : signal is "true";
  attribute keep of bi        : signal is "true";
  
  begin
    gen_input_logic: if g_desired_pipedelay<6 generate
    begin
      ar                      <= resize(i_dataA_real,ar'length);
      ai                      <= resize(i_dataA_imag,ai'length);
      bi                      <= resize(i_dataB_imag,bi'length);
      br                      <= resize(i_dataB_real,br'length);
    else generate -- use input reg when g_desired_pipedelay=6
      reg_input_proc : process (i_clk)
      begin
        if rising_edge(i_clk) then
          ar                  <= resize(i_dataA_real,ar'length);
          ai                  <= resize(i_dataA_imag,ai'length);
          bi                  <= resize(i_dataB_imag,bi'length);
          br                  <= resize(i_dataB_real,br'length);
        end if;
      end process reg_input_proc;
    end generate gen_input_logic;


    assert (g_desired_pipedelay=c_agilex_pipe_delay or g_desired_pipedelay=c_agilex_pipe_delay+1 or g_desired_pipedelay=c_agilex_pipe_delay+2) report " In AgileX mode only pipe depth 4,5 or 6 is supported!" severity failure;

    cmplmult_input_regs_agilex : process (i_clk)
    begin
      if rising_edge(i_clk) then
        -- dsp0 AND dsp1 BOTH get the same data, but the inputs are "mixed" up into the multiplier
        -- we probably don't need to declare both here, but just incase we do.
        ar_d_dsp0                         <= ar_d_dsp0(1 downto 0) & ar;
        ai_d_dsp0                         <= ai_d_dsp0(1 downto 0) & ai;
        br_d_dsp0                         <= br_d_dsp0(1 downto 0) & br;
        bi_d_dsp0                         <= bi_d_dsp0(1 downto 0) & bi;
        ar_d_dsp1                         <= ar_d_dsp1(1 downto 0) & ar;
        ai_d_dsp1                         <= ai_d_dsp1(1 downto 0) & ai;
        br_d_dsp1                         <= br_d_dsp1(1 downto 0) & br;
        bi_d_dsp1                         <= bi_d_dsp1(1 downto 0) & bi;
        pipe_d(0)                         <= i_pipe & i_data_valid;
        pipe_d(pipe_d'length-1 downto 1)  <= pipe_d(pipe_d'length-2 downto 0);
      end if;
    end process cmplmult_input_regs_agilex;
    multI1                                <= ar_d_dsp0(2) * br_d_dsp0(2);
    multI2                                <= ai_d_dsp0(2) * bi_d_dsp0(2);
    multQ1                                <= ar_d_dsp0(2) * bi_d_dsp0(2);
    multQ2                                <= ai_d_dsp0(2) * br_d_dsp0(2);    

    cmplmult_outpur_reg_agilex : process (i_clk)
    begin
      if rising_edge(i_clk) then
        out_real                          <= resize(multI1,out_real'length) - multI2;
        out_imag                          <= resize(multQ1,out_imag'length) + multQ2;
      end if;
    end process cmplmult_outpur_reg_agilex;

    gen_output_logic: if g_desired_pipedelay<5 generate
    begin
      o_data_real                           <= out_real(o_data_real'length-1 downto 0);
      o_data_imag                           <= out_imag(o_data_imag'length-1 downto 0);
      o_pipe                                <= pipe_d(c_agilex_pipe_delay-1)(g_pipe_width downto 1);
      o_data_valid                          <= pipe_d(c_agilex_pipe_delay-1)(0);
    else generate -- use input reg when g_desired_pipedelay=6
      reg_output_proc : process (i_clk)
      begin
        if rising_edge(i_clk) then
          o_data_real                       <= out_real(o_data_real'length-1 downto 0);
          o_data_imag                       <= out_imag(o_data_imag'length-1 downto 0);
          o_pipe                            <= pipe_d(c_agilex_pipe_delay-1)(g_pipe_width downto 1);
          o_data_valid                      <= pipe_d(c_agilex_pipe_delay-1)(0);
        end if;
      end process reg_output_proc;
    end generate gen_output_logic;

end generate agilex_generate_notm_gen;


        
          

end architecture tech_agilex_versal_cmult_arch;
