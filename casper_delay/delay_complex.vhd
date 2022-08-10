-- A VHDL implementation of the CASPER delay_complex block.
-- @company: Mydon Solutions.
-- @author: Ross Donnachie.

LIBRARY IEEE, common_pkg_lib, casper_misc_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY delay_complex is
  generic (
    g_delay : NATURAL := 3;
    g_ram_primitive : STRING  := "block";
    g_ram_latency: NATURAL := 2
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    din   : in std_logic_vector;
    dout  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of delay_complex is

  SIGNAL s_re_in   : std_logic_vector((din'HIGH+1)/2 -1 downto 0);
  SIGNAL s_im_in   : std_logic_vector(s_re_in'RANGE);

  SIGNAL s_re_out   : std_logic_vector(s_re_in'RANGE);
  SIGNAL s_im_out   : std_logic_vector(s_re_in'RANGE);

begin

  u_c_split : entity casper_misc_lib.c_to_ri
    generic map(
        g_async => TRUE,
        g_bit_width => din'LENGTH/2
    )
    port map(
        clk => clk,
        ce => ce,
        c_in => din,
        re_out => s_re_in,
        im_out => s_im_in
    );

  u_delay_bram_re : entity work.delay_bram
    generic map (
      g_delay => g_delay,
      g_ram_primitive => g_ram_primitive,
      g_ram_latency => g_ram_latency
    )
    port map (
      clk => clk,
      ce => ce,
      din => s_re_in,
      dout => s_re_out
    );

  u_delay_bram_im : entity work.delay_bram
    generic map (
      g_delay => g_delay,
      g_ram_primitive => g_ram_primitive,
      g_ram_latency => g_ram_latency
    )
    port map (
      clk => clk,
      ce => ce,
      din => s_im_in,
      dout => s_im_out
    );

  u_c_combine : entity casper_misc_lib.ri_to_c
    generic map(
        g_async => TRUE
    )
    port map(
        clk => clk,
        ce => ce,
        re_in => s_re_out,
        im_in => s_im_out,
        c_out => dout
    );

end architecture;

LIBRARY IEEE, common_pkg_lib, casper_misc_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY delay_complex_async is
  generic (
    g_delay : NATURAL := 3;
    g_ram_primitive : STRING  := "block";
    g_ram_latency: NATURAL := 2
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    en    : in std_logic;
    din   : in std_logic_vector;
    dout  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of delay_complex_async is

  SIGNAL s_re_in   : std_logic_vector((din'HIGH+1)/2 -1 downto 0);
  SIGNAL s_im_in   : std_logic_vector(s_re_in'RANGE);

  SIGNAL s_re_out   : std_logic_vector(s_re_in'RANGE);
  SIGNAL s_im_out   : std_logic_vector(s_re_in'RANGE);

begin

  u_c_split : entity casper_misc_lib.c_to_ri
    generic map(
        g_async => TRUE,
        g_bit_width => din'LENGTH/2
    )
    port map(
        clk => clk,
        ce => ce,
        c_in => din,
        re_out => s_re_in,
        im_out => s_im_in
    );

  u_delay_bram_re : entity work.delay_bram_async
    generic map (
      g_delay => g_delay,
      g_ram_primitive => g_ram_primitive,
      g_ram_latency => g_ram_latency
    )
    port map (
      clk => clk,
      ce => ce,
      en => en,
      din => s_re_in,
      dout => s_re_out
    );

  u_delay_bram_im : entity work.delay_bram_async
    generic map (
      g_delay => g_delay,
      g_ram_primitive => g_ram_primitive,
      g_ram_latency => g_ram_latency
    )
    port map (
      clk => clk,
      ce => ce,
      en => en,
      din => s_im_in,
      dout => s_im_out
    );

  u_c_combine : entity casper_misc_lib.ri_to_c
    generic map(
        g_async => TRUE
    )
    port map(
        clk => clk,
        ce => ce,
        re_in => s_re_out,
        im_in => s_im_out,
        c_out => dout
    );

end architecture;