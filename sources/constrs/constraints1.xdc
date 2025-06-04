
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { rst_pushbutton_in }];  #IO_L4P_T0_35 Sch=btn[0]

#  Clock signal 125 MHz
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { clk_extern_in }]; #IO_L13P_T2_MRCC_35 Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk_extern_in }];

## End signal connected to led5 green
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { end_signal_out }]; #IO_L22P_T3_AD7P_35 Sch=led5_g

##GPIO1 connections
##LEDs connected to GPIO1
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led0_out }]; #IO_L6N_T0_VREF_34 Sch=led[0]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led1_out }]; #IO_L6P_T0_34 Sch=led[1]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[2] }]; #IO_L21N_T3_DQS_AD14N_35 Sch=led[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[3] }]; #IO_L23P_T3_35 Sch=led[3]
##RGB LEDs connected to GPIO1
#set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[4] }]; #IO_L22N_T3_AD7N_35 Sch=led4_b
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[5] }]; #IO_L16P_T2_35 Sch=led4_g
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[6] }]; #IO_L21P_T3_DQS_AD14P_35 Sch=led4_r
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { gpio2_data_out[7] }]; #IO_0_35 Sch=led5_b

set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw0_in }]; #IO_L7N_T1_AD2N_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { sw1_in }]; #IO_L7P_T1_AD2P_35 Sch=sw[1]

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


# OLD Constraints
##RGB LEDs

#set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { led4_b }]; #IO_L22N_T3_AD7N_35 Sch=led4_b
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { led4_g }]; #IO_L16P_T2_35 Sch=led4_g
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { led4_r }]; #IO_L21P_T3_DQS_AD14P_35 Sch=led4_r
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led5_b }]; #IO_0_35 Sch=led5_b
#set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { led5_g }]; #IO_L22P_T3_AD7P_35 Sch=led5_g
#set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led5_r }]; #IO_L23N_T3_35 Sch=led5_r

##LEDs

#set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led0 }]; #IO_L6N_T0_VREF_34 Sch=led[0]
#set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led1 }]; #IO_L6P_T0_34 Sch=led[1]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led2 }]; #IO_L21N_T3_DQS_AD14N_35 Sch=led[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led3 }]; #IO_L23P_T3_35 Sch=led[3]


