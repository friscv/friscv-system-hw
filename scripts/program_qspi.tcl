# Program QSPI flash on Zynq with BOOT.bin
# Usage: xsdb program_qspi.tcl <boot.bin> <fsbl.elf>

set boot_bin [lindex $argv 0]
set fsbl_elf [lindex $argv 1]

exec program_flash -f $boot_bin -offset 0 -flash_type qspi-x4-single -fsbl $fsbl_elf -url TCP:localhost:3121 -verify >@stdout 2>@stderr
