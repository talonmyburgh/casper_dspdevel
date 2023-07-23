library ieee, common_pkg_lib, casper_misc_lib, casper_multiplier_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.correlator_pkg.all;

entity cross_multiplier is
    generic(
        g_use_gauss : BOOLEAN  := FALSE;
        g_use_dsp          : BOOLEAN := TRUE;
        g_pipeline_input   : NATURAL := 1; --! 0 or 1
        g_pipeline_product : NATURAL := 1; --! 0 or 1
        g_pipeline_adder   : NATURAL := 1; --! 0 or 1
        g_pipeline_round   : NATURAL := 1; --! 0 or 1
        g_pipeline_output  : NATURAL := 0; --! >= 0
        ovflw_behav : BOOLEAN  := FALSE;
        quant_behav : NATURAL := 0
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  s_cross_mult_din;
        dout : out s_cross_mult_out
    );
end entity cross_multiplier;

architecture RTL of cross_multiplier is
--    constant c_use_variant : STRING := sel_a_b(g_use_gauss, "3DSP", "4DSP");
--    constant c_use_dsp     : STRING          := sel_a_b(g_use_dsp, "YES", "NO");
    
    signal s_out_bus_expand                  : s_cross_mult_out_bus_expand := (others => (others => '0'));
--    signal s_out_c_to_ri, s_in_cmult_ordered : s_cross_mult_out_c_to_ri    := (others => (others => '0'));

    function gen_inpt_to_mult_mapping(nof_aggregation : NATURAL; nof_streams : NATURAL)
        return s_cmult_map is
        variable mapping : s_cmult_map;
        variable mult : INTEGER := 0;
        variable aa : INTEGER := 0;
    begin
        FOR a IN 0 TO nof_aggregation - 1 LOOP
            aa := a + nof_streams;
            FOR s IN aa TO (aa + nof_streams - 1) LOOP
                FOR ss IN s TO (aa + nof_streams - 1) LOOP
                    mapping(mult) := (s , ss);
                    mult := mult + 1;
                END LOOP;
            END LOOP;
        END LOOP;
        return mapping;
    end function gen_inpt_to_mult_mapping;
    
    signal s_cmult_input_map : s_cmult_map := gen_inpt_to_mult_mapping(c_cross_mult_aggregation_per_stream, c_cross_mult_nof_input_streams);

begin
    gen_bus_expand : FOR i IN 0 TO c_cross_mult_nof_input_streams - 1 GENERATE -- FOR each stream
        gen_expand : FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 GENERATE --SPLIT the aggregation
            s_out_bus_expand(i) <= din(i)((j + 1) * c_cross_mult_input_cbit_width - 1 DOWNTO j * c_cross_mult_input_cbit_width);
        END GENERATE;
    END GENERATE;

--    gen_c_to_ri : FOR k IN 0 TO c_cross_mult_total_streams - 1 GENERATE
--        u_to_ri_inst : entity casper_misc_lib.c_to_ri
--            generic map(
--                g_async     => TRUE,
--                g_bit_width => c_cross_mult_input_bit_width
--            )
--            port map(
--                clk    => clk,
--                ce     => ce,
--                c_in   => s_out_bus_expand(k),
--                re_out => s_out_c_to_ri(2 * k),
--                im_out => s_out_c_to_ri(2 * k + 1)
--            );
--    END GENERATE;

    gen_cmult : FOR m IN 0 TO c_cross_mult_nof_cmults - 1 GENERATE
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
            in_a    => s_out_bus_expand(s_cmult_input_map(m)(0))(c_cross_mult_input_cbit_width - 1 DOWNTO 0),
            in_b    => s_out_bus_expand(s_cmult_input_map(m)(1))(c_cross_mult_input_cbit_width - 1 DOWNTO 0),
            in_val  => '1',
            out_ab  => out_ab,
            out_val => open
    );
    
    
--    tech_complex_mult_inst : entity casper_multiplier_lib.tech_complex_mult
--            generic map(
--                g_use_ip           => FALSE,
--                g_use_variant      => c_use_variant,
--                g_use_dsp          => c_use_dsp,
--                g_in_a_w           => c_cross_mult_input_bit_width,
--                g_in_b_w           => c_cross_mult_input_bit_width,
--                g_out_p_w          => 2*c_cross_mult_input_bit_width + 1,
--                g_conjugate_b      => TRUE,
--                g_pipeline_input   => 1,
--                g_pipeline_product => 2,
--                g_pipeline_adder   => 1,
--                g_pipeline_output  => 0
--            )
--            port map(
--                rst       => '0',
--                clk       => clk,
--                clken     => ce,
--                in_ar     => in_ar,
--                in_ai     => in_ai,
--                in_br     => in_br,
--                in_bi     => in_bi,
--                result_re => result_re,
--                result_im => result_im
--            );
    
    
    END GENERATE;

end architecture RTL;
