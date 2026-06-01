set script_dir [file dirname [info script]]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

source [file join $script_dir ../overlay/ps7_init.tcl]
ps7_init
ps7_post_config

configparams force-mem-accesses 1
mwr 0x41200000 0x0
after 100
mwr 0x41200000 0x1
disconnect
exit
