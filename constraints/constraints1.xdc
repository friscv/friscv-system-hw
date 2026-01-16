set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { rst_pushbutton_in }];  #IO_L4P_T0_35 Sch=btn[0]
set_false_path -from [get_ports rst_pushbutton_in]

## End signal connected to led5 green
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { end_signal_out }]; #IO_L22P_T3_AD7P_35 Sch=led5_g
set_false_path -to [get_ports end_signal_out]
## Reset signal connected to led5 red
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { rst_out }]; #IO_L23N_T3_35 Sch=led5_r
set_false_path -to [get_ports rst_out]

# UART on PMOD A
set_property PACKAGE_PIN Y18 [get_ports uart_tx];  # PMOD A Pin 1
set_property PACKAGE_PIN Y19 [get_ports uart_rx];  # PMOD A Pin 2
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx];
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx];
set_false_path -to [get_ports uart_tx]
set_false_path -from [get_ports uart_rx]

# LEDs
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_false_path -to [get_ports {led[*]}]

set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw_in[0] }]; #IO_L7N_T1_AD2N_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { sw_in[1] }]; #IO_L7P_T1_AD2P_35 Sch=sw[1]
set_false_path -from [get_ports {sw_in[*]}]

##GPIO2 conncetions
## Arduino GPIO
#set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[0]}];
#set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[1]}];
#set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[2]}];
#set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[3]}];
#set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[4]}];
#set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[5]}];
#set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[6]}];
#set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {gpio1_data_out[7]}];
