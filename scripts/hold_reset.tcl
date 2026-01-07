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

# Hold reset
mwr 0x41210000 0x0

puts "FRISC-V in reset"

disconnect
exit
