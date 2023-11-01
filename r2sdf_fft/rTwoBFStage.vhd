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

library ieee, common_pkg_lib, common_components_lib, technology_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
USE technology_lib.technology_select_pkg.ALL;
library casper_fifo_lib;
use ieee.numeric_std.all;
library casper_counter_lib;

entity rTwoBFStage is
	generic(
		-- generics for this stage
		g_nof_chan      : natural := 0; --! Exponent of nr of subbands (0 means 1 subband)
		g_stage         : natural;      --! The stage indices are ..., 3, 2, 1. The input stage has the highest index, the output stage has index 1.
		g_bf_lat        : natural := 1; --! Digital pipelining latency
		-- generics for rTwoBF
		g_bf_use_zdly   : natural := 1; --! >= 1. Stage high downto g_bf_use_zdly will will use g_bf_in_a_zdly and g_bf_out_zdly
		g_bf_in_a_zdly  : natural := 0; --! g_bf_in_a_zdly+g_bf_out_d_zdly must be <= the stage z^(-1) delay, note that stage 1 has only one z^(-1) delay
		g_bf_out_d_zdly : natural := 0; --! The stage z^(-1) delays are ..., 4, 2, 1.
		g_dsp_dly		: natural := 1	--! Butterfly units delay - expect timing failure for dsp_dly < 1 (ignored for non Xilinx designs)
	);
	port(
		clk     : in  std_logic;        --! Input clock source
		rst     : in  std_logic;        --! Reset signal
		in_re   : in  std_logic_vector; --! Real input
		in_im   : in  std_logic_vector; --! Imaginary input
		in_val  : in  std_logic;        --! Accept input value (for delay)
		in_sel  : in  std_logic;        --! Select input
    out_weight_addr : out  std_logic_vector(g_stage - 1 downto 1);
    out_start_frame : out  std_logic;
		out_re  : out std_logic_vector; --! Real output
		out_im  : out std_logic_vector; --! Imaginary output
		ovflw   : out std_logic;		--! Overflow detected in butterfly add/sub
		out_val : out std_logic;        --! Output value valid signal
		out_sel : out std_logic         --! Select output
	);
end entity rTwoBFStage;

