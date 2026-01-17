set script_dir [file dirname [info script]]
set bin_file [lindex $argv 0]
set ddr_base [lindex $argv 1]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

if {![file exists $script_dir/ps7_init.tcl]} {
    puts "ERROR: ps7_init.tcl not found in $script_dir"
    puts "This file is required to initialize the PS7 DDR controller."
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

# Wait for DDR to stabilize
puts "Waiting for DDR to stabilize..."
after 1000

# Test DDR accessibility with a simple write/read test
puts "Testing DDR accessibility at 0x[format %08X $ddr_base]..."
set test_addr $ddr_base
if {[catch {mwr $test_addr 0xDEADBEEF} result]} {
    puts "ERROR: Cannot write to DDR at address 0x[format %08X $test_addr]"
    puts "Error: $result"
    puts "PS7/DDR controller may not be properly initialized."
    disconnect
    exit 1
}

if {[catch {set readback [mrd -value $test_addr]} result]} {
    puts "ERROR: Cannot read from DDR at address 0x[format %08X $test_addr]"
    puts "Error: $result"
    disconnect
    exit 1
}

if {$readback != 0xDEADBEEF} {
    puts "=========================================="
    puts "ERROR: Memory read/write test failed!"
    puts "=========================================="
    puts "Test address: 0x[format %08X $test_addr]"
    puts "Wrote:        0xDEADBEEF"
    puts "Read back:    0x[format %08X $readback]"
    puts ""
    puts "DDR is not working. OCM range: 0x00000000-0x0002FFFF"
    puts "=========================================="
    disconnect
    exit 1
}

puts "DDR test passed (0x[format %08X $test_addr] = 0xDEADBEEF)"

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
