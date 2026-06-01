set script_dir [file dirname [info script]]

connect
targets -set -filter {name =~ "ARM*#0"}

set ps7_init [file join $script_dir ../overlay/ps7_init.tcl]
if {[file exists $ps7_init]} {
    source $ps7_init
    ps7_init
    ps7_post_config
}

configparams force-mem-accesses 1

puts "\nFirst instructions at 0x00100000:"
if {[catch {mrd 0x00100000 16} result]} {
    puts "ERROR reading memory at 0x00100000: $result"
} else {
    puts $result
}

disconnect
exit
