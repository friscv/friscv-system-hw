# Generate Zynq FSBL source from XSA
# Usage: xsct gen_fsbl.tcl <xsa_path> <output_dir>

set xsa_path [lindex $argv 0]
set output_dir [lindex $argv 1]

set hw [hsi::open_hw_design $xsa_path]
hsi::generate_app -hw $hw -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -dir $output_dir
hsi::close_hw_design $hw

puts "FSBL generated in $output_dir"
