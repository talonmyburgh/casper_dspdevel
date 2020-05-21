--------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
--------------------------------------------------------------------------------
--
-- Purpose: This unit performs the reordering and the separation for the two real
--          input option of the complex fft.
--          It can also perform only one of the two functions(specified via generics).
--
-- Description: The incoming data is written (normal or reordered, based on g_bit_flip)
--              to the first page of a dual page memory. When the first page is full, 
--              the write process will continue on the second page. Meanwhile the read 
--              process will start to read the first page. The read process can include 
--              the separation function or not(based on g_separate). 
--              The size of the dual page memory is determined by g_nof_points. 
--
-- Remarks: . This unit is only suitable for the pipelined fft (fft_r2_pipe).
-- 

library ieee, common_pkg_lib, casper_counter_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.fft_pkg.all;

entity fft_reorder_sepa_pipe is
  generic   (
    g_nof_points  : natural := 8;
    g_bit_flip    : boolean := true;  -- apply index flip to have bins in incrementing frequency order
    g_fft_shift   : boolean := false; -- apply fft_shift to have negative bin frequencies first for complex input
    g_dont_flip_channels : boolean := false;  -- set true to preserve the channel interleaving when g_bit_flip is true, otherwise the channels get separated in time when g_bit_flip is true
    g_separate    : boolean := true;  -- apply separation bins for two real inputs
    g_nof_chan    : natural := 0      -- Exponent of nr of subbands (0 means 1 subband, 1 => 2 sb, 2 => 4 sb, etc )
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    in_dat  : in  std_logic_vector;
    in_val  : in  std_logic;
    out_dat : out std_logic_vector;
    out_val : out std_logic
  );
end entity fft_reorder_sepa_pipe;

architecture rtl of fft_reorder_sepa_pipe is
   
  constant c_nof_channels : natural := 2**g_nof_chan;
  constant c_dat_w        : natural := in_dat'length;
  constant c_page_size    : natural := g_nof_points*c_nof_channels;
  constant c_adr_points_w : natural := ceil_log2(g_nof_points); 
  constant c_adr_chan_w   : natural := g_nof_chan; 
  constant c_adr_tot_w    : natural := c_adr_points_w + c_adr_chan_w;

  signal adr_points_cnt : std_logic_vector(c_adr_points_w -1 downto 0);
  signal adr_chan_cnt   : std_logic_vector(c_adr_chan_w   -1 downto 0);
  signal adr_tot_cnt    : std_logic_vector(c_adr_tot_w    -1 downto 0);

  signal adr_fft_flip   : std_logic_vector(c_adr_points_w-1 downto 0);
  signal adr_fft_shift  : std_logic_vector(c_adr_points_w-1 downto 0);
  
  signal next_page : std_logic;  
  
  signal cnt_ena   : std_logic; 

  signal wr_en     : std_logic;
  signal wr_adr    : std_logic_vector(c_adr_tot_w-1 downto 0);
  signal wr_dat    : std_logic_vector(c_dat_w-1 downto 0);

  signal rd_en     : std_logic;
  signal rd_adr_up   : std_logic_vector(c_adr_points_w downto 0);
  signal rd_adr_down : std_logic_vector(c_adr_points_w downto 0);  -- use intermediate rd_adr_down that has 1 bit extra to avoid truncation warning with TO_UVEC()
  signal rd_adr    : std_logic_vector(c_adr_tot_w-1 downto 0);
  signal rd_dat    : std_logic_vector(c_dat_w-1 downto 0);
  signal rd_val    : std_logic;
  
  signal out_dat_i : std_logic_vector(c_dat_w-1 downto 0);   
  signal out_val_i : std_logic; 
  
  type   state_type is (s_idle, s_run_separate, s_run_normal);

  type reg_type is record
    rd_en       : std_logic;   -- The read enable signal to read out the data from the dp memory
    switch      : std_logic;   -- Toggel register used for separate functionalilty
    count_up    : natural;     -- An upwards counter for read addressing
    count_down  : natural;     -- A downwards counter for read addressing
    count_chan  : natural;     -- Counter that holds the number of channels for reading. 
    state       : state_type;  -- The state machine. 
  end record;

  signal r, rin : reg_type;   

