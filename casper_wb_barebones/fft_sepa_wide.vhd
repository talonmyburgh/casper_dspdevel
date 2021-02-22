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
-- Purpose: The fft_sepa_wide unit performs the separate function on the
--          output of a complex wideband fft in order to extract the spectrum
--          of the two real inputs A and B. Where A was fed to the real input 
--          of the complext wfft and B was fed to the imaginary input.
--          
--
-- Description: The incoming data is stored in a dual paged ram. For each output 
--              of the complex wfft a unique dual paged ram is instantiated. Once
--              the first page is written, the unit will read the data from the 
--              memory. 
--              The read process reads the memories in such a way that pairs of 
--              data are created that are required to generate the correct outputs. 
--              The data pairs are offered to the ZIP units that serialize the pairs. 
--              The serialized data is then offered to the separate units that outputs
--              the separated data in an interleaved stream: A, B, A, B etc (for both real and imaginary part) 
--              The last stage contains pipeline stages that are required for allignment
--              and additional pipeling.  
--

library ieee, common_pkg_lib, casper_counter_lib, common_components_lib, casper_ram_lib, casper_multiplexer_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;

entity fft_sepa_wide is
	generic(
		g_fft 			: t_fft  := c_fft;          -- generics for the FFT
		g_ram_primitive : string := "auto"
	);
	port(
		clken      : in  std_logic;
		clk        : in  std_logic;
		rst        : in  std_logic := '0';
		in_re_arr  : in  t_fft_slv_arr_stg(g_fft.wb_factor - 1 downto 0);
		in_im_arr  : in  t_fft_slv_arr_stg(g_fft.wb_factor - 1 downto 0);
		in_val     : in  std_logic := '1';
		out_re_arr : out t_fft_slv_arr_stg(g_fft.wb_factor - 1 downto 0);
		out_im_arr : out t_fft_slv_arr_stg(g_fft.wb_factor - 1 downto 0);
		out_val    : out std_logic
	);

end entity fft_sepa_wide;

architecture rtl of fft_sepa_wide is

	constant c_pipeline_output : natural := 0; -- no need for extra pipeline output, because output is already registered

	constant c_page_size   : natural := g_fft.nof_points / g_fft.wb_factor; -- Size of the memories
	constant c_nof_pages   : natural := 2; -- The number of pages in each ram. 
	constant c_dat_w       : natural := c_nof_complex * g_fft.stage_dat_w; -- Data width for the internal vectors where real and imag are combined. 
	constant c_adr_w       : natural := ceil_log2(c_page_size); -- Address width of the rams
	constant c_nof_streams : natural := 2; -- Number of inputstreams for the zip units

	type t_dat_arr is array (integer range <>) of std_logic_vector(c_dat_w - 1 downto 0);
	type t_rd_adr_arr is array (integer range <>) of std_logic_vector(c_adr_w - 1 downto 0);
	type t_zip_in_matrix is array (integer range <>) of t_slv_64_arr(1 downto 0); -- Every Zip unit has two inputs. 

	signal next_page : std_logic;       -- Active high signal to force a page-swap in the memories
	signal wr_en     : std_logic;       -- The write enable signal for the memories
	signal wr_adr    : std_logic_vector(c_adr_w - 1 downto 0); -- The write address
	signal wr_dat    : t_dat_arr(g_fft.wb_factor - 1 downto 0); -- Array of data to be written to memory

	signal rd_dat_arr : t_dat_arr(g_fft.wb_factor - 1 downto 0); -- Array of data that is read from memory
	signal rd_adr_arr : t_rd_adr_arr(1 downto 0); -- There are two different read addresses. 

	signal zip_in_matrix   : t_zip_in_matrix(g_fft.wb_factor - 1 downto 0); -- Matrix that contains the inputs for zip units
	signal zip_in_val      : std_logic_vector(g_fft.wb_factor - 1 downto 0); -- Vector that holds the data input valids for the zip units
	signal zip_out_dat_arr : t_dat_arr(g_fft.wb_factor - 1 downto 0); -- Array that holds the outputs of all zip units. 
	signal zip_out_val     : std_logic_vector(g_fft.wb_factor - 1 downto 0); -- Vector that holds the output valids of the zip units

	signal sep_out_dat_arr : t_dat_arr(g_fft.wb_factor - 1 downto 0); -- Array that holds the outputs of the separation blocks
	signal sep_out_val_vec : std_logic_vector(g_fft.wb_factor - 1 downto 0); -- Vector containing the datavalids from the separation blocks
	signal out_dat_arr     : t_dat_arr(g_fft.wb_factor - 1 downto 0); -- Array that holds the ouput values, where real and imag are concatenated 

	type state_type is (s_idle, s_read);
	type reg_type is record
		switch     : std_logic;         -- Toggle register used for separate functionalilty
		count_up   : natural range 0 to c_page_size; -- An upwards counter for read addressing
		count_down : natural range 0 to c_page_size; -- A downwards counter for read addressing
		val_odd    : std_logic;         -- Register that drives the in_valid of the odd zip units
		val_even   : std_logic;         -- Register that drives the in_valid of the even zip units
		state      : state_type;        -- The state machine. 
	end record;

	signal r, rin : reg_type;

