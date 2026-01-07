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

# Read reset register
set reset_val [mrd -value 0x41210000]
puts "Reset register: $reset_val"

# Read base address register
set base_addr [mrd -value 0x41200000]
puts "Base address register: 0x[format %08X $base_addr]"

# Read first few instructions from DDR memory at address 0x0
puts "\nFirst instructions at 0x0:"
if {[catch {mrd 0x0 16} result]} {
    puts "ERROR reading memory at 0x0: $result"
} else {
    puts $result
}

# If base address is set, try reading from there too
if {$base_addr != 0} {
    puts "\nFirst instructions at base address 0x[format %08X $base_addr]:"
    if {[catch {mrd $base_addr 16} result]} {
        puts "ERROR reading memory at 0x[format %08X $base_addr]: $result"
    } else {
        puts $result
    }
}

disconnect
exit
