#!/bin/sh
# General Cores uses

# We only want certain files with usable licenses from ohwr
wget -O gencores_pkg.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gencores_pkg.vhd?inline=false
wget -O inferred_async_fifo.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/common/inferred_async_fifo.vhd?inline=false 
wget -O genram_pkg.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/genram_pkg.vhd?inline=false
wget -O gc_sync_register.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_sync_register.vhd?inline=false
wget -O gc_sync_word_rd.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_sync_word_rd.vhd?inline=false
wget -O gc_sync_ffs.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_sync_ffs.vhd?inline=false
wget -O gc_sync.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_sync.vhd?inline=false
wget -O gc_edge_detect.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_edge_detect.vhd?inline=false
wget -O gc_pulse_synchronizer2.vhd https://ohwr.org/project/general-cores/raw/master/modules/common/gc_pulse_synchronizer2.vhd?inline=false
wget -O inferred_sync_fifo.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/common/inferred_sync_fifo.vhd?inline=false
wget -O generic_dpram.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/xilinx/generic_dpram.vhd?inline=false
wget -O memory_loader_pkg.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/memory_loader_pkg.vhd?inline=false
wget -O generic_dpram_split.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/xilinx/generic_dpram_split.vhd?inline=false
wget -O generic_dpram_sameclock.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/xilinx/generic_dpram_sameclock.vhd?inline=false
wget -O generic_dpram_dualclock.vhd https://ohwr.org/project/general-cores/raw/master/modules/genrams/xilinx/generic_dpram_dualclock.vhd?inline=false

