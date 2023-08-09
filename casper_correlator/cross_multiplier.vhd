library ieee, common_pkg_lib, casper_multiplier_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.correlator_pkg.all;

entity cross_multiplier is
    generic(
        g_use_gauss        : BOOLEAN := FALSE;
        g_use_dsp          : BOOLEAN := TRUE;
        g_pipeline_input   : NATURAL := 1; --! 0 or 1
        g_pipeline_product : NATURAL := 1; --! 0 or 1
        g_pipeline_adder   : NATURAL := 1; --! 0 or 1
        g_pipeline_round   : NATURAL := 1; --! 0 or 1
        g_pipeline_output  : NATURAL := 0; --! >= 0
        ovflw_behav        : BOOLEAN := FALSE;
        quant_behav        : NATURAL := 0
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  s_cross_mult_din;
        dout : out s_cross_mult_out
    );
end entity cross_multiplier;

architecture RTL of cross_multiplier is

    signal s_out_bus_expand : s_cross_mult_out_bus_expand := (others => (others => '0'));
    signal s_out_cmults     : s_cross_mult_cmult_out      := (others => (others => '0'));
    signal s_a_cmult_in, s_b_cmult_in  : s_cross_mult_cmult_in := (others => (others => '0'));
    signal s_out : s_cross_mult_out := (others=>(others=>'0'));
    
    signal s_cmult_input_map : s_cmult_map := gen_inpt_to_mult_mapping(c_cross_mult_aggregation_per_stream, c_cross_mult_nof_input_streams);

begin
    
    gen_expand : FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 GENERATE --SPLIT the aggregation
        gen_bus_expand : FOR i IN 0 TO c_cross_mult_nof_input_streams - 1 GENERATE -- FOR each stream
            s_out_bus_expand(c_cross_mult_nof_input_streams*j + i) <= din(i)((j + 1) * c_cross_mult_input_cbit_width - 1 DOWNTO j * c_cross_mult_input_cbit_width);
        END GENERATE;
    END GENERATE;

    gen_cmult : FOR m IN 0 TO c_cross_mult_nof_cmults - 1 GENERATE
        s_a_cmult_in(m) <= s_out_bus_expand(s_cmult_input_map(m)(0));
        s_b_cmult_in(m) <= s_out_bus_expand(s_cmult_input_map(m)(1));
        cmult_inst : entity casper_multiplier_lib.cmult
            generic map(
                g_use_ip           => FALSE,
                g_a_bw             => c_cross_mult_input_bit_width,
                g_b_bw             => c_cross_mult_input_bit_width,
                g_ab_bw            => c_cross_mult_output_bit_width,
                g_conjugate_b      => TRUE,
                g_use_gauss        => g_use_gauss,
                g_use_dsp          => g_use_dsp,
                g_round_method     => quant_behav,
                g_ovflw_method     => ovflw_behav,
                g_pipeline_input   => g_pipeline_input,
                g_pipeline_product => g_pipeline_product,
                g_pipeline_adder   => g_pipeline_adder,
                g_pipeline_round   => g_pipeline_round,
                g_pipeline_output  => g_pipeline_output
            )
            port map(
                clk     => clk,
                ce      => ce,
                rst     => '0',
                in_a    => s_a_cmult_in(m),
                in_b    => s_b_cmult_in(m),
                in_val  => '1',
                out_ab  => s_out_cmults(m),
                out_val => open
            );

    END GENERATE;

    gen_pack : FOR n IN 0 TO c_cross_mult_nof_output_streams - 1 GENERATE
        gen_per_aggregation : FOR p IN 0 TO c_cross_mult_aggregation_per_stream - 1 GENERATE
                s_out(n)((p+1)*c_cross_mult_output_cbit_width - 1 DOWNTO p*c_cross_mult_output_cbit_width) <= s_out_cmults(2*n + p)(c_cross_mult_output_cbit_width -1 DOWNTO 0);
        END GENERATE;
    END GENERATE;
    dout <= s_out;
end architecture RTL;
