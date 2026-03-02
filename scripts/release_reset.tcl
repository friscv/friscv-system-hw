connect
targets -set -filter {name =~ "ARM*#0"}
catch {stop}
configparams force-mem-accesses 1
mwr 0x41200000 0x1
disconnect
exit
