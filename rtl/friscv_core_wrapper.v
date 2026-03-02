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

module friscv_core_wrapper (
    input wire        i_clk,
    input wire        i_rstn,
    
    // Instruction Memory Interface
    output wire [31:0] i_mem_addr_out,
    input  wire [31:0] i_mem_data_in,
    output wire        i_mem_en_out,
    input  wire        i_mem_wait_in,

    // Data memory interface 
    output wire [31:0] d_mem_addr_out,
    output wire [31:0] d_mem_data_out,
    input  wire [31:0] d_mem_data_in,
    output wire        d_mem_en_out,
    output wire        d_mem_wr_out,
    output wire [2:0]  d_mem_size_out,
    input  wire        d_mem_wait_in
);

friscv_core core_inst (
    .i_clk          ( i_clk          ),
    .i_rstn         ( i_rstn         ),
    .i_mem_addr_out ( i_mem_addr_out ),
    .i_mem_data_in  ( i_mem_data_in  ),
    .i_mem_en_out   ( i_mem_en_out   ),
    .i_mem_wait_in  ( i_mem_wait_in  ),
    .d_mem_addr_out ( d_mem_addr_out ),
    .d_mem_data_out ( d_mem_data_out ),
    .d_mem_data_in  ( d_mem_data_in  ),
    .d_mem_en_out   ( d_mem_en_out   ),
    .d_mem_wr_out   ( d_mem_wr_out   ),
    .d_mem_size_out ( d_mem_size_out ),
    .d_mem_wait_in  ( d_mem_wait_in  )
);

endmodule