architecture rTwoBFStage_arch of rTwoBFStage is
constant c_fifo_depth     : integer := pow2(g_stage - 1)*(2**g_nof_chan);
signal infifo_wr_data     : std_logic_vector(in_re'length+in_im'length-1 downto 0);
signal infifo_wr_en       : std_logic;
signal data_delay_re      : std_logic_vector(in_re'length-1 downto 0);
signal data_delay_re_d1   : std_logic_vector(in_re'length-1 downto 0);
signal data_delay_im      : std_logic_vector(in_im'length-1 downto 0);
signal data_delay_im_d1   : std_logic_vector(in_im'length-1 downto 0);
signal infifo_rd_en       : std_logic;
signal infifo_rd_data     : std_logic_vector(in_re'length+in_im'length-1 downto 0);
signal infifo_pipe_out    : std_logic_vector(in_re'length+in_im'length-1 downto 0);
signal infifo_rd_valid    : std_logic;
signal xa_re              : signed(in_re'length downto 0);
signal xa_im              : signed(in_re'length downto 0);
signal xb_re              : signed(in_re'length-1 downto 0);
signal xb_im              : signed(in_re'length-1 downto 0);
signal xab_valid          : std_logic;

signal out_zero_re        : signed(in_re'length downto 0);
signal out_zero_im        : signed(in_im'length downto 0);
signal out_one_re         : signed(in_re'length downto 0);
signal out_one_im         : signed(in_im'length downto 0);
signal out_one_two_valid  : std_logic;

signal out_fifo_zero_data : std_logic_vector(in_re'length+in_im'length downto 0);
signal out_fifo_one_data  : std_logic_vector(in_re'length+in_im'length downto 0);
signal out_fifo_wren      : std_logic;

signal fifo_zero_empty    : std_logic;

signal fifo_zero_rd_data  : std_logic_vector(in_re'length+in_im'length downto 0);
signal fifo_one_rd_data   : std_logic_vector(in_re'length+in_im'length downto 0);
signal fifo_one_rd_req    : std_logic;
signal fifo_one_rd_valid  : std_logic;
signal fifo_zero_rd_req   : std_logic;
signal fifo_zero_rd_valid : std_logic;


signal fifo_rd_cnt        : integer range 0 to c_fifo_depth;
type t_rstate is (idle,read_zero_start,read_zero,read_zero_slow,read_zero_slow_b,read_one);
signal rstate : t_rstate;
signal fifo_zero_almost_full : std_logic;

signal ctrl_sel : std_logic_vector(g_stage + g_nof_chan+4 downto 1);
signal weight_addr : std_logic_vector(g_stage - 1 downto 1);
signal cnt_en      : std_logic;
signal start_frame : std_logic;
signal fifo_error  : std_logic_vector(5 downto 0);
begin
-- data arrives on the in port.  in_sel='0' indicates first half, while in_sel='1' indicates second half.
-- We then need to provide output grouped together
-- Output out_Sel='0' = xa+xb (xa=first half + xb=second half)
-- output out_Sel='1' = xa-xb (first half - second half)

-- to accomplish that we'll feed the first half of the data into a fifo
-- then read the data from the fifo as the second half arrives
-- after the butterfly we'll have to store the xa-xb so we can get that data back out after outputing the xa-xb data

in_proc : process (clk)
begin
	if rising_edge(clk) then
		infifo_wr_data    <= in_re & in_im;
		infifo_wr_en      <= in_val and not in_sel;
    infifo_rd_en      <= in_val and in_sel;

    xa_re             <= resize(signed(infifo_rd_data(infifo_rd_data'length-1 downto in_im'length)),xa_re'length);
    xa_im             <= resize(signed(infifo_rd_data(in_im'length-1 downto 0)),xa_im'length);
    xb_re             <= signed(infifo_pipe_out(infifo_rd_data'length-1 downto in_im'length));
    xb_im             <= signed(infifo_pipe_out(in_im'length-1 downto 0));
    xab_valid         <= infifo_rd_valid;

    out_zero_re       <= xa_re+xb_re;
    out_zero_im       <= xa_im+xb_im;
    out_one_re        <= xa_re-xb_re;
    out_one_im        <= xa_im-xb_im;
    out_one_two_valid <= xab_valid;

    out_fifo_zero_data  <= '0' & std_logic_vector(out_zero_re(in_re'length-1 downto 0)) & std_logic_vector(out_zero_im(in_re'length-1 downto 0));
    out_fifo_one_data   <= '0' & std_logic_vector(out_one_re(in_re'length-1 downto 0)) & std_logic_vector(out_one_im(in_re'length-1 downto 0));
    out_fifo_wren       <= out_one_two_valid;

   
    if out_one_two_valid='1' then
      if out_zero_re(out_zero_re'length-1) /= out_zero_re(out_zero_re'length-2) then
        out_fifo_zero_data(out_fifo_zero_data'length-1)  <= '1';
      end if;
      if out_zero_im(out_zero_im'length-1) /= out_zero_im(out_zero_im'length-2) then
        out_fifo_zero_data(out_fifo_zero_data'length-1)  <= '1';
      end if;     
      if out_one_re(out_one_re'length-1) /= out_one_re(out_one_re'length-2) then
        out_fifo_one_data(out_fifo_one_data'length-1)    <= '1';
      end if;
      if out_one_im(out_one_im'length-1) /= out_one_im(out_one_im'length-2) then
        out_fifo_one_data(out_fifo_one_data'length-1)    <= '1';
      end if;
    end if;

  end if;
end process in_proc;

infifo_inst : entity casper_fifo_lib.siriushdl_fifo_sync_1_0
  generic map(
    g_data_width             => in_re'length + in_im'length,
    g_pipe_width             => infifo_wr_data'length,
    g_size                   => 2**ceil_log2(maximum(c_fifo_depth,32)),
    g_show_ahead             => false,
    g_almost_empty_threshold => 1,
    g_almost_full_threshold  => 1
  )
  port map(
    i_clk            => clk,
    i_reset          => rst,
    i_wr_data        => infifo_wr_data,
    i_wren           => infifo_wr_en,
    i_rden           => infifo_rd_en,
    i_rd_pipe        => infifo_wr_data,
    o_rd_data        => infifo_rd_data,
    o_rddata_valid   => infifo_rd_valid,
    o_rd_pipe        => infifo_pipe_out,
    o_empty          => open,
    o_full           => open,
    o_almost_empty   => open,
    o_almost_full    => open,
    o_count          => open,
    o_fifo_overflow  => fifo_error(0),
    o_fifo_underflow => fifo_error(1)
  );

assert_proc : process (clk)
variable first_reset_received : boolean := false;
begin
  if rising_edge(clk) then
    if rst='0' and first_reset_received then
      assert fifo_error="000000" report "Fifo Error! in BF" severity failure;
    end if;
    if rst='1' THEN
      first_reset_received := true;
    end if;
  end if;
end process assert_proc;

rd_cntrl_state : process (clk)
begin
  if rising_edge(clk) then
    fifo_zero_rd_req          <= '0';
    fifo_one_rd_req           <= '0';
    case rstate is
      when idle =>
        if fifo_zero_empty='0' then
          rstate               <= read_zero_start;
        end if;
      when read_zero_start =>
        if fifo_zero_empty='0' then
          fifo_zero_rd_req    <= '1';
          fifo_rd_cnt         <= 1;
          if fifo_zero_almost_full='1'then
            rstate            <= read_zero;
          else
            rstate            <= read_zero_slow;
          end if;
        end if;       
      when read_zero =>
        if fifo_rd_cnt = c_fifo_depth then
          fifo_one_rd_req     <= '1';
          fifo_rd_cnt         <= 1;
          rstate              <= read_one;
        else
          if fifo_zero_empty='0' then
            fifo_rd_cnt       <= fifo_rd_cnt + 1;
            fifo_zero_rd_req  <= '1';
            if fifo_zero_almost_full='0' then -- we might need to read slow to allow flags to update
              rstate        <= read_zero_slow;
            end if;
          end if;
        end if;
      when read_zero_slow =>
        if fifo_rd_cnt = c_fifo_depth then
          fifo_one_rd_req     <= '1';
          fifo_rd_cnt         <= 1;
          rstate              <= read_one;
        else
          rstate              <= read_zero_slow_b;
        end if;
      when read_zero_slow_b =>
        rstate                <= read_zero;
      when read_one =>
        -- for the one fifo we can just read like mad....
        if fifo_rd_cnt = c_fifo_depth THEN
          if fifo_zero_almost_full='1' then -- if we are filling up rush to read.
            fifo_rd_cnt       <= 1;
            rstate            <= read_zero;
            fifo_zero_rd_req  <= '1';
          else
            rstate            <= idle;
          end if;
        else
          fifo_rd_cnt         <= fifo_rd_cnt + 1;
          fifo_one_rd_req     <= '1';
        end if;
    end case;
    if rst='1' then
      rstate                  <= idle;
      fifo_one_rd_req         <= '0';
      fifo_zero_rd_req        <= '0';
    end if;
  end if;
end process rd_cntrl_state;

outzerofifo_inst : entity casper_fifo_lib.siriushdl_fifo_sync_1_0
  generic map(
    g_data_width             => in_re'length + in_im'length+1,
    g_pipe_width             => 1,
    g_size                   => 2**ceil_log2(maximum(c_fifo_depth+64,64)),
    g_show_ahead             => false,
    g_almost_empty_threshold => 1,
    g_almost_full_threshold  => 16
  )
  port map(
    i_clk            => clk,
    i_reset          => rst,
    i_wr_data        => out_fifo_zero_data,
    i_wren           => out_fifo_wren,
    i_rden           => fifo_zero_rd_req,
    i_rd_pipe        => "0",
    o_rd_data        => fifo_zero_rd_data,
    o_rddata_valid   => fifo_zero_rd_valid,
    o_rd_pipe        => open,
    o_empty          => fifo_zero_empty,
    o_full           => open,
    o_almost_empty   => open,
    o_almost_full    => fifo_zero_almost_full,
    o_count          => open,
    o_fifo_overflow  => fifo_error(2),
    o_fifo_underflow => fifo_error(3)
  );

outonefifo_inst : entity casper_fifo_lib.siriushdl_fifo_sync_1_0
  generic map(
    g_data_width             => in_re'length + in_im'length+1,
    g_pipe_width             => 1,
    g_size                   => 2**ceil_log2(maximum(c_fifo_depth+64,64)),
    g_show_ahead             => false,
    g_almost_empty_threshold => 1,
    g_almost_full_threshold  => 1
  )
  port map(
    i_clk            => clk,
    i_reset          => rst,
    i_wr_data        => out_fifo_one_data,
    i_wren           => out_fifo_wren,
    i_rden           => fifo_one_rd_req,
    i_rd_pipe        => "0",
    o_rd_data        => fifo_one_rd_data,
    o_rddata_valid   => fifo_one_rd_valid,
    o_rd_pipe        => open,
    o_empty          => open,
    o_full           => open,
    o_almost_empty   => open,
    o_almost_full    => open,
    o_count          => open,
    o_fifo_overflow  => fifo_error(4),
    o_fifo_underflow => fifo_error(5)
  );
    cnt_en <= fifo_one_rd_req or fifo_zero_rd_req;

		u_control : entity casper_counter_lib.common_counter
		generic map(
			g_latency   => 1,
			g_init      => 0,
			g_width     => g_stage + g_nof_chan+4,
			g_step_size => 1
		)
		port map(
			clken  => std_logic'('1'),
			rst    => rst,
			clk    => clk,
			cnt_en => cnt_en,
			count  => ctrl_sel
		);
  weight_addr 		<= ctrl_sel(g_stage + g_nof_chan - 1 downto g_nof_chan + 1);
	start_frame <= '1' when unsigned(ctrl_sel)=0 or ctrl_sel'length=0 else '0';

  u_pipeline_out : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => 3,
			g_in_dat_w  => weight_addr'length,
			g_out_dat_w => weight_addr'length
		)
		port map(
			clk     => clk,
			in_dat  => weight_addr,
			out_dat => out_weight_addr
		);
  u_pipeline_outsf : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => 3,
			g_in_dat_w  => 1,
			g_out_dat_w => 1
		)
		port map(
			clk     => clk,
			in_dat(0) => start_frame,
			out_dat(0) => out_start_frame
		);

  out_proc : process (clk)
  begin
    if rising_edge(clk) then
      out_val   <= '0';
      --out_weight_addr <= weight_addr;
      if fifo_zero_rd_valid='1' then
        out_re  <= fifo_zero_rd_data(fifo_zero_rd_data'length-2 downto in_re'length);
        out_im  <= fifo_zero_rd_data(in_re'length-1 downto 0);
        ovflw   <= fifo_zero_rd_data(fifo_zero_rd_data'length-1);
        out_sel <= '0';
        out_val <= '1';
      ELSIF fifo_one_rd_valid='1' then
        out_re  <= fifo_one_rd_data(fifo_one_rd_data'length-2 downto in_re'length);
        out_im  <= fifo_one_rd_data(in_re'length-1 downto 0);
        ovflw   <= fifo_one_rd_data(fifo_one_rd_data'length-1);
        out_sel <= '1';
        out_val <= '1';
      end if;
    end if;
  end process out_proc;
end architecture rTwoBFStage_arch;
