library ieee, vunit_lib, r2sdf_fft_lib;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use ieee.math_real.all;
use ieee.fixed_float_types.all;
use ieee.fixed_pkg.all;
context vunit_lib.vunit_context;
use r2sdf_fft_lib.twiddlesPkg.all;
use std.textio.all;
library osvvm;
use osvvm.RandomPkg.all;

entity tb_vu_trwosdf_vfmodel is
    GENERIC(
        g_use_reorder       : boolean                   := true;  -- TRUE = "FFTorder", False = "BitRevorder"
        g_in_dat_w          : integer range 1 to 32     := 14;
        g_out_dat_w         : integer range 1 to 32     := 18;
        g_stage_dat_w       : integer range 1 to 32     := 18;
        g_guard_w           : integer range 0 to 32     := 2;
        g_twiddle_width     : integer range 1 to 32     := 18;
        g_fftsize_log2      : integer range 1 to 32     := 13;     -- 1 = always active, others = random control
        g_ovflw_behav       : string                    := "SATURATE"; --! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
        g_use_round         : string                    := "ROUND"; --! = "ROUND" or "TRUNCATE" will default to TRUNCATE if invalid option used
        g_use_mult_round    : string                    := "ROUND";		--! Rounding behaviour "ROUND" or "TRUNCATE"
        g_enable_pattern    : integer                   := 0; --0=Full speed, 1=Random, 2=10 Clocks between enables, 3=100 Clock between enables
        
        -- generics for rTwoSDF
        runner_cfg : string;
        output_path : string
        --tb_path : string

    );
end tb_vu_trwosdf_vfmodel;

