LIBRARY ieee, common_pkg_lib;
USE ieee.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;
 LIBRARY UNIMACRO;
 USE UNIMACRO.VComponents.all;
 LIBRARY UNISIM;
 USE UNISIM.VComponents.all;

ENTITY ip_xilinx_ram_cr_cw IS
  GENERIC (
    g_adr_w      : NATURAL := 9;
    g_dat_w      : NATURAL := 38;
    g_bram_size  : STRING := "36Kb"; -- choose 9kb, 18kb, 36kb
    g_rd_latency : NATURAL := 2;  -- choose 1 or 2
    g_init_file  : STRING  := "UNUSED";
    g_device        :STRING := "7SERIES"
  );
  PORT
  (
    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
    rdclock   : IN  STD_LOGIC := '1';
    rdclocken : IN  STD_LOGIC  := '1';
    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
    wrclock   : IN  STD_LOGIC  := '1';
    wrclocken : IN  STD_LOGIC  := '1';
    wren      : IN  STD_LOGIC  := '1';
    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
  );
END ip_xilinx_ram_cr_cw;

architecture syn of ip_xilinx_ram_cr_cw is

	function we_length_calc(dat_w : integer)
        return integer is
    begin
        if (37 <= dat_w) and (dat_w <= 72) then
            return 8;
        elsif (19 <= dat_w) and (dat_w <= 36) then
            return 4;
        elsif (10 <= dat_w) and (dat_w <= 18) then
        	return 2;
        elsif (1 <= dat_w) and (dat_w <= 9) then
            return 1;
        else
        	return 0;
        end if;
     end function;
	
	SIGNAL c_outdata_reg_b : STD_LOGIC := sel_a_b(g_rd_latency-1=0, '0', '1');
	
	CONSTANT initfile : STRING := sel_a_b(g_init_file="UNUSED", "NONE", g_init_file);
  
  	SIGNAL sub_wire0  : STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
  	
  	CONSTANT we_length : INTEGER := we_length_calc(g_dat_w);
  	
	SIGNAL we_a : STD_LOGIC_VECTOR(we_length -1 DOWNTO 0);
  	
  	component BRAM_SDP_MACRO
  		generic(
  			BRAM_SIZE           : string;
  			DEVICE              : string;
  			DO_REG              : integer;
  			INIT_FILE           : string;
  			READ_WIDTH          : integer;
  			WRITE_MODE          : string;
  			WRITE_WIDTH         : integer
  		);
  		port(
  			DO     : out std_logic_vector(READ_WIDTH - 1 downto 0);
  			DI     : in  std_logic_vector(WRITE_WIDTH - 1 downto 0);
  			RDADDR : in  std_logic_vector;
  			RDCLK  : in  std_ulogic;
  			RDEN   : in  std_ulogic;
  			REGCE  : in  std_ulogic;
  			RST    : in  std_ulogic;
  			WE     : in  std_logic_vector;
  			WRADDR : in  std_logic_vector;
  			WRCLK  : in  std_ulogic;
  			WREN   : in  std_ulogic
  		);
  	end component BRAM_SDP_MACRO;
	
begin

    we_a <= (others => wren);
	
	q    <= sub_wire0(g_dat_w-1 DOWNTO 0);
	
	sdp_ram_comp : BRAM_SDP_MACRO
		generic map(
			BRAM_SIZE => g_bram_size,
			DEVICE => g_device,
			DO_REG => g_rd_latency-1,
			INIT_FILE => initfile,
			READ_WIDTH => g_dat_w,
			WRITE_MODE => "WRITE_FIRST",
			WRITE_WIDTH => g_dat_w
		)
		port map(
			DO     => sub_wire0,
			DI     => data,
			RDADDR => rdaddress,
			RDCLK  => rdclock,
			RDEN   => rdclocken,
			REGCE  => c_outdata_reg_b,
			RST    => '0',
			WE     => we_a,
			WRADDR => wraddress,
			WRCLK  => wrclock,
			WREN   => wren
		);
	
end architecture syn;
