set script_dir [file dirname [info script]]

connect
targets -set -filter {name =~ "ARM*#0"}

# Initialize PS if ps7_init.tcl exists
if {[file exists $script_dir/ps7_init.tcl]} {
    source $script_dir/ps7_init.tcl
    ps7_init
    ps7_post_config
}

# Enable force memory access to allow PL peripheral access
configparams force-mem-accesses 1

# Release reset
mwr 0x41200000 0x1

puts "FRISC-V running"

disconnect
exit