begin

  out_dat_i <= rd_dat;
  out_val_i <= rd_val;

  wr_dat    <= in_dat;
  wr_en     <= in_val;
  
  next_page <= '1' when unsigned(adr_tot_cnt) = c_page_size-1  and wr_en='1' else '0';

  adr_tot_cnt <= adr_chan_cnt & adr_points_cnt;
  
  adr_fft_flip <= flip(adr_points_cnt);      -- flip the addresses to perform the bit-reversed reorder
  adr_fft_shift <= fft_shift(adr_fft_flip);  -- invert MSbit for fft_shift
  
  gen_complex : if g_separate=false generate
    no_bit_flip : if g_bit_flip=false generate
      wr_adr <= adr_tot_cnt;
    end generate;
    gen_bit_flip_spectrum_and_channels : if g_bit_flip=true and g_dont_flip_channels=false generate -- the channels get separated in time
      gen_no_fft_shift_sac : if g_fft_shift=false generate
        wr_adr <= adr_chan_cnt & adr_fft_flip;
      end generate;
      gen_fft_shift_sac : if g_fft_shift=true generate
        wr_adr <= adr_chan_cnt & adr_fft_shift;
      end generate;
    end generate;
    gen_bit_flip_spectrum_only : if g_bit_flip=true and g_dont_flip_channels=true generate  -- the channel interleaving in time is preserved
      gen_no_fft_shift_so : if g_fft_shift=false generate
        wr_adr <= adr_fft_flip & adr_chan_cnt;
      end generate;
      gen_fft_shift_so : if g_fft_shift=true generate
        wr_adr <= adr_fft_shift & adr_chan_cnt;
      end generate;
    end generate;
  end generate;
  gen_two_real : if g_separate=true generate
    gen_bit_flip_spectrum_and_channels : if g_dont_flip_channels=false generate -- the channels get separated in time
      wr_adr <= adr_chan_cnt & adr_fft_flip;
    end generate;
    gen_bit_flip_spectrum_only : if g_dont_flip_channels=true generate  -- the channel interleaving in time is preserved
      wr_adr <= adr_fft_flip & adr_chan_cnt;
    end generate;
  end generate;
  
  u_adr_point_cnt : entity casper_counter_lib.common_counter
  generic map(
    g_latency   => 1,  
    g_init      => 0,
    g_width     => ceil_log2(g_nof_points)
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    cnt_en  => cnt_ena,
    count   => adr_points_cnt
  );
  
  -- Generate on c_nof_channels to avoid simulation warnings on TO_UINT(adr_chan_cnt) when adr_chan_cnt is a NULL array
  one_chan : if c_nof_channels=1 generate
    cnt_ena <= '1' when in_val = '1' else '0';
  end generate;
  more_chan : if c_nof_channels>1 generate
    cnt_ena <= '1' when in_val = '1' and TO_UINT(adr_chan_cnt) = c_nof_channels-1 else '0';
  end generate;
 
  u_adr_chan_cnt : entity casper_counter_lib.common_counter
  generic map(
    g_latency   => 1,  
    g_init      => 0,
    g_width     => g_nof_chan
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    cnt_en  => in_val,
    count   => adr_chan_cnt
  ); 
  
  u_buff : entity casper_ram_lib.common_paged_ram_r_w
  generic map (
    g_str             => "use_adr",
    g_data_w          => c_dat_w,
    g_nof_pages       => 2,
    g_page_sz         => c_page_size,
    g_wr_start_page   => 0,
    g_rd_start_page   => 1,
    g_rd_latency      => 1
  )
  port map (
    rst          => rst,
    clk          => clk,
    wr_next_page => next_page,
    wr_adr       => wr_adr,
    wr_en        => wr_en,
    wr_dat       => wr_dat,
    rd_next_page => next_page,
    rd_adr       => rd_adr,
    rd_en        => rd_en,
    rd_dat       => rd_dat,
    rd_val       => rd_val
  );
  
  -- If the separate functionality is enabled the read address will 
  -- be composed of an up and down counter that are interleaved. This is
  -- reflected in the s_run_separate state. 
  -- The process facilitates the first stage of the separate function
  -- It generates the read address in order to 
  -- create the data stream that is required for the separate
  -- block. The order for a 1024 ponit FFT is:
  -- X(0), X(1024), X(1), X(1023), X(2), X(1022), etc...              
  --          |
  --          |
  --       This value is X(0), because modulo N addressing is used. 
  --
  -- If separate functionality is disbaled a "normal" coun ter is used 
  -- to read out the dual page memory. State: s_run_normal
  
  comb : process(r, rst, next_page)
    variable v : reg_type;
  begin
  
    v := r;
    v.rd_en := '0';      
    
    case r.state is
	    when s_idle =>      
        if(next_page = '1') then               -- Both counters are reset on page turn. 
          v.rd_en        := '1';
          v.switch       := '0';
          v.count_up     := 0;
          if(g_separate=true) then             -- Choose the appropriate run state 
            v.count_chan := 0;
            v.count_down := g_nof_points;			  	
            v.state      := s_run_separate; 
          else           
            v.state      := s_run_normal; 
          end if;
        end if;
        
	    when s_run_separate =>    
        v.rd_en      := '1';
        if(r.switch = '0') then
          v.switch   := '1';
          v.count_up := r.count_up + 1; 
        end if; 

        if(r.switch = '1') then 
          v.switch     := '0';
          v.count_down := r.count_down - 1; 
        end if;                 
        
        if(next_page = '1') then                 -- Both counters are reset on page turn. 
          v.count_up   := 0;
          v.count_down := g_nof_points;
          v.count_chan := 0;         
        elsif(r.count_up = g_nof_points/2 and r.count_chan < c_nof_channels-1) then  -- 
          v.count_up   := 0; 
          v.count_down := g_nof_points;
          v.count_chan := r.count_chan + 1; 
        elsif(r.count_up = g_nof_points/2) then  -- Pagereading is done, but there is not yet new data available
          v.rd_en      := '0';   
          v.state      := s_idle;            
        end if;  
        
      when s_run_normal => 
        v.rd_en      := '1';        
        if(next_page = '1') then                -- Counters is reset on page turn.         
          v.count_up := 0;                    
        elsif(r.count_up = c_page_size-1) then  -- Pagereading is done, but there is not yet new data available 
          v.rd_en    := '0';   
          v.state    := s_idle;            
        else
          v.count_up := r.count_up + 1;         
        end if; 

	    when others =>
	  	  v.state := s_idle;

	  end case;
      
    if(rst = '1') then 
      v.switch     := '0';
      v.rd_en      := '0';
      v.count_up   := 0;
      v.count_down := 0; 
      v.count_chan := 0; 
      v.state      := s_idle;
    end if;

    rin <= v;  
 	    	
  end process comb;
  
  regs : process(clk)
  begin 
    if rising_edge(clk) then 
      r <= rin; 
    end if; 
  end process;

  rd_en  <= r.rd_en; 
  
  gen_separate : if g_separate=true generate     
    -- The read address toggles between the upcounter and the downcounter.
    -- Modulo N addressing is done with the TO_UVEC function.
    rd_adr_up   <= TO_UVEC(r.count_up,   c_adr_points_w+1);  -- eg.    0 .. 512
    rd_adr_down <= TO_UVEC(r.count_down, c_adr_points_w+1);  -- eg. 1024 .. 513, use 1 bit more to avoid truncation warning on 1024 ^= 0
    rd_adr <= TO_UVEC(r.count_chan, c_adr_chan_w) & rd_adr_up(  c_adr_points_w-1 DOWNTO 0) when r.switch = '0' else
              TO_UVEC(r.count_chan, c_adr_chan_w) & rd_adr_down(c_adr_points_w-1 DOWNTO 0);
    -- The data that is read from the memory is fed to the separate block
    -- that performs the 2nd stage of separation. The output of the 
    -- separate unit is connected to the output of rtwo_order_separate unit. 
    -- The 2nd stage of the separate funtion is performed:
    u_separate : entity work.fft_sepa
    port map (
      clk     => clk,
      rst     => rst,
      in_dat  => out_dat_i, 
      in_val  => out_val_i,
      out_dat => out_dat,
      out_val => out_val
    );                          
  end generate;                             
  
  -- If the separate functionality is disabled the 
  -- read address is received from the address counter and
  -- the output signals are directly driven. 
  gen_no_separate : if g_separate=false generate
    rd_adr  <= TO_UVEC(r.count_up, c_adr_tot_w);
    out_dat <= out_dat_i;
    out_val <= out_val_i;                   
  end generate;                                 

end rtl;


