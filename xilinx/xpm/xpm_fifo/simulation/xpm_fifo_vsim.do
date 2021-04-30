vlib work
vlog /proj/xbuilds/2016.3_daily_latest/installs/lin64/Vivado/2016.3/data/ip/xpm/xpm_fifo/simulation/xpm_fifo_tb.sv
vsim -c -voptargs="+acc" -L work -L /proj/xbuilds/2016.3_daily_latest/clibs/questa/10.5b/lin64/lib/xpm work.xpm_fifo_tb
