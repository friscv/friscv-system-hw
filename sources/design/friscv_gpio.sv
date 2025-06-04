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

module friscv_gpio
#(
    parameter   GPIO_ADDRESS = 32'H10000,
    parameter   GPIO_WIDTH = 32
)
(   input  logic                    clk_cpu_in,
    input  logic                    clk_mem_in,
    input  logic                    debug_mode_in,    

    input  logic [ADDR_WIDTH-1:0]   d_mem_addr_in,
    input  logic [GPIO_WIDTH-1:0]   d_mem_data_in,
    output logic [GPIO_WIDTH-1:0]   d_mux_gpio_data_out,

    input  logic                    d_mem_en_in,
    input  logic                    d_mem_wr_in,
    input logic                     rst_n_in,

    input  logic [GPIO_WIDTH-1:0]   gpio_in,
    output logic [GPIO_WIDTH-1:0]   gpio_out,
    output logic [GPIO_WIDTH-1:0]   gpio_tristate_out
);
	    
logic [GPIO_WIDTH-1:0] gpio_buff;
logic [GPIO_WIDTH-1:0] gpio_tristate_buff;


always_ff @(negedge clk_mem_in) begin
    if (~rst_n_in) begin
        gpio_buff <= 0;
        gpio_tristate_buff <= 0;        
    end
    else if (~debug_mode_in) begin
        if (~clk_cpu_in && d_mem_en_in) begin
            if (d_mem_wr_in) begin
                if (d_mem_addr_in == GPIO_ADDRESS) begin                 
                    gpio_buff <= d_mem_data_in;            
                end
                else if (d_mem_addr_in == (GPIO_ADDRESS+4)) begin                 
                    gpio_tristate_buff <= d_mem_data_in;            
                end
            end
        end
    end
    
end

assign d_mux_gpio_data_out = gpio_in;
assign gpio_out = gpio_buff;
assign gpio_tristate_out = gpio_tristate_buff;

endmodule


