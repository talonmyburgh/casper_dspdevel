library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library cern_general_cores;
library common_pkg_lib;
USE common_pkg_lib.common_pkg.ALL;

entity siriushdl_fifo_sync_1_0 is
  generic (
    g_data_width              : natural;
    g_pipe_width              : natural := 1;
    g_size                    : natural;
    g_show_ahead              : boolean := false; -- note while show ahead does show the next value eventually the pipeline delay is substantial for the rden to effect the output value due to pipelineing, so this block can't be used in AXI skid buffer implementations directly.

    g_almost_empty_threshold  : integer := 0;  -- threshold for almost empty flag
    g_almost_full_threshold   : integer := 0   -- threshold for almost full flag

    );
  
  port(
    i_clk                     : in  std_logic;
    i_reset                   : in  std_logic;
    
    i_wr_data                 : in  std_logic_vector(g_data_width-1 downto 0);
    i_wren                    : in  std_logic;
    
    i_rden                    : in  std_logic;
    -- rd pipe allows data to be passed with equal pipe delay as the rden to rddata output
    -- This is sometimes useful for start and last flags for example.
    i_rd_pipe                 : in  std_logic_vector(g_pipe_width-1 downto 0) := (others => '0');
    o_rd_data                 : out std_logic_vector(g_data_width-1 downto 0);
    o_rddata_valid            : out std_logic;
    o_rd_pipe                 : out std_logic_vector(g_pipe_width-1 downto 0);
    
    -- Status Flags
    o_empty                   : out std_logic;
    o_full                    : out std_logic;
    o_almost_empty            : out std_logic;
    o_almost_full             : out std_logic;
    o_count                   : out unsigned(ceil_log2(g_size) downto 0);
    
    -- Error Flags
    o_fifo_overflow           : out std_logic;
    o_fifo_underflow          : out std_logic   
    
  );
end entity siriushdl_fifo_sync_1_0;

architecture siriushdl_fifo_sync_1_0_arch of siriushdl_fifo_sync_1_0 is
signal fifo_empty     : std_logic;
signal fifo_full      : std_logic;
signal rd_pipe        : std_logic_vector(g_pipe_width downto 0);
signal rd_pipe_d1     : std_logic_vector(g_pipe_width downto 0);
signal count          : std_logic_vector(ceil_log2(g_size)-1 downto 0);
signal almost_empty   : std_logic;
signal almost_full    : std_logic;
signal wr_data        : std_logic_vector(g_data_width-1 downto 0);
signal wren           : std_logic;
signal rden           : std_logic;
signal rden_to_fifo   : std_logic;
signal rd_data        : std_logic_vector(g_data_width-1 downto 0);
--signal rd_pipe_d2     : std_logic_vector(g_pipe_width downto 0);
begin

gc_sync_fifo : entity cern_general_cores.inferred_sync_fifo
  generic map(
    g_data_width             => g_data_width,
    g_size                   => g_size,
    g_show_ahead             => g_show_ahead,
    g_show_ahead_legacy_mode => false,
    g_with_empty             => true,
    g_with_full              => true,
    g_with_almost_empty      => true,
    g_with_almost_full       => true,
    g_with_count             => true,
    g_almost_empty_threshold => g_almost_empty_threshold,
    g_almost_full_threshold  => g_almost_full_threshold,
    g_register_flag_outputs  => false,
    g_memory_implementation_hint => "auto"
  ) 
  port map(
    rst_n_i                  => not(i_reset),
    clk_i                    => i_clk,
    d_i                      => wr_data,
    we_i                     => wren,
    q_o                      => rd_data,
    rd_i                     => rden_to_fifo,
    empty_o                  => fifo_empty,
    full_o                   => fifo_full,
    almost_empty_o           => almost_empty,
    almost_full_o            => almost_full,
    count_o                  => count
  ) ;
  
rden_to_fifo <= rden and not fifo_empty;
    
    
-- We want flags the underlying fifo doesn't support,
-- So we'll run the fifo un-registered mode, and use the signals
-- to Calculate what we really want.
-- We'll also add registers to wr and rd data to give
-- tools options.  Note this will mean registers are always on
-- Users of this fifo will need to understand the pipe delay
-- on Flags. See documentation for Timing Diagrams.
sfifo_helper_proc : process (i_clk)
begin
  if rising_edge(i_clk) then
    
    wr_data         <= i_wr_data;
    wren            <= i_wren;
    rden            <= i_rden; 
    o_rd_data       <= rd_data;
    -- only create the ack if the fifo is not empty.
    rd_pipe         <= i_rd_pipe & '0'; -- the enable flag will be added later
    rd_pipe_d1      <= rd_pipe(rd_pipe'length-1 downto 1) & (rden_to_fifo);
    --rd_pipe_d2      <= rd_pipe_d1;
    o_rddata_valid  <= rd_pipe_d1(0);
    o_rd_pipe       <= rd_pipe_d1(rd_pipe_d1'length-1 downto 1);
    
    o_fifo_overflow <= fifo_full and wren;
    o_fifo_underflow<= fifo_empty and rden; -- underflows can still cause errors, but won't pass to the actual fifo
    o_empty         <= fifo_empty;
    o_full          <= fifo_full;
    o_almost_empty  <= almost_empty;
    o_almost_full   <= almost_full;
    if fifo_full='0' then
      o_count       <= resize(unsigned(count),o_count'length);
    else
      o_count       <= to_unsigned(g_size,o_count'length);
    end if;
    if i_reset='1' then
      wren          <= '0';
      rden          <= '0';
      o_rddata_valid<= '0';
    end if;
  end if;
end process sfifo_helper_proc;

end architecture siriushdl_fifo_sync_1_0_arch;
