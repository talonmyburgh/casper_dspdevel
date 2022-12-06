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

-- Purpose: Perform the separate function to support two real inputs  
--
-- Description: It composes an output stream where the bins for input A and B are
--              interleaved in the stream: A, B, A, B etc (for both real and imaginary part)
--
--              It is assumed that the incoming data is as follows for a 1024 point FFT: 
-- 
--              X(0), X(1024), X(1), X(1023), X(2), X(1022), etc...              
--                       |
--                       |
--                    This value is X(0)!!! 
--                                          
--              The function that is performed is based on the following equation: 
--
--              A.real(m) = (X.real(N-m) + X.real(m))/2
--              A.imag(m) = (X.imag(m)   - X.imag(N-m))/2
--              B.real(m) = (X.imag(m)   + X.imag(N-m))/2
--              B.imag(m) = (X.real(N-m) - X.real(m))/2
--
-- Remarks:
-- . The add and sub output of the separate have 1 bit growth that needs to be
--   rounded. Simply skipping 1 LSbit is not suitable, because it yields
--   asymmetry around 0 and thus a DC offset. For example for N = 3-bit data:
--              x =  -4 -3 -2 -1  0  1  2  3
--     round(x/2) =  -2 -2 -1 -1  0  1  1  2  = common_round for signed
--     floor(x/2) =  -2 -2 -1 -1  0  0  1  1  = truncation
--   The most negative value can be ignored:
--              x : mean(-3 -2 -1  0  1  2  3) = 0
--   . round(x/2) : mean(-2 -1 -1  0  1  1  2) = 0
--   . floor(x/2) : mean(-2 -1 -1  0  0  1  1) = -2/8 = -0.25 = -2^(N-1)/2 / 2^N
--   So the DC offset due to truncation is -0.25 LSbit, independent of N.

library IEEE, common_pkg_lib, casper_adder_lib, casper_requantize_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;

entity fft_sepa is
    generic(
        g_alt_output : boolean := FALSE
    );
    port(
        clk     : in  std_logic;
        clken   : in  std_logic;
        rst     : in  std_logic;
        in_dat  : in  std_logic_vector;
        in_val  : in  std_logic;
        out_dat : out std_logic_vector;
        out_val : out std_logic
    );
end entity fft_sepa;

architecture rtl of fft_sepa is

    constant c_sepa_round : boolean := true; -- must be true, because separate should round the 1 bit growth

    constant c_data_w   : natural := in_dat'length / c_nof_complex;
    constant c_c_data_w : natural := c_nof_complex * c_data_w;
    constant c_pipeline : natural := 3;

    type reg_type is record
        switch      : std_logic;        -- Register used to toggle between A & B definitionn
        val_dly     : std_logic_vector(c_pipeline - 1 downto 0); -- Register that delays the incoming valid signal
        xn_m_reg    : std_logic_vector(c_c_data_w - 1 downto 0); -- Register to hold the X(N-m) value for one cycle
        xm_reg      : std_logic_vector(c_c_data_w - 1 downto 0); -- Register to hold the X(m) value for one cycle
        add_1_reg_a : std_logic_vector(c_data_w - 1 downto 0); -- Input register A for the adder
        add_1_reg_b : std_logic_vector(c_data_w - 1 downto 0); -- Input register B for the adder
        add_2_reg_a : std_logic_vector(c_data_w - 1 downto 0); -- Input register A for the subtractor
        add_2_reg_b : std_logic_vector(c_data_w - 1 downto 0); -- Input register B for the subtractor
        adder_1_dir : std_logic;        -- Direction for the adder block
        adder_2_dir : std_logic;        -- Direction for the adder block
        out_dat     : std_logic_vector(c_c_data_w - 1 downto 0); -- Registered output value
        out_val     : std_logic;        -- Registered data valid signal  
    end record;

    signal r, rin     : reg_type;
    signal sub_result : std_logic_vector(c_data_w downto 0); -- Result of the subtractor   
    signal add_result : std_logic_vector(c_data_w downto 0); -- Result of the adder   

    signal sub_result_q : std_logic_vector(c_data_w - 1 downto 0); -- Requantized result of the subtractor   
    signal add_result_q : std_logic_vector(c_data_w - 1 downto 0); -- Requantized result of the adder

