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

`include "friscv_pkg.sv"
`timescale 1ns / 1ps

module friscv_system_top(
    input clk_extern_in,
    input rst_n_extern_in,
    input rst_pushbutton_in,

// Arm debug memory interface
    input logic clk_debug_extern_in,
    input logic debug_mode_in,
    input logic [ADDR_WIDTH-1:0] debug_mem_addr_in,
    input logic [DATA_WIDTH-1:0] debug_mem_data_in,
    output logic [DATA_WIDTH-1:0] debug_mem_data_out,
    input logic debug_mem_wr_in,
    output logic [1:0] debug_signals_out,

    //GPIO interface
    output logic [GPIO1_WIDTH-1:0] gpio1_out,
    input  logic [GPIO1_WIDTH-1:0] gpio1_in,
    output logic [GPIO1_WIDTH-1:0] gpio1_tristate_out,

    output logic [GPIO2_WIDTH-1:0] gpio2_out,
    input  logic [GPIO2_WIDTH-1:0] gpio2_in,
    output logic [GPIO2_WIDTH-1:0] gpio2_tristate_out,

    output logic      end_signal_out
    
);



    logic clk_cpu, clk_mem;
    logic rst_n_cpu;
    logic [ADDR_WIDTH-1:0]  cpu_i_mem_addr;
    logic [DATA_WIDTH-1:0]  cpu_i_mem_data;
    logic                   cpu_i_mem_en;
    logic                   cpu_i_mem_stall;
    logic [ADDR_WIDTH-1:0]  cpu_d_mem_addr;
    logic [DATA_WIDTH-1:0]  cpu_d_mem_data_o;
    logic [DATA_WIDTH-1:0]  cpu_d_mem_data_i;
    logic [DATA_WIDTH-1:0]  mux_d_mem_data_i;
    logic                   cpu_d_mem_en;
    logic                   cpu_d_mem_wr;
    logic [1:0]             cpu_d_mem_size;
    logic                   cpu_d_mem_stall;
    logic                   end_signal_output;
    logic [GPIO1_WIDTH-1:0] d_mux_gpio1_data_in;
    logic [GPIO2_WIDTH-1:0] d_mux_gpio2_data_in;



    friscv_clock_divider friscv_clock_divider_0 (
        .clk_extern_in(clk_extern_in),
        .clk_cpu_out(clk_cpu),
        .clk_mem_out(clk_mem),
        .cpu_clock_stop_in(debug_mode_in),
        .cpu_clock_stopped_out(debug_signals_out[0]) 
    );

 
    friscv_cpu friscv_cpu_0(
        .clk_cpu_in(clk_cpu),
        .rst_n_cpu_in (rst_n_cpu),
        .i_mem_addr_out(cpu_i_mem_addr),
        .i_mem_data_in(cpu_i_mem_data),
        .i_mem_en_out(cpu_i_mem_en),
        //.i_mem_stall_in(cpu_i_mem_stall),
        .d_mem_addr_out(cpu_d_mem_addr),
        .d_mem_data_out(cpu_d_mem_data_o),
        .d_mem_data_in(cpu_d_mem_data_i),
        .d_mem_en_out(cpu_d_mem_en),
        .d_mem_wr_out(cpu_d_mem_wr),
        .d_mem_size_out(cpu_d_mem_size)
    );


    friscv_memory friscv_memory_0(
        .clk_cpu_in(clk_cpu),
        .clk_mem_in(clk_mem),
        .clk_debug_in(clk_debug_extern_in),
        .debug_mode_in(debug_mode_in),

        .i_mem_addr_in(cpu_i_mem_addr),
        .i_mem_data_out(cpu_i_mem_data),
        .i_mem_en_in(cpu_i_mem_en),

        .d_mem_addr_in(cpu_d_mem_addr),
        .d_mem_data_in(cpu_d_mem_data_o),
        .d_mem_data_out(mux_d_mem_data_i),
        .d_mem_en_in(cpu_d_mem_en),
        .d_mem_wr_in(cpu_d_mem_wr),
        .d_mem_size_in(cpu_d_mem_size),

        .debug_mem_addr_in(debug_mem_addr_in),
        .debug_mem_data_in(debug_mem_data_in),
        .debug_mem_data_out(debug_mem_data_out),
        .debug_mem_wr_in(debug_mem_wr_in)
    );
    
    friscv_d_mem_in_mux friscv_d_mem_in_mux_0(

        .d_mem_addr_in(cpu_d_mem_addr),
        .d_mux_mem_data_out(cpu_d_mem_data_i),

        .d_mux_mem_data_in(mux_d_mem_data_i),
        .d_mux_gpio1_data_in(d_mux_gpio1_data_in),
        .d_mux_gpio2_data_in(d_mux_gpio2_data_in)
    );



    
    friscv_end friscv_end_0(
        .clk_cpu_in(clk_cpu),
        .clk_mem_in(clk_mem),
        .debug_mode_in(debug_mode_in),    
        .d_mem_addr_in(cpu_d_mem_addr),
        .d_mem_data_in(cpu_d_mem_data_o),
        .d_mem_en_in(cpu_d_mem_en),
        .d_mem_wr_in(cpu_d_mem_wr),
        .rst_n_in(rst_n_cpu),
        .end_signal_out(end_signal_output)
    );


 friscv_gpio #(.GPIO_ADDRESS(GPIO1_ADDR), .GPIO_WIDTH(GPIO1_WIDTH)) friscv_gpio_1 (
        .clk_cpu_in(clk_cpu),
        .clk_mem_in(clk_mem),
        .debug_mode_in(debug_mode_in),    
        .d_mem_addr_in(cpu_d_mem_addr),
        .d_mem_data_in(cpu_d_mem_data_o),
        .d_mux_gpio_data_out(d_mux_gpio1_data_in),
        .d_mem_en_in(cpu_d_mem_en),
        .d_mem_wr_in(cpu_d_mem_wr),
        .rst_n_in(rst_n_cpu),
        .gpio_in(gpio1_in),
        .gpio_out(gpio1_out),
        .gpio_tristate_out(gpio1_tristate_out)
    );

 friscv_gpio #(.GPIO_ADDRESS(GPIO2_ADDR), .GPIO_WIDTH(GPIO2_WIDTH)) friscv_gpio_2 (
        .clk_cpu_in(clk_cpu),
        .clk_mem_in(clk_mem),
        .debug_mode_in(debug_mode_in),    
        .d_mem_addr_in(cpu_d_mem_addr),
        .d_mem_data_in(cpu_d_mem_data_o),
        .d_mux_gpio_data_out(d_mux_gpio2_data_in),
        .d_mem_en_in(cpu_d_mem_en),
        .d_mem_wr_in(cpu_d_mem_wr),
        .rst_n_in(rst_n_cpu),
        .gpio_in(gpio1_in),
        .gpio_out(gpio1_out),
        .gpio_tristate_out(gpio1_tristate_out)
    );
    

    always_ff @(negedge clk_cpu) begin
        if (~rst_n_extern_in | rst_pushbutton_in )
            rst_n_cpu<=0;
        else
            rst_n_cpu<=1;
    end

    always_comb begin
       debug_signals_out[1] <= end_signal_output;
       end_signal_out <= end_signal_output;
    end  

endmodule