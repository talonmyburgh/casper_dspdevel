# Scoped constraints for xpm_fifo
#if {([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
#set_false_path -from [get_pins -hierarchical -filter {NAME =~ *wr_rst_i_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *d_out_reg/D}]
#wr_rst_rd_reg[*]/D}]
#set_false_path -from [get_pins -hierarchical -filter {NAME =~ *rd_rst_d3_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *d_out_reg/D}]
#}

if {([llength [get_cells -quiet -hier * -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports wr_clk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hier * -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}

