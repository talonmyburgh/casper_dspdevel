#!/bin/sh

WORKING_DIR="/home/talon/Documents/CASPERWORK/CASPERFFT/casper_common_pkg"

ghdl-llvm -a --std=08 $WORKING_DIR/common_pkg.vhd;
ghdl-llvm -a --std=08 $WORKING_DIR/common_pkg_tb.vhd;
ghdl-llvm -a --std=08 $WORKING_DIR/common_lfsr_sequences_pkg.vhd;
ghdl-llvm -a --std=08 $WORKING_DIR/common_str_pkg.vhd;
ghdl-llvm -e --std=8 $common_pkg_tb;
ghdl-llvm -r --workdir=$WORKING_DIR/work.ghdl $PROJECT_NAME_TB --vcd=$WORKING_DIR/$PROJECT_NAME/simulation.vcd;