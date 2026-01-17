set script_dir [file dirname [info script]]

connect
targets -set -filter {name =~ "ARM*#0"}

if {![file exists $script_dir/ps7_init.tcl]} {
    puts "ERROR: ps7_init.tcl not found in $script_dir"
    puts "This file is required to initialize the PS7."
    puts "Please run 'make bitstream' to generate it."
    disconnect
    exit 1
}

puts "Initializing PS7..."
source $script_dir/ps7_init.tcl

if {[catch {ps7_init} result]} {
    puts "ERROR: ps7_init failed: $result"
    puts "The PS7 initialization script may be incompatible with the programmed bitstream."
    disconnect
    exit 1
}

if {[catch {ps7_post_config} result]} {
    puts "ERROR: ps7_post_config failed: $result"
    disconnect
    exit 1
}

puts "PS7 initialized successfully."

# Enable force memory access to allow PL peripheral access
configparams force-mem-accesses 1

# Release reset
mwr 0x41200000 0x1

puts "FRISC-V running"

disconnect
exit
