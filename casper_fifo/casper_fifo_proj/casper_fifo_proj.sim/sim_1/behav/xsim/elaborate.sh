#!/bin/bash -f
# ****************************************************************************
# Vivado (TM) v2019.1 (64-bit)
#
# Filename    : elaborate.sh
# Simulator   : Xilinx Vivado Simulator
# Description : Script for elaborating the compiled design
#
# Generated by Vivado on Fri Aug 14 12:33:44 SAST 2020
# SW Build 2552052 on Fri May 24 14:47:09 MDT 2019
#
# Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
#
# usage: elaborate.sh
#
# ****************************************************************************
set -Eeuo pipefail
echo "xelab -wto f07e2515bea94ce989966c8f97bd7812 --incr --debug typical --relax --mt 8 -L common_pkg_lib -L casper_fifo_lib -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot tb_common_fifo_rd_behav casper_fifo_lib.tb_common_fifo_rd casper_fifo_lib.glbl -log elaborate.log"
xelab -wto f07e2515bea94ce989966c8f97bd7812 --incr --debug typical --relax --mt 8 -L common_pkg_lib -L casper_fifo_lib -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot tb_common_fifo_rd_behav casper_fifo_lib.tb_common_fifo_rd casper_fifo_lib.glbl -log elaborate.log

