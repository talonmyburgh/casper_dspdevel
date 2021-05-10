# Scoped constraints for xpm_memory
set my_var "" 
set my_var [get_property dram_emb_xdc [get_cells -hier  -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==uram || PRIMITIVE_SUBGROUP==BRAM}]]
if {[lsort -unique $my_var] == [list {} yes]} {
if {([llength [get_cells -quiet -hier * -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram}]] > 0)} {
  set_false_path -from [filter [all_fanout -from [get_ports clka] -flat -endpoints_only] {IS_LEAF}] -through [get_pins -of_objects [get_cells -hier * -filter {PRIMITIVE_SUBGROUP==LUTRAM || PRIMITIVE_SUBGROUP==dram || PRIMITIVE_SUBGROUP==drom}] -filter {DIRECTION==OUT}]
if {([llength [get_cells -quiet -hier -filter {NAME =~*doutb*reg*}]] > 0)} {
set_false_path -from [filter [all_fanout -from [get_ports clka] -flat -endpoints_only] {IS_LEAF}] -to [get_cells -hierarchical -filter {NAME =~ *doutb*reg*}]
}
}
}
