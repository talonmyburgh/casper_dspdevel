library ieee, vunit_lib, r2sdf_fft_lib;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use ieee.math_real.all;
library common_pkg_lib;
use ieee.fixed_float_types.all;
--use ieee.fixed_pkg.all;
use common_pkg_lib.fixed_pkg.all;
context vunit_lib.vunit_context;
use r2sdf_fft_lib.twiddlesPkg.all;
use std.textio.all;

entity tb_vu_twiddlepkg is
    GENERIC(
        g_twiddle_width     : integer  := 18;
        g_fftsize_log2      : integer  := 13;     -- 1 = always active, others = random control
        -- generics for rTwoSDF
        runner_cfg : string;
        output_path : string
        --tb_path : string

    );
end tb_vu_twiddlepkg;

architecture tbarch_tb_vu_twiddlepkg of tb_vu_twiddlepkg is
constant c_fftsize : integer := 2**g_fftsize_log2;

BEGIN


	p_vunit : PROCESS
	variable twidI : signed (g_twiddle_width-1 downto 0);
    variable twidQ : signed (g_twiddle_width-1 downto 0);
    variable line_var : line;
    file text_file : text;
    variable temp_number : integer;

    BEGIN
		test_runner_setup(runner, runner_cfg);
        file_open(text_file,output_path & "/" & "twiddlepkg_twidth" & integer'image(g_twiddle_width) & "_fftsize" & integer'image(c_fftsize) & ".txt",WRITE_MODE);
        report "FFTsize = " & integer'image(c_fftsize) & " Twiddle Width = " & integer'image(g_twiddle_width) severity note;
        for k in 0 to c_fftsize-1 loop
            twidI           := gen_twiddle_factor(k,0,g_fftsize_log2,1,g_twiddle_width,false,true);
            temp_number     := to_integer(twidI);
            write(line_var,temp_number);
            writeline(text_file,line_var);
            twidQ           := gen_twiddle_factor(k,0,g_fftsize_log2,1,g_twiddle_width,false,false);
            temp_number     := to_integer(twidQ);
            write(line_var,temp_number);
            writeline(text_file,line_var);
        end loop;
        file_close(text_file);
		test_runner_cleanup(runner);
		wait;
	END PROCESS;


END tbarch_tb_vu_twiddlepkg;