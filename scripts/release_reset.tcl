set script_dir [file dirname [info script]]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

source $script_dir/ps7_init.tcl
ps7_init
ps7_post_config

configparams force-mem-accesses 1
mwr 0x41200000 0x1
disconnect
exit
