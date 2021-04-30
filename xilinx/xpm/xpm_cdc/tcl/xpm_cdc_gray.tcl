# Scoped constraints for xpm_cdc_gray
set src_clk  [get_clocks -quiet -of [get_ports src_clk]]
set dest_clk [get_clocks -quiet -of [get_ports dest_clk]]

set src_clk_period  [get_property -quiet -min PERIOD $src_clk]
set dest_clk_period [get_property -quiet -min PERIOD $dest_clk]

if {$src_clk == ""} {
    set src_clk_period 1000
}

if {$dest_clk == ""} {
    set dest_clk_period 1001
}

if {($src_clk != $dest_clk) || ($src_clk == "" && $dest_clk == "")} {
    set_max_delay -from [get_cells src_gray_ff_reg*] -to [get_cells dest_graysync_ff_reg[0]*] $src_clk_period -datapath_only
    set_bus_skew  -from [get_cells src_gray_ff_reg*] -to [get_cells dest_graysync_ff_reg[0]*] [expr min ($src_clk_period, $dest_clk_period)]
} elseif {$src_clk != "" && $dest_clk != ""} {
    common::send_msg_id "XPM_CDC_GRAY: TCL-1000" "WARNING" "The source and destination clocks are the same. \n     Instance: [current_instance .] \n  This will add unnecessary latency to the design. Please check the design for the following: \n 1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules. \n 2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message."
}

create_waiver -internal -scoped -type CDC -id {CDC-6} -user "xpm_cdc" -tags "1009444"\
-desc "The CDC-6 warning is waived as it is safe in the context of XPM_CDC_GRAY." \
-from [get_pins -quiet {src_gray_ff_reg*/C}] \
-to [get_pins -quiet {dest_graysync_ff_reg*/D}]

