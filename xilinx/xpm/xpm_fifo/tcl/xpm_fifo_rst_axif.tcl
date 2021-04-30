# Scoped constraints for xpm_fifo
#if {([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
#set_false_path -from [get_pins -hierarchical -filter {NAME =~ *wr_rst_i_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *d_out_reg/D}]
#wr_rst_rd_reg[*]/D}]
#set_false_path -from [get_pins -hierarchical -filter {NAME =~ *rd_rst_d3_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *d_out_reg/D}]
#}

##Write Addr Channel
if {([llength [get_cells -quiet -hierarchical  -regexp .*axi_write_address_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports s_aclk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hierarchical  -regexp .*axi_write_address_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}

##Write Data Channel
if {([llength [get_cells -quiet -hierarchical  -regexp .*axi_write_data_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports s_aclk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hierarchical  -regexp .*axi_write_data_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}

##Write Response Channel
if {([llength [get_cells -quiet -hierarchical  -regexp .*axi_write_resp_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports m_aclk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hierarchical  -regexp .*axi_write_resp_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}

##Read Addr Channel
if {([llength [get_cells -quiet -hierarchical  -regexp .*axi_read_addr_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports s_aclk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hierarchical  -regexp .*axi_read_addr_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}

##Read Data Channel
if {([llength [get_cells -quiet -hierarchical  -regexp .*axi_read_data_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0) && ([llength [ get_cells -hier *src_gray_ff_reg* -quiet]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports m_aclk] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_obj [get_cells -hierarchical  -regexp .*axi_read_data_ch.* -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
}