begin

	---------------------------------------------------------------
	-- DUAL PAGED RAMS
	---------------------------------------------------------------
	-- Prepare the data for the dual paged memory. Real and imaginary part are concatenated into one vector. 
	gen_prep_write_data : for I in 0 to g_fft.wb_factor - 1 generate
		wr_dat(I) <= in_im_arr(I)(g_fft.stage_dat_w - 1 downto 0) & in_re_arr(I)(g_fft.stage_dat_w - 1 downto 0);
	end generate;

	-- Prepare the write control signals for the memories. 
	wr_en     <= in_val;
	next_page <= '1' when unsigned(wr_adr) = c_page_size - 1 and wr_en = '1' else '0';

	-- Counter will generate the write address  
	u_wr_adr_cnt : entity casper_counter_lib.common_counter
		generic map(
			g_latency => 1,
			g_init    => 0,
			g_width   => c_adr_w
		)
		port map(
			rst    => rst,
			clk    => clk,
			cnt_en => in_val,
			count  => wr_adr
		);

	-- Instantiation of the rams. 
	gen_dual_paged_rams : for I in g_fft.wb_factor - 1 downto 0 generate
		u_buff : entity casper_ram_lib.common_paged_ram_r_w
			generic map(
				g_str           => "use_adr",
				g_data_w        => c_dat_w,
				g_nof_pages     => c_nof_pages,
				g_page_sz       => c_page_size,
				g_wr_start_page => 0,
				g_rd_start_page => 1,
				g_rd_latency    => 1,
				g_ram_primitive => g_ram_primitive
			)
			port map(
				rst          => rst,
				clk          => clk,
				wr_next_page => next_page,
				wr_adr       => wr_adr,
				wr_en        => wr_en,
				wr_dat       => wr_dat(I),
				rd_next_page => next_page,
				rd_adr       => rd_adr_arr(I / (g_fft.wb_factor / 2)),
				rd_en        => '1',
				rd_dat       => rd_dat_arr(I),
				rd_val       => open
			);
	end generate;

	-- Compose the read-addresses for the memories. 
	-- The first address toggles between the value of count_up and the value of count_up + offset. 
	-- The second address toggles between the value of count_down and the value of count_down + offset.  
	-- Note that the RESIZE_UVEC function generates the modulo(N) addressing.(The MSB is thrown away).  
	rd_adr_arr(0) <= RESIZE_UVEC(TO_UVEC(r.count_up, c_adr_w + 1), c_adr_w) when r.switch = '0' else RESIZE_UVEC(TO_UVEC(r.count_up + c_page_size / 2, c_adr_w + 1), c_adr_w);
	rd_adr_arr(1) <= RESIZE_UVEC(TO_UVEC(r.count_down, c_adr_w + 1), c_adr_w) when r.switch = '0' else RESIZE_UVEC(TO_UVEC(r.count_down + c_page_size / 2, c_adr_w + 1), c_adr_w);

	---------------------------------------------------------------
	-- ZIP UNITS AND SEPARATORS
	---------------------------------------------------------------
	-- Compose the input matrix for the zip units. Each zip unit receives the
	-- data of two different memories at the same time in order to allign the data 
	-- properly (in serial) for the separation units. Every zip unit receives data 
	-- once every two clock cylces. 
	gen_compose_zip_matrix : for I in g_fft.wb_factor / 2 - 1 downto 0 generate
		zip_in_matrix(2 * I)(0)(c_dat_w - 1 downto 0)     <= rd_dat_arr(I);
		zip_in_matrix(2 * I)(1)(c_dat_w - 1 downto 0)     <= rd_dat_arr((g_fft.wb_factor - I) rem g_fft.wb_factor) when r.count_up = 0 else rd_dat_arr(g_fft.wb_factor - 1 - I);
		zip_in_matrix(2 * I + 1)(0)(c_dat_w - 1 downto 0) <= rd_dat_arr(I);
		zip_in_matrix(2 * I + 1)(1)(c_dat_w - 1 downto 0) <= rd_dat_arr(g_fft.wb_factor - 1 - I);
		zip_in_val(2 * I)                                 <= r.val_even;
		zip_in_val(2 * I + 1)                             <= r.val_odd;
	end generate;

	-- The instantiation of the zip units and the separation units. 
	-- The output of the zip units is connected to the input of the 
	-- adjacent separate unit. 
	gen_separators : for I in g_fft.wb_factor - 1 downto 0 generate
		u_zipper : entity casper_multiplexer_lib.common_zip
			generic map(
				g_nof_streams => c_nof_streams,
				g_dat_w       => c_dat_w
			)
			port map(
				rst        => rst,
				clk        => clk,
				in_val     => zip_in_val(I),
				in_dat_arr => zip_in_matrix(I),
				out_val    => zip_out_val(I),
				out_dat    => zip_out_dat_arr(I)
			);

		u_separate : entity work.fft_sepa
			port map(
				clken   => clken,
				clk     => clk,
				rst     => rst,
				in_dat  => zip_out_dat_arr(I),
				in_val  => zip_out_val(I),
				out_dat => sep_out_dat_arr(I),
				out_val => sep_out_val_vec(I)
			);
	end generate;

	---------------------------------------------------------------
	-- READ MEMORIES PROCESS
	---------------------------------------------------------------
	-- This process creates the read addresses for the dual page memories and 
	-- the fellow toggle signals. It also controls the starting and stopping 
	-- of the data stream. 
	comb : process(r, rst, next_page)
		variable v : reg_type;
	begin
		v := r;

		case r.state is
			when s_idle =>
				v.switch     := '0';
				v.val_odd    := '0';
				v.val_even   := '0';
				v.count_up   := 0;
				v.count_down := c_page_size;
				if (next_page = '1') then -- Check if next page is asserted, meaning first page is written)
					v.state := s_read;
				end if;

			when s_read =>
				if (r.switch = '0') then -- Toggle the switch register from 0 to 1
					v.switch := '1';
				end if;

				if (r.switch = '1') then -- Toggle the switch register from 1 to 0
					v.switch     := '0';
					v.count_up   := r.count_up + 1; -- Increment the upwards counter 
					v.count_down := r.count_down - 1; -- Decrease the downwards counter
				end if;

				if (next_page = '1') then -- Both counters are reset on page turn. 
					v.count_up   := 0;
					v.count_down := c_page_size;
				elsif (v.count_up = c_page_size / 2) then -- Pagereading is done, but there is not yet new data available (Note that the value of variable v is checked here) 
					v.state := s_idle;  -- then go back to idle. 
				end if;

				v.val_odd  := r.switch; -- Assignment of the odd and even markers
				v.val_even := not (r.switch);

			when others =>
				v.state := s_idle;

		end case;

		if (rst = '1') then
			v.switch     := '0';
			v.count_up   := 0;
			v.count_down := 0;
			v.val_odd    := '0';
			v.val_even   := '0';
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

	---------------------------------------------------------------
	-- OUTPUT STAGE: ALIGNMENT AND PIPELINE STAGES
	---------------------------------------------------------------
	gen_align_and_pipeline_stages : for I in g_fft.wb_factor / 2 - 1 downto 0 generate
		u_output_pipeline_align : entity common_components_lib.common_pipeline
			generic map(
				g_pipeline  => c_pipeline_output + 1, -- Pipeline + one stage for allignment
				g_in_dat_w  => c_dat_w,
				g_out_dat_w => c_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => sep_out_dat_arr(2 * I),
				out_dat => out_dat_arr(2 * I)
			);

		u_output_pipeline : entity common_components_lib.common_pipeline
			generic map(
				g_pipeline  => c_pipeline_output, -- Only pipeline stage
				g_in_dat_w  => c_dat_w,
				g_out_dat_w => c_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => sep_out_dat_arr(2 * I + 1),
				out_dat => out_dat_arr(2 * I + 1)
			);
	end generate;

	u_out_val_pipeline : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => c_pipeline_output
		)
		port map(
			clk     => clk,
			in_dat  => sep_out_val_vec(1),
			out_dat => out_val
		);

	-- Split the concatenated array into a real and imaginary array for the output
	gen_output_arrays : for I in g_fft.wb_factor - 1 downto 0 generate
		out_re_arr(I) <= RESIZE_SVEC(out_dat_arr(I)(g_fft.stage_dat_w - 1 downto 0), g_fft.stage_dat_w);
		out_im_arr(I) <= RESIZE_SVEC(out_dat_arr(I)(c_nof_complex * g_fft.stage_dat_w - 1 downto g_fft.stage_dat_w), g_fft.stage_dat_w);
	end generate;

end rtl;