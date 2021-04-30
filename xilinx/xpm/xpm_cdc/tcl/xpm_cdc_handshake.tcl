# Scoped constraints for xpm_cdc_handshake
set src_clk  [get_clocks -quiet -of [get_ports src_clk]]
set dest_clk [get_clocks -quiet -of [get_ports dest_clk]]

set src_clk_period  [get_property -quiet -min PERIOD $src_clk]
set dest_clk_period [get_property -quiet -min PERIOD $dest_clk]

set xpm_cdc_hs_width [llength [get_cells dest_hsdata_ff_reg[*]]]
set xpm_cdc_hs_num_s2d_dsync_ff [llength [get_cells xpm_cdc_single_src2dest_inst/syncstages_ff_reg[*]]]

if {$src_clk == ""} {
    set src_clk_period 1000
}

if {$dest_clk == ""} {
    set dest_clk_period 1001
}

if {($src_clk != $dest_clk) || ($src_clk == "" && $dest_clk == "")} {
    if {$xpm_cdc_hs_width <= 100} {
        set_max_delay -from [get_cells src_hsdata_ff_reg*] -to [get_cells dest_hsdata_ff_reg*] [expr {$dest_clk_period * $xpm_cdc_hs_num_s2d_dsync_ff}] -datapath_only
        set_bus_skew  -from [get_cells src_hsdata_ff_reg*] -to [get_cells dest_hsdata_ff_reg*] [expr {$dest_clk_period * $xpm_cdc_hs_num_s2d_dsync_ff}]
    } else {
        set_max_delay -from [get_cells src_hsdata_ff_reg*] -to [get_cells dest_hsdata_ff_reg*] [expr min ($src_clk_period, $dest_clk_period)] -datapath_only
    }
} elseif {$src_clk != "" && $dest_clk != ""} {
    common::send_msg_id "XPM_CDC_HANDSHAKE: TCL-1000" "WARNING" "The source and destination clocks are the same. \n     Instance: [current_instance .] \n  This will add unnecessary latency to the design. Please check the design for the following: \n 1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules. \n 2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message."
}

create_waiver -internal -scoped -type CDC -id {CDC-15} -user "xpm_cdc" -tags "1009444"\
-desc "The CDC-15 warning is waived as it is safe in the context of XPM_CDC_HANDSHAKE." \
-from [get_pins -quiet {src_hsdata_ff_reg*/C}] \
-to [get_pins -quiet {dest_hsdata_ff_reg*/D}]
