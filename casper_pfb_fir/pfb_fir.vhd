-- author: August 2023 - Andrew Martens but compiled from Astron sources with improvements mostly to reduce BRAM use 
-- add sync functionality and improve timing

library IEEE, common_pkg_lib, casper_ram_lib, casper_multiplier_lib, casper_adder_lib, casper_requantize_lib, technology_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;
use casper_ram_lib.common_ram_pkg.ALL;
use technology_lib.technology_select_pkg.ALL;
use work.pfb_fir_pkg.ALL;

entity pfb_fir is
    generic(
        g_big_endian_in     : boolean            := false; -- time order in
        g_big_endian_out    : boolean            := false; -- time order out
        g_coefs_file_prefix : string             := c_pfb_fir_coefs_file; --! coefficients file prefix generated by fil_ppf_create.py
        g_ram_primitive     : string             := "auto";
        g_pfb_fir           : t_pfb_fir          := c_pfb_fir; -- standard record from package
        g_pfb_fir_pipeline  : t_pfb_fir_pipeline := c_pfb_fir_pipeline -- standard pipeline record from package
    );
    port(
        clk      : in  std_logic;
        sync_in  : in  std_logic;
        din      : in  t_pfb_fir_array_in((g_pfb_fir.wb_factor * g_pfb_fir.n_streams) - 1 downto 0);
        en       : in  std_logic;
        sync_out : out std_logic;
        dout     : out t_pfb_fir_array_out((g_pfb_fir.wb_factor * g_pfb_fir.n_streams) - 1 downto 0);
        dvalid   : out std_logic
    );
end pfb_fir;