begin

    ---------------------------------------------------------------
    -- ADDER AND SUBTRACTOR
    ---------------------------------------------------------------
    adder_1 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "BOTH",
            g_representation  => "SIGNED",
            g_pipeline_input  => 0,
            g_pipeline_output => 1,
            g_in_dat_w        => c_data_w,
            g_out_dat_w       => c_data_w + 1
        )
        port map(
            clk     => clk,
            clken   => clken,
            sel_add => r.adder_1_dir,
            in_a    => r.add_1_reg_a,
            in_b    => r.add_1_reg_b,
            result  => add_result
        );

    adder_2 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "BOTH",
            g_representation  => "SIGNED",
            g_pipeline_input  => 0,
            g_pipeline_output => 1,
            g_in_dat_w        => c_data_w,
            g_out_dat_w       => c_data_w + 1
        )
        port map(
            clk     => clk,
            clken   => clken,
            sel_add => r.adder_2_dir,
            in_a    => r.add_2_reg_a,
            in_b    => r.add_2_reg_b,
            result  => sub_result
        );

    gen_sepa_truncate : IF c_sepa_round = FALSE GENERATE
        -- truncate the one LSbit
        add_result_q <= add_result(c_data_w downto 1);
        sub_result_q <= sub_result(c_data_w downto 1);
    end generate;

    gen_sepa_round : IF c_sepa_round GENERATE
        -- round the one LSbit
        round_add : ENTITY casper_requantize_lib.common_round
            GENERIC MAP(
                g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
                g_round           => TRUE, -- when TRUE round the input, else truncate the input
                g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
                g_pipeline_input  => 0, -- >= 0
                g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
                g_in_dat_w        => c_data_w + 1,
                g_out_dat_w       => c_data_w
            )
            PORT MAP(
                clk     => clk,
                clken   => clken,
                in_dat  => add_result,
                out_dat => add_result_q
            );

        round_sub : ENTITY casper_requantize_lib.common_round
            GENERIC MAP(
                g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
                g_round           => TRUE, -- when TRUE round the input, else truncate the input
                g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
                g_pipeline_input  => 0, -- >= 0
                g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
                g_in_dat_w        => c_data_w + 1,
                g_out_dat_w       => c_data_w
            )
            PORT MAP(
                clk     => clk,
                clken   => clken,
                in_dat  => sub_result,
                out_dat => sub_result_q
            );
    end generate;

    ---------------------------------------------------------------
    -- CONTROL PROCESS
    ---------------------------------------------------------------
    comb : process(r, rst, in_val, in_dat, add_result_q, sub_result_q)
        variable v : reg_type;
    begin
        v := r;

        -- Shift register for the valid signal
        v.val_dly(c_pipeline - 1 downto 1) := v.val_dly(c_pipeline - 2 downto 0);
        v.val_dly(0)                       := in_val;

        -- Composition of the output registers:
        v.out_dat := sub_result_q & add_result_q;
        v.out_val := r.val_dly(c_pipeline - 1);

        if g_alt_output = FALSE then
            -- Compose the inputs for the adder and subtractor
            -- for both A and B 
            if in_val = '1' or r.val_dly(0) = '1' then
                --set adder directions - fixed in this case:
                v.adder_1_dir := '1';
                v.adder_2_dir := '0';
                if r.switch = '0' then
                    -- output B_real = X.imag(m) + X.imag(N-m), B_imag = X.real(N-m) - X.real(m)
                    v.xm_reg      := in_dat;
                    v.add_1_reg_a := r.xm_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(m)
                    v.add_1_reg_b := r.xn_m_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(N-m)
                    v.add_2_reg_a := r.xn_m_reg(c_data_w - 1 downto 0); -- X.real(N-m)
                    v.add_2_reg_b := r.xm_reg(c_data_w - 1 downto 0); -- X.real(m)
                else
                    -- output A_real = X.real(m) + X.real(N-m), A_imag = X.imag(m)- X.imag(N-m)
                    v.xn_m_reg    := in_dat;
                    v.add_1_reg_a := r.xm_reg(c_data_w - 1 downto 0); -- X.real(m) 
                    v.add_1_reg_b := in_dat(c_data_w - 1 downto 0); -- X.real(N-m)
                    v.add_2_reg_a := r.xm_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(m)
                    v.add_2_reg_b := in_dat(c_c_data_w - 1 downto c_data_w); -- X.imag(N-m)
                end if;
            end if;
        else
            --Compose the inputs for the adder and subtractor
            --When switch = '0' output A real and B real.
            --When switch = '1' output A imag and B imag.
            if in_val = '1' or r.val_dly(0) = '1' then
                if r.switch = '0' then
                    -- output B_real = X.imag(m) + X.imag(N-m), A_real = X.real(m) + X.real(N-m)
                    v.xm_reg      := in_dat;
                    v.add_1_reg_a := r.xm_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(m)
                    v.add_1_reg_b := r.xn_m_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(N-m)
                    v.add_2_reg_a := r.xm_reg(c_data_w - 1 downto 0); -- X.real(m)
                    v.add_2_reg_b := r.xn_m_reg(c_data_w - 1 downto 0); -- X.real(N-m)

                    --set adder directions - both adding:
                    v.adder_1_dir := '1';
                    v.adder_2_dir := '1';
                else
                    -- output B_imag = X.real(N-m) - X.real(m), A_imag = X.imag(m) - X.imag(N-m)
                    v.xn_m_reg    := in_dat;
                    v.add_1_reg_a := in_dat(c_data_w - 1 downto 0); -- X.real(N-m)
                    v.add_1_reg_b := r.xm_reg(c_data_w - 1 downto 0); -- X.real(m)
                    v.add_2_reg_a := r.xm_reg(c_c_data_w - 1 downto c_data_w); -- X.imag(m)
                    v.add_2_reg_b := in_dat(c_c_data_w - 1 downto c_data_w); -- X.imag(N-m)

                    --set adder directions - both subtracting:
                    v.adder_1_dir := '0';
                    v.adder_2_dir := '0';
                end if;
            end if;

        end if;

        if in_val = '1' then
            v.switch := not r.switch;
        end if;

        if (rst = '1') then
            v.switch      := '0';
            v.val_dly     := (others => '0');
            v.xn_m_reg    := (others => '0');
            v.xm_reg      := (others => '0');
            v.add_1_reg_a := (others => '0');
            v.add_1_reg_b := (others => '0');
            v.adder_1_dir := '0';
            v.adder_2_dir := '0';
            v.add_2_reg_a := (others => '0');
            v.add_2_reg_b := (others => '0');
            v.out_dat     := (others => '0');
            v.out_val     := '0';
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
    -- OUTPUT STAGE
    ---------------------------------------------------------------
    out_dat <= r.out_dat;
    out_val <= r.out_val;

end rtl;

