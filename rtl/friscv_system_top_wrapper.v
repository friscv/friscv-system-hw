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
    input  wire        i_clk,
    input  wire        i_extern_rstn,
    input  wire        i_pushbtn_rst,
    output wire        o_end,

    // Memory Interface
    output wire [2:0]  o_mem_size,
    output wire [31:0] o_mem_addr,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    output wire [1:0]  o_mem_rw,
    input  wire        i_mem_wait
);

    friscv_system_top friscv_system_top_0(
        .i_clk         (i_clk),
        .i_extern_rstn (i_extern_rstn),
        .i_pushbtn_rst (i_pushbtn_rst),
        .o_end         (o_end),
        .o_mem_size    (o_mem_size),
        .o_mem_addr    (o_mem_addr),
        .o_mem_wdata   (o_mem_wdata),
        .i_mem_rdata   (i_mem_rdata),
        .o_mem_rw      (o_mem_rw),
        .i_mem_wait    (i_mem_wait)
    );

endmodule