architecture rtl of pfb_fir is

    -- control logic
    constant c_tap_length : natural := (g_pfb_fir.n_bins / g_pfb_fir.wb_factor) * (2 ** g_pfb_fir.n_chans);
    constant c_addr_w     : natural := ceil_log2(c_tap_length);
    signal master_counter : std_logic_vector(c_addr_w - 1 downto 0);

    -- note that this differs from the delay used by CASPER 
    constant c_sync_delay : natural   := 0; --c_tap_length * 1; --(g_pfb_fir.n_taps-1); 
    signal sync_pending   : std_logic := '0';

    constant c_delay_adder_tree : natural := ceil_log2(g_pfb_fir.n_taps) * g_pfb_fir_pipeline.add_latency;
    constant c_delay_total      : natural := g_pfb_fir_pipeline.mem_latency + g_pfb_fir_pipeline.mult_latency + c_delay_adder_tree + g_pfb_fir_pipeline.conv_latency;

    signal en_delay      : std_logic_vector(c_delay_total - 1 downto 0) := (others => '0'); -- enable pipeline
    signal sync_in_delay : std_logic_vector(c_delay_total - 1 downto 0) := (others => '0');

    ------------------
    -- taps 
    ------------------   

    type t_din_array is array (g_pfb_fir.wb_factor - 1 downto 0, g_pfb_fir.n_streams - 1 downto 0) of std_logic_vector(g_pfb_fir.din_w - 1 downto 0);
    --reorder data into little endian format if needed
    signal din_little_endian : t_din_array;

    --interally we group all inputs from the same stream
    type t_dint_array is array (g_pfb_fir.n_streams - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(g_pfb_fir.din_w - 1 downto 0);

    signal din_internal : t_dint_array;

    type t_din_delay is array (g_pfb_fir_pipeline.mem_latency - 1 downto 0) of t_dint_array;
    signal din_delay : t_din_delay;

    --we get the tap with delay of 0 for free                                          
    type t_taps_array is array (natural range <>) of t_dint_array;
    signal taps_in_vec, taps_out_vec : t_taps_array((g_pfb_fir.n_taps - 1) - 1 downto 0);

    constant c_tap_data_w      : natural := g_pfb_fir.wb_factor * g_pfb_fir.n_streams * g_pfb_fir.din_w;
    constant c_taps_mem_data_w : natural := c_tap_data_w * (g_pfb_fir.n_taps - 1);

    constant c_taps_mem             : t_c_mem   := (latency => g_pfb_fir_pipeline.mem_latency,
                                                    adr_w   => c_addr_w,
                                                    dat_w   => c_taps_mem_data_w,
                                                    nof_dat => (g_pfb_fir.n_bins / g_pfb_fir.wb_factor) * (2 ** g_pfb_fir.n_chans),
                                                    init_sl => '0'); -- use '0' instead of 'X' to avoid RTL RAM simulation warnings due to read before write
    signal taps_wr_dat, taps_rd_dat : std_logic_vector(c_taps_mem_data_w - 1 downto 0);
    signal taps_wren                : std_logic := '0';
    signal taps_rdaddr, taps_wraddr : std_logic_vector(c_addr_w - 1 downto 0);

    ------------------
    -- coefficients
    ------------------

    constant c_coefs_total     : natural := g_pfb_fir.wb_factor * g_pfb_fir.n_taps;
    constant c_coef_mem_addr_w : natural := c_addr_w - g_pfb_fir.n_chans;
    constant c_coef_mem_data_w : natural := g_pfb_fir.coef_w;
    constant c_coefs_postfix   : string  := sel_a_b(c_tech_select_default = c_tech_xpm, ".mem", ".mif");
    constant c_coef_mem        : t_c_mem := (latency => g_pfb_fir_pipeline.mem_latency,
                                             adr_w   => c_coef_mem_addr_w,
                                             dat_w   => c_coef_mem_data_w,
                                             nof_dat => g_pfb_fir.n_bins,
                                             init_sl => '0'); -- use '0' instead of 'X' to avoid RTL RAM simulation warnings due to read before write
    -- we set up coefficients in the same ordering as taps
    type t_coef_array is array (g_pfb_fir.n_taps - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(g_pfb_fir.coef_w - 1 downto 0);

    signal coef_vec                     : t_coef_array;
    signal coef_rdaddr, coef_rdaddr_inv : std_logic_vector(c_coef_mem_addr_w - 1 downto 0);

    ------------------    
    --multipliers
    ------------------    

    constant c_mult_din_w : natural := g_pfb_fir.padding + g_pfb_fir.din_w; -- add optional input padding to fit output overshoot
    constant c_prod_w     : natural := g_pfb_fir.din_w + g_pfb_fir.coef_w - 1; -- skip double sign bit
    constant c_n_mults    : natural := g_pfb_fir.wb_factor * g_pfb_fir.n_taps * g_pfb_fir.n_streams;

    signal mult_din : t_taps_array((g_pfb_fir.n_taps - 1) downto 0);

    type t_mult_din_padded_array is array (g_pfb_fir.n_taps - 1 downto 0, g_pfb_fir.n_streams - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(c_mult_din_w - 1 downto 0);
    signal mult_din_padded : t_mult_din_padded_array;

    type t_product_array is array (g_pfb_fir.n_taps - 1 downto 0, g_pfb_fir.n_streams - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(c_prod_w - 1 downto 0);
    signal product_vec : t_product_array;

    ------------------
    --adder tree  
    ------------------

    constant c_gain_w    : natural := 0; -- no need for adder bit growth so fixed 0, because filter coefficients should have DC gain <= 1.
                                         -- The adder tree bit growth depends on DC gain of FIR coefficients, not on ceil_log2(g_fil_ppf.nof_taps). 
    constant c_sum_w     : natural := c_prod_w + c_gain_w;
    constant c_ppf_lsb_w : natural := c_sum_w - g_pfb_fir.dout_w;

    type t_added_array is array (g_pfb_fir.n_streams - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(c_sum_w - 1 downto 0);
    signal adder_out : t_added_array;

    ------------------
    --requantisation  
    ------------------    

    type t_requant_array is array (g_pfb_fir.n_streams - 1 downto 0, g_pfb_fir.wb_factor - 1 downto 0) of std_logic_vector(g_pfb_fir.dout_w - 1 downto 0);
    signal requant_out : t_requant_array;

    ------------------
    --output 
    ------------------

    signal sync_out_int : std_logic;
    signal dvalid_int   : std_logic;
    signal dout_int     : t_pfb_fir_array_out((g_pfb_fir.wb_factor * g_pfb_fir.n_streams) - 1 downto 0);

begin

    -- endinanness reordering if needed
    p_wire_input : process(din)
        variable vW, idx : natural;
    begin
        for W in 0 to g_pfb_fir.wb_factor - 1 loop
            if g_big_endian_in = true then
                vW := g_pfb_fir.wb_factor - 1 - W; -- convert input big endian time [0,1,2,3] to P [3,2,1,0] index mapping to internal little endian
            else
                vW := W;                -- keep input little endian time [0,1,2,3] to P [0,1,2,3] index mapping 
            end if;
            for S in 0 to g_pfb_fir.n_streams - 1 loop
                din_little_endian(vW, S) <= din((W * g_pfb_fir.n_streams) + S);
            end loop;
        end loop;
    end process;

    -- rewire inputs so that streams of data are separated
    p_unpack_input : process(din_little_endian)
        variable idx : natural;
    begin
        for W in 0 to g_pfb_fir.wb_factor - 1 loop
            for S in 0 to g_pfb_fir.n_streams - 1 loop
                idx                := (W * g_pfb_fir.n_streams) + S;
                din_internal(S, W) <= din_little_endian(W, S);
            end loop;
        end loop;
    end process;

    -- control of addresses, pipelines etc
    proc_master : process(clk)
    begin
        if rising_edge(clk) then        --everything is synchronous 
            if (sync_in = '1') then
                master_counter <= (others => '0');
            else
                if (en = '1') then
                    master_counter <= std_logic_vector(unsigned(master_counter) + 1);
                end if;
            end if;

            -- enable pipeline
            en_delay(0)                          <= en;
            en_delay(c_delay_total - 1 downto 1) <= en_delay(c_delay_total - 2 downto 0);
            dvalid_int                           <= en_delay(c_delay_total - 1);

            --sync pipeline
            sync_in_delay(0)                          <= sync_in;
            sync_in_delay(c_delay_total - 1 downto 1) <= sync_in_delay(c_delay_total - 2 downto 0);
            sync_out_int                              <= sync_in_delay(c_delay_total - 1);

        end if;                         --rising_edge(clk)
    end process proc_master;

    dvalid   <= dvalid_int;
    sync_out <= sync_out_int;

    ------------
    -- taps
    ------------

    proc_taps : process(clk)
    begin
        if (rising_edge(clk)) then
            din_delay(0)                                           <= din_internal;
            din_delay(g_pfb_fir_pipeline.mem_latency - 1 downto 1) <= din_delay(g_pfb_fir_pipeline.mem_latency - 2 downto 0);

            -- the write address is delayed while we wait for the data from the read 
            if (sync_in_delay(g_pfb_fir_pipeline.mem_latency - 1) = '1') then
                taps_wraddr <= (others => '0');
            else
                if (en_delay(g_pfb_fir_pipeline.mem_latency - 1) = '1') then
                    taps_wraddr <= std_logic_vector(unsigned(taps_wraddr) + 1);
                end if;
            end if;
        end if;
    end process;

    -- we feed new data in from the lowest index
    taps_in_vec(0)                                   <= din_delay(g_pfb_fir_pipeline.mem_latency - 1);
    taps_in_vec((g_pfb_fir.n_taps - 1) - 1 downto 1) <= taps_out_vec((g_pfb_fir.n_taps - 1) - 2 downto 0);

    -- map logical vector to physical BRAM ports
    p_map_tap_bram_din_mapping : process(taps_in_vec, taps_rd_dat)
        variable idx : natural;
    begin
        for T in 0 to g_pfb_fir.n_taps - 2 loop
            for S in 0 to g_pfb_fir.n_streams - 1 loop
                for W in 0 to g_pfb_fir.wb_factor - 1 loop
                    idx                                                                           := (T * g_pfb_fir.n_streams * g_pfb_fir.wb_factor) + (S * g_pfb_fir.wb_factor) + W;
                    taps_wr_dat(((idx + 1) * g_pfb_fir.din_w) - 1 downto (idx * g_pfb_fir.din_w)) <= taps_in_vec(T)(S, W);
                    taps_out_vec(T)(S, W)                                                         <= taps_rd_dat(((idx + 1) * g_pfb_fir.din_w) - 1 downto (idx * g_pfb_fir.din_w));
                end loop;
            end loop;
        end loop;
    end process;

    taps_rdaddr <= master_counter(c_addr_w - 1 downto 0); --lsbs for channels too
    taps_wren   <= en_delay(g_pfb_fir_pipeline.mem_latency - 1);

    u_taps_mem : entity casper_ram_lib.common_ram_r_w
        generic map(
            g_ram            => c_taps_mem,
            g_init_file      => "UNUSED", -- assume block RAM gets initialized to '0' by default in simulation
            g_true_dual_port => TRUE,
            g_ram_primitive  => g_ram_primitive
        )
        port map(
            clk    => clk,
            clken  => '1',
            wr_en  => taps_wren,
            wr_adr => taps_wraddr,
            wr_dat => taps_wr_dat,
            rd_en  => '1',
            rd_adr => taps_rdaddr,
            rd_dat => taps_rd_dat,
            rd_val => open
        );

    -----------------------
    -- coefficients
    -----------------------

    coef_rdaddr     <= master_counter(c_addr_w - 1 downto g_pfb_fir.n_chans);
    coef_rdaddr_inv <= not (coef_rdaddr);

    gen_coeffs : for T in 0 to (g_pfb_fir.n_taps / 2) - 1 generate
    begin
        gen_inputs : for W in 0 to g_pfb_fir.wb_factor - 1 generate
            signal rd_dat_a, rd_dat_b : std_logic_vector(g_pfb_fir.coef_w - 1 downto 0);
        begin
            -- We require that the g_coefs_file_prefix is just a prefix, details around wideband factor, points etc are appended as appropriate
            u_coef_mem : entity casper_ram_lib.common_rom_r_r
                generic map(
                    g_ram            => c_coef_mem,
                    g_init_file      => sel_a_b(g_coefs_file_prefix = "UNUSED",
                                                g_coefs_file_prefix,
                                                g_coefs_file_prefix & "_" & integer'image(g_pfb_fir.n_taps) & "taps" --append taps
                                                & "_" & integer'image(g_pfb_fir.n_bins) & "points" --append points
                                                & "_" & integer'image(g_pfb_fir.coef_w) & "b" --append bits
                                                & "_" & integer'image(g_pfb_fir.wb_factor) & "wb" --append wideband factor
                                                & "_" & NATURAL'IMAGE((W * g_pfb_fir.n_taps) + T) & c_coefs_postfix), --append incrementer and postfix
                    g_true_dual_port => TRUE,
                    g_ram_primitive  => g_ram_primitive
                )
                port map(
                    clk      => clk,
                    clken    => '1',
                    adr_a    => coef_rdaddr,
                    rd_en_a  => '1',
                    rd_dat_a => rd_dat_a,
                    rd_val_a => open,
                    adr_b    => coef_rdaddr_inv, --count backwards on other port
                    rd_en_b  => '1',
                    rd_dat_b => rd_dat_b --coefficients are symmetrical
                );
            coef_vec(T, W)                                                  <= rd_dat_a;
            coef_vec(g_pfb_fir.n_taps - 1 - T, g_pfb_fir.wb_factor - 1 - W) <= rd_dat_b;
        end generate;
    end generate;

    -----------------
    --multipliers 
    ----------------

    --we get the tap with delay 0 for (almost) free
    mult_din(0)                             <= din_delay(g_pfb_fir_pipeline.mem_latency - 1);
    mult_din(g_pfb_fir.n_taps - 1 downto 1) <= taps_out_vec(g_pfb_fir.n_taps - 2 downto 0);

    gen_mults : for T in 0 to g_pfb_fir.n_taps - 1 generate
    begin
        gen_streams : for S in 0 to g_pfb_fir.n_streams - 1 generate
        begin
            gen_wb : for W in 0 to g_pfb_fir.wb_factor - 1 generate
                signal in_a : std_logic_vector(c_mult_din_w - 1 downto 0);
                signal in_b : std_logic_vector(g_pfb_fir.coef_w - 1 downto 0);
            begin
                in_a <= resize_svec(mult_din(T)(S, W), c_mult_din_w);
                in_b <= coef_vec(T, W);

                u_multiplier : entity casper_multiplier_lib.common_mult
                    generic map(
                        g_use_dsp          => "YES",
                        g_in_a_w           => c_mult_din_w,
                        g_in_b_w           => g_pfb_fir.coef_w,
                        g_out_p_w          => c_prod_w,
                        g_pipeline_input   => sel_a_b(g_pfb_fir_pipeline.mult_latency > 2, 1, 0),
                        g_pipeline_product => sel_a_b(g_pfb_fir_pipeline.mult_latency > 2, 1, 0),
                        g_pipeline_output  => sel_a_b(g_pfb_fir_pipeline.mult_latency > 2, g_pfb_fir_pipeline.mult_latency - 2, g_pfb_fir_pipeline.mult_latency)
                    )
                    port map(
                        rst     => '0',
                        clk     => clk,
                        clken   => '1',
                        in_a    => in_a,
                        in_b    => in_b,
                        in_val  => '1',
                        result  => product_vec(T, S, W),
                        out_val => open
                    );
            end generate;
        end generate;
    end generate;

    -----------------
    --adder trees
    -----------------

    gen_add_quantise : for S in 0 to g_pfb_fir.n_streams - 1 generate
    begin
        gen_streams : for W in 0 to g_pfb_fir.wb_factor - 1 generate
            constant c_offset      : natural := (S * g_pfb_fir.wb_factor) + W;
            signal add_in_dat      : std_logic_vector((g_pfb_fir.n_taps * c_prod_w) - 1 downto 0);
            signal add_sum         : std_logic_vector(c_sum_w - 1 downto 0);
            signal requant_in_dat  : std_logic_vector(c_sum_w - 1 downto 0);
            signal requant_out_dat : std_logic_vector(g_pfb_fir.dout_w - 1 downto 0);

        begin

            gen_taps : for T in 0 to g_pfb_fir.n_taps - 1 generate
            begin
                add_in_dat(((T + 1) * c_prod_w) - 1 downto T * c_prod_w) <= product_vec(T, S, W);
            end generate;

            u_adder_tree : entity casper_adder_lib.common_adder_tree
                generic map(
                    g_representation => "SIGNED",
                    g_pipeline       => g_pfb_fir_pipeline.add_latency,
                    g_nof_inputs     => g_pfb_fir.n_taps,
                    g_dat_w          => c_prod_w,
                    g_sum_w          => c_sum_w
                )
                port map(
                    clk    => clk,
                    clken  => '1',
                    in_dat => add_in_dat,
                    sum    => add_sum   --
                );

            --requantisation
            requant_in_dat <= add_sum;
            u_requantize : entity casper_requantize_lib.common_requantize
                generic map(
                    g_representation      => "SIGNED",
                    g_lsb_w               => c_ppf_lsb_w,
                    g_lsb_round           => ROUND,
                    g_lsb_round_clip      => FALSE,
                    g_msb_clip            => FALSE,
                    g_msb_clip_symmetric  => FALSE,
                    g_pipeline_remove_lsb => 1, --hardcoded for now 
                    g_pipeline_remove_msb => 0, --hardcoded for now
                    g_in_dat_w            => c_sum_w,
                    g_out_dat_w           => g_pfb_fir.dout_w
                )
                port map(
                    clk     => clk,
                    clken   => '1',
                    in_dat  => requant_in_dat,
                    out_dat => requant_out_dat,
                    out_ovr => open
                );

            --insert the result into output array and register the outputs to align with sync and dvalid
            process(clk)
            begin
                if (rising_edge(clk)) then
                    dout_int((W * g_pfb_fir.n_streams) + S) <= requant_out_dat;
                end if;
            end process;
        end generate;
    end generate;

    p_wire_output : process(dout_int)
        variable vW : natural;
    begin
        for W in 0 to g_pfb_fir.wb_factor - 1 loop
            if g_big_endian_out = true then
                vW := g_pfb_fir.wb_factor - 1 - W; -- convert internal little endian to output big endian time [0,1,2,3] to P [3,2,1,0] index mapping
            else
                vW := W;                -- keep internal little endian for output little endian time [0,1,2,3] to P [0,1,2,3] index mapping 
            end if;
            for S in 0 to g_pfb_fir.n_streams - 1 loop
                dout((W * g_pfb_fir.n_streams) + S) <= RESIZE_SVEC(dout_int((vW * g_pfb_fir.n_streams) + S), g_pfb_fir.dout_w);
            end loop;
        end loop;
    end process;

end rtl;
