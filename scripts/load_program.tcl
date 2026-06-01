set script_dir [file dirname [info script]]
set bin_file [lindex $argv 0]
set ddr_base [lindex $argv 1]

connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}

puts "Initializing PS7..."
source [file join $script_dir ../overlay/ps7_init.tcl]

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

puts "Zeroing memory..."

set zero_words [expr {$zero_size / 4}]
set burst_words 1024
for {set word_idx 0} {$word_idx < $zero_words} {incr word_idx $burst_words} {
    set words_this_burst [expr {($word_idx + $burst_words <= $zero_words) ? $burst_words : ($zero_words - $word_idx)}]
    set burst_addr [expr {$ddr_base + ($word_idx * 4)}]
    mwr $burst_addr 0x0 $words_this_burst
}

puts "Loading program..."

# Load program
dow -data $bin_file $ddr_base

disconnect
exit
