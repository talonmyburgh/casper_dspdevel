# Scoped constraints for xpm_cdc_array_single
set src_clk  [get_clocks -quiet -of [get_ports src_clk]]
set dest_clk [get_clocks -quiet -of [get_ports dest_clk]]

if {($src_clk != $dest_clk) || ($src_clk == "" && $dest_clk == "")} {
    set_false_path -to [get_cells syncstages_ff_reg[0][*]]
} elseif {$src_clk != "" && $dest_clk != ""} {
    common::send_msg_id "XPM_CDC_ARRAY_SINGLE: TCL-1000" "WARNING" "The source and destination clocks are the same. \n     Instance: [current_instance .] \n  This will add unnecessary latency to the design. Please check the design for the following: \n 1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules. \n 2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message."
}
