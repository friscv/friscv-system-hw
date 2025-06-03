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

module friscv_d_mem_in_mux
(
// CPU interface
    input  logic [ADDR_WIDTH-1:0]   d_mem_addr_in,
    output  logic [DATA_WIDTH-1:0]   d_mux_mem_data_out,

// data memory interface
    input  logic [DATA_WIDTH-1:0]   d_mux_mem_data_in,
    input  logic [GPIO1_WIDTH-1:0]   d_mux_gpio1_data_in,
    input  logic [GPIO2_WIDTH-1:0]   d_mux_gpio2_data_in
);

always_comb begin
    if (d_mem_addr_in == GPIO1_ADDR) begin
        d_mux_mem_data_out[GPIO1_WIDTH-1:0] = d_mux_gpio1_data_in;
        d_mux_mem_data_out[DATA_WIDTH-1:GPIO1_WIDTH] = 0;
    end 
    else if (d_mem_addr_in == GPIO2_ADDR) begin
        d_mux_mem_data_out[GPIO2_WIDTH-1:0] = d_mux_gpio1_data_in;
        d_mux_mem_data_out[DATA_WIDTH-1:GPIO2_WIDTH] = 0;
    end 
    else begin
        d_mux_mem_data_out = d_mux_mem_data_in;
    end 
end
endmodule