architecture tb_vu_trwosdf_vfmodel_arch of tb_vu_trwosdf_vfmodel is
constant c_fftsize          : integer := 2**g_fftsize_log2;
signal clk                  : std_logic;
signal rst                  : std_logic;
signal in_re                : std_logic_vector(g_in_dat_w - 1 downto 0);
signal in_im                : std_logic_vector(g_in_dat_w - 1 downto 0);
signal in_val               : std_logic;
signal shiftreg             : std_logic_vector(g_fftsize_log2-1 downto 0);
signal out_re               : std_logic_vector(g_out_dat_w - 1 downto 0);
signal out_im               : std_logic_vector(g_out_dat_w - 1 downto 0);
signal ovflw                : std_logic_vector(g_fftsize_log2-1 downto 0);
signal out_val              : std_logic;
signal endsim               : std_logic := '0';
shared variable rv          : RandomPType;
signal data_cnt             : integer := 0;
signal words_expected_sig   : integer := 1000;
--type t_data_arr is array (g_fftsize_log2 downto 0) of std_logic_vector(g_stage_dat_w - 1 downto 0);
--signal stage_data_re        : t_data_arr;
--signal stage_data_im        : t_data_arr;
--signal stage_data_val       : std_logic_vector(g_fftsize_log2 downto 0);
--alias stage_data_re is <<signal rTwoSDF_inst.data_re: t_data_arr>>;
--alias stage_data_im is <<signal rTwoSDF_inst.data_im: t_data_arr>>;
BEGIN

    rTwoSDF_inst : entity r2sdf_fft_lib.rTwoSDF
        generic map(
            g_nof_chan          => 0, -- at this time this test bench only processed a single channel
            g_use_reorder       => g_use_reorder,
            g_in_dat_w          => g_in_dat_w,
            g_out_dat_w         => g_out_dat_w,
            g_stage_dat_w       => g_stage_dat_w,
            g_guard_w           => g_guard_w,
            g_nof_points        => c_fftsize, -- definition of points is not as expected
            g_variant           => "4DSP",
            g_use_dsp           => "yes",
            g_ovflw_behav       => g_ovflw_behav,
            g_use_round         => g_use_round,
            g_use_mult_round    => g_use_mult_round,
            g_twid_dat_w        => g_twiddle_width,
            g_max_addr_w        => 10, -- Keep Default size to use Block Ram
            g_twid_file_stem    => "NONE", -- We don't simulate with Twiddle Files, so this should matter
            -- Keep the default latencys
            g_stage_lat         => 1,
            g_weight_lat        => 1,
            g_mult_lat          => 4,
            g_bf_lat            => 1,
            g_bf_use_zdly       => 1,
            g_bf_in_a_zdly      => 0,
            g_bf_out_d_zdly     => 0,
            -- Automaticall choose Ram Primitives.
            g_ram_primitive     => "auto"
        )
        port map(
            clk                 => clk,
            ce                  => '1', -- Don't Simulate Clock Enables.
            rst                 => rst,
            in_re               => in_re,
            in_im               => in_im,
            in_val              => in_val,
            shiftreg            => shiftreg,
            out_re              => out_re,
            out_im              => out_im,
            ovflw               => ovflw,
            out_val             => out_val
        );

  clk_gen : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
    if endsim='1' then
      wait;
    end if;
  end process clk_gen;
  
    

	p_vunit : PROCESS
    variable twidI              : signed (g_twiddle_width-1 downto 0);
    variable twidQ              : signed (g_twiddle_width-1 downto 0);
    variable twidIR             : REAL;
    variable twidQR             : REAL;
    variable line_var           : line;
    file text_file              : text;
    file textR_file             : text;
    variable temp_number        : integer;
    variable fftsize            : integer;
    variable num_words_to_read  : integer;
    variable words_expected     : integer;
    variable dataI              : signed (g_in_dat_w-1 downto 0);
    variable dataQ              : signed (g_in_dat_w-1 downto 0);
    procedure enable_pattern is
    begin
      case g_enable_pattern is
        when 1 => -- random Enable
          if rv.RandSlv(1)(1)='0' then
            wait until rising_edge(clk);
          end if;
        when 2 => -- 1 clocks between enables
          for n in 1 to 1 loop
            wait until rising_edge(clk);
          end loop;
        when 3 => -- 10 clocks between enables
          for n in 1 to 9 loop
            wait until rising_edge(clk);
          end loop;
        when 4 => -- 100 clocks between enables
          for n in 1 to 99 loop
            wait until rising_edge(clk);
          end loop;
        when others =>
          null; -- no clocks between enables!
      end case;
    end procedure enable_pattern;      
  BEGIN
    test_runner_setup(runner, runner_cfg);
    rst     <= '1';
    endsim  <= '0';
    in_re   <= (others => '0');
    in_im   <= (others => '0');
    in_val  <= '0';
    shiftreg <= (others => '0');
    -- before we start the simulation create the Twiddle refernce binaries for all the stages of this fft
    -- We'll need these files for 100% bit accurate simulation
    for stageidx in 0 to g_fftsize_log2 loop
      fftsize := 2**stageidx;
      file_open(text_file,output_path & "/" & "twiddlepkg_twidth" & integer'image(g_twiddle_width) & "_fftsize" & integer'image(fftsize) & ".txt",WRITE_MODE);
      file_open(textR_file,output_path & "/" & "twiddlepkgR_twidth" & integer'image(g_twiddle_width) & "_fftsize" & integer'image(fftsize) & ".txt",WRITE_MODE);

      report "FFTsize = " & integer'image(fftsize) & " Twiddle Width = " & integer'image(g_twiddle_width) severity note;
      for k in 0 to fftsize-1 loop
          twidI           := gen_twiddle_factor(k,0,stageidx,1,g_twiddle_width,false,true);
          twidIR          := gen_twiddle_factor_real(k,0,stageidx,1,g_twiddle_width,false,true);
          temp_number     := to_integer(twidI);
          write(line_var,temp_number);
          writeline(text_file,line_var);
          write(line_var,twidIR);
          writeline(textR_file,line_var);
          twidQ           := gen_twiddle_factor(k,0,stageidx,1,g_twiddle_width,false,false);
          twidQR          := gen_twiddle_factor_real(k,0,stageidx,1,g_twiddle_width,false,false);
          temp_number     := to_integer(twidQ);
          write(line_var,temp_number);
          writeline(text_file,line_var);
          write(line_var,twidQR);
          writeline(textR_file,line_var);
      end loop;  
      file_close(text_file);
      file_close(textR_file);
    end loop;
    wait for 1000 nS;
    rst <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    file_open(text_file,output_path & "/" & "input_data.txt",READ_MODE);
    -- The input data, input_data.txt, has the following format
    -- header (first 8 integers):
    -- <fftsize>
    -- <g_in_dat_w>
    -- <num_words_to_read>
    -- <scale_schedule>
    -- 0 (spare)
    -- 0 (spare)
    -- 0 (spare)
    -- 2122219905 (Magic Header End field 0x7E7E8181)
    -- folllowed 2*num_words_to_read integers.
    -- Data is in I first, then Q
    
    -- Read the Header into VHDL
    -- Word 0= FFTsize
    readline(text_file,line_var);
    read(line_var,temp_number);
    check(temp_number=c_fftsize,"tb_vu_rtwosdf_vfmodel: Unexpected FFTsize in input data");
    -- Word 1= g_in_dat_w (bits of data for each I and Q)
    readline(text_file,line_var);
    read(line_var,temp_number);
    check(temp_number=g_in_dat_w,"tb_vu_rtwosdf_vfmodel: Unexpected Input Data width");
    check(temp_number<=32,"tb_vu_rtwosdf_vfmodel: Testbench only supports 32 bit or less inputs!");
    -- Word 2= num_words_to_read (number of I/Q pairs
    readline(text_file,line_var);
    read(line_var,words_expected);
    check(words_expected>0,"tb_vu_rtwosdf_vfmodel: Data Length must be greater than 0");
    check((words_expected mod c_fftsize)=0,"tb_vu_rtwosdf_vfmodel: Length of data must be a multiple of FFTsize");
    words_expected_sig <= words_expected;
    -- word 3 = Scale Schedule
    readline(text_file,line_var);
    read(line_var,temp_number);
    shiftreg  <= std_logic_vector(to_unsigned(temp_number,g_fftsize_log2));
    
    for n in 4 to 6 loop
        -- Read in the spare fields and verify = 0
        readline(text_file,line_var);
        read(line_var,temp_number);
        check(temp_number=0,"tb_vu_rtwosdf_vfmodel: Spare header fields must be 0");
    end loop;
    -- Word=7 Read in the magic word
    readline(text_file,line_var);
    read(line_var,temp_number);
    check(temp_number=2122219905,"tb_vu_rtwosdf_vfmodel: Magic word must be 0x7E7E8181");

    -- Read The Data
    num_words_to_read := words_expected;
    loop
      exit when endfile(text_file);
      readline(text_file,line_var);
      read(line_var,temp_number);
      dataI       := to_signed(temp_number,g_in_dat_w);
      readline(text_file,line_var);
      read(line_var,temp_number);
      dataQ       := to_signed(temp_number,g_in_dat_w);
      in_val      <= '1';
      in_re       <= std_logic_vector(dataI);
      in_im       <= std_logic_vector(dataQ);
      wait until rising_edge(clk);
      in_val      <= '0';
      enable_pattern;
      num_words_to_read := num_words_to_read - 1;
      exit when num_words_to_read=0;
    end loop;
    check(num_words_to_read=0,"tb_vu_rtwosdf_vfmodel: Unexpected amount of data in input data");
    
    --Synthetically generate 8 Additional frames to dump the pipeline
    for n in 1 to (8*c_fftsize) loop
      in_val      <= '1';
      in_re       <= std_logic_vector(to_signed(0,g_in_dat_w));
      in_im       <= std_logic_vector(to_signed(0,g_in_dat_w));
      wait until rising_edge(clk);
      in_val      <= '0';
      enable_pattern;
    end loop;

    -- All the data has been sent to the FFT module
    -- Wait 16 * g_fftsize_log2 clocks and then verify we received all data
    -- 16 is assumed based on generics for delay.
    for n in 1 to (16*g_fftsize_log2) loop
      wait until rising_edge(clk);
    end loop;

    check(data_cnt>=words_expected,"tb_vu_rtwosdf_vfmodel: Data output count less than input data");
    endsim  <= '1';
		test_runner_cleanup(runner);
		wait;
	END PROCESS p_vunit;

  o_data_proc : process
  variable line_var           : line;
  file output_file            : text;
  variable temp_number        : integer;
  begin
    data_cnt          <= 1; -- Reset our Data counter
    wait until rising_edge(clk) and rst='0';
    file_open(output_file,output_path & "/" & "output_data.txt",WRITE_MODE);
    loop
      exit when endsim='1';
      wait until falling_edge(clk) and out_val='1'; -- read data on falling clocks to avoid delta issues.
      temp_number     := to_integer(signed(out_re));
      write(line_var,temp_number);
      writeline(output_file,line_var);
      temp_number     := to_integer(signed(out_im));
      write(line_var,temp_number);
      writeline(output_file,line_var);
      data_cnt        <= data_cnt + 1;
      exit when data_cnt>=words_expected_sig;
    end loop;
    file_close(output_file);
    wait;
  end process o_data_proc;

--stage_data_re <= <<signal rTwoSDF_inst.data_re: t_data_arr>>;
--stage_data_im <= <<signal rTwoSDF_inst.data_im: t_data_arr>>;
--stage_data_val <= <<signal rTwoSDF_inst.data_val: std_logic_vector>>;   
--  debug_data_save : for n in 0 to g_fftsize_log2 generate
--    stage_data_proc : process
--    variable line_var           : line;
--    file output_file            : text;
--    variable temp_number        : integer;
--    variable data_cntV          : integer;
--    begin
--      data_cntV         := 0; -- Reset our Data counter
--      wait until rising_edge(clk) and rst='0';
--      file_open(output_file,output_path & "/" & "stage_data" & integer'image(n) & ".txt",WRITE_MODE);
--      loop
--        exit when endsim='1';
--        wait until falling_edge(clk) and stage_data_val(n)='1'; -- read data on falling clocks to avoid delta issues.
--        temp_number     := to_integer(signed(stage_data_re(n)));
--        write(line_var,temp_number);
--        writeline(output_file,line_var);
--        temp_number     := to_integer(signed(stage_data_im(n)));
--        write(line_var,temp_number);
--        writeline(output_file,line_var);
--        data_cntV        := data_cntV + 1;
--        exit when data_cntV>=words_expected_sig;
--      end loop;
--      file_close(output_file);
--      wait;
--    end process stage_data_proc;
--  end generate debug_data_save;

  error_proc : process
  begin
    wait until falling_edge(clk) and unsigned(ovflw)>0;
    check(unsigned(ovflw)=0,"tb_vu_rtwosdf_vfmodel: Overflow detected: 0x" & to_hstring(ovflw));
  end process error_proc;

END tb_vu_trwosdf_vfmodel_arch;