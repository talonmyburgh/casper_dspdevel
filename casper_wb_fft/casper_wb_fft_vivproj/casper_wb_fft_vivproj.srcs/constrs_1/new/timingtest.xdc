create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports {in_bsn[*]}]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports {in_bsn[*]}]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports {in_err[*]}]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports {in_err[*]}]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports {in_im_0[*]}]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports {in_im_0[*]}]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports {in_re_0[*]}]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports {in_re_0[*]}]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports {in_shiftreg[*]}]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports {in_shiftreg[*]}]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports ce]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports ce]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports in_sop]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports in_sop]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports in_sync]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports in_sync]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports in_valid]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports in_valid]
#set_input_delay -clock [get_clocks clk] -min -add_delay 2.500 [get_ports rst]
#set_input_delay -clock [get_clocks clk] -max -add_delay 5.000 [get_ports rst]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports {out_bsn[*]}]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports {out_bsn[*]}]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports {out_err[*]}]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports {out_err[*]}]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports {out_im_0[*]}]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports {out_im_0[*]}]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports {out_ovflw[*]}]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports {out_ovflw[*]}]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports {out_re_0[*]}]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports {out_re_0[*]}]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports out_eop]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports out_eop]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports out_sop]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports out_sop]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports out_sync]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports out_sync]
#set_output_delay -clock [get_clocks clk] -min -add_delay -3.000 [get_ports out_valid]
#set_output_delay -clock [get_clocks clk] -max -add_delay 2.500 [get_ports out_valid]
