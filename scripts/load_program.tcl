set script_dir [file dirname [info script]]
set bin_file [lindex $argv 0]
set ddr_base [lindex $argv 1]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

# Initialize PS if ps7_init.tcl exists
if {[file exists $script_dir/ps7_init.tcl]} {
    source $script_dir/ps7_init.tcl
    ps7_init
    ps7_post_config
}

# Enable force memory access to allow PL peripheral access
configparams force-mem-accesses 1

# Hold in reset
mwr 0x41200000 0x0

# Get file size to determine how much memory to zero
set file_size [file size $bin_file]
# Round up to nearest 4KB boundary for zeroing
set zero_size [expr {(($file_size + 4095) / 4096) * 4096}]

puts "Zeroing memory region: 0x[format %08X $ddr_base] - 0x[format %08X [expr {$ddr_base + $zero_size - 1}]] ($zero_size bytes)"

for {set addr $ddr_base} {$addr < ($ddr_base + $zero_size)} {incr addr 4} {
    mwr $addr 0x0
}

puts "Memory zeroed."

# Load program
dow -data $bin_file $ddr_base

puts "Program loaded. Ready to run with 'make run'"

disconnect
exit
