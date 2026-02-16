set script_dir [file dirname [info script]]
set bin_file [lindex $argv 0]
set ddr_base [lindex $argv 1]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

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

# Enable force memory access to allow PL peripheral access
configparams force-mem-accesses 1

# Wait for DDR to stabilize
after 1000

# Hold in reset
mwr 0x41200000 0x0

# Get file size to determine how much memory to zero
set file_size [file size $bin_file]
# Round up to nearest 4KB boundary for zeroing
set zero_size [expr {(($file_size + 4095) / 4096) * 4096}]

for {set addr $ddr_base} {$addr < ($ddr_base + $zero_size)} {incr addr 4} {
    mwr $addr 0x0
}

# Load program
dow -data $bin_file $ddr_base

disconnect
exit
