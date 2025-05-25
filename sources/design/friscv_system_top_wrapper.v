/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK, 
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or 
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

Version info is listed in friscv_pkg.sv
*/

module friscv_system_top_wrapper(

    input clk_extern_in,
    input rst_n_extern_in,
    input rst_pushbutton_in,
    input clk_debug_extern_in,
    input [1:0] debug_control_in,  /* [1] debug_mem_wr_in [0] debug_mode_in */ 
    output [1:0] debug_signals_out, //[1]end_signal_out,[0]debug_cpu_stopped_out
    input [31:0] debug_mem_addr_in,
    input [31:0] debug_mem_data_in,
    output [31:0] debug_mem_data_out,
    output  [7:0] gpio1_data_out,
    output  [7:0] gpio2_data_out,  
    output  end_signal_out

);

    friscv_system_top friscv_system_top_0(
        .clk_extern_in(clk_extern_in),
        .rst_n_extern_in(rst_n_extern_in),
        .rst_pushbutton_in(rst_pushbutton_in),
        .clk_debug_extern_in (clk_debug_extern_in),
        .debug_mode_in(debug_control_in[0]),
        .debug_mem_wr_in(debug_control_in[1]),
        .debug_signals_out(debug_signals_out),
        .debug_mem_addr_in(debug_mem_addr_in),
        .debug_mem_data_in(debug_mem_data_in),
        .debug_mem_data_out(debug_mem_data_out),
        .gpio1_data_out(gpio1_data_out),
        .gpio2_data_out(gpio2_data_out),
        .end_signal_out(end_signal_out)
    );

endmodule