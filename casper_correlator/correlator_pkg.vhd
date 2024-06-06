library ieee;
use ieee.std_logic_1164.all;

package correlator_pkg is

  CONSTANT c_cross_mult_nof_input_streams : NATURAL := 12;
  CONSTANT c_cross_mult_aggregation_per_stream : NATURAL := 3;
  CONSTANT c_cross_mult_input_bit_width : NATURAL := 5;
  CONSTANT c_cross_mult_output_bit_width : NATURAL := 11;
    
    CONSTANT c_cross_mult_input_cbit_width : NATURAL := c_cross_mult_input_bit_width * 2; --COMPLEX
    CONSTANT c_cross_mult_output_cbit_width : NATURAL := c_cross_mult_output_bit_width * 2; --COMPLEX
    CONSTANT c_cross_mult_total_streams : NATURAL := c_cross_mult_nof_input_streams * c_cross_mult_aggregation_per_stream;
    CONSTANT c_cross_mult_nof_output_streams :NATURAL := (c_cross_mult_nof_input_streams+1)*c_cross_mult_nof_input_streams / 2;
    CONSTANT c_cross_mult_nof_cmults : NATURAL := c_cross_mult_nof_output_streams * c_cross_mult_aggregation_per_stream;
    
    TYPE s_cross_mult_din is ARRAY (0 TO c_cross_mult_nof_input_streams - 1) OF std_logic_vector((c_cross_mult_aggregation_per_stream * c_cross_mult_input_cbit_width) - 1 downto 0);
    TYPE s_cross_mult_out_bus_expand is ARRAY (0 TO (c_cross_mult_total_streams) - 1) OF std_logic_vector(c_cross_mult_input_cbit_width - 1 downto 0);
    TYPE s_cross_mult_cmult_in is ARRAY(0 TO (c_cross_mult_nof_cmults - 1)) OF std_logic_vector(c_cross_mult_input_cbit_width - 1 downto 0);
    TYPE s_cross_mult_out is ARRAY (0 TO c_cross_mult_nof_output_streams - 1) OF std_logic_vector((c_cross_mult_aggregation_per_stream * c_cross_mult_output_cbit_width) - 1 downto 0);
    TYPE s_cross_mult_cmult_out is ARRAY (0 TO c_cross_mult_nof_cmults - 1) OF std_logic_vector(c_cross_mult_output_cbit_width - 1 DOWNTO 0);
    TYPE s_cmult_inpt is ARRAY(0 TO 1) OF INTEGER RANGE 0 TO c_cross_mult_total_streams - 1;
    TYPE s_cmult_map is ARRAY(0 TO c_cross_mult_nof_cmults - 1) OF s_cmult_inpt;

    FUNCTION gen_inpt_to_mult_mapping(nof_aggregation : NATURAL; nof_streams : NATURAL) return s_cmult_map;
    
end package correlator_pkg;

package body correlator_pkg is

function gen_inpt_to_mult_mapping(nof_aggregation : NATURAL; nof_streams : NATURAL)
    return s_cmult_map is
        variable mapping : s_cmult_map;
        variable mult    : INTEGER := 0;
        variable aa      : INTEGER := 0;
    begin
        mult := 0;
        FOR a IN 0 TO nof_aggregation - 1 LOOP
            aa := a * nof_streams;
            FOR s IN aa TO (aa + nof_streams - 1) LOOP
                FOR ss IN s TO (aa + nof_streams - 1) LOOP
                    mapping(mult) := (s, ss);
                    mult          := mult + 1;
                END LOOP;
            END LOOP;
        END LOOP;
        return mapping;
    end function gen_inpt_to_mult_mapping;
    
end package body correlator_pkg;
