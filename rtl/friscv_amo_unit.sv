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

module friscv_amo_unit (
    input  logic    i_clk,
    input  logic    i_rstn,

    // Requested atomic operation
    input  amo_op_t i_amo_op,

    // Core interface
    input  data_t   i_rs2_val,
    output data_t   o_core_load_data,
    output logic    o_core_wait,

    // External interface
    input  logic    i_mem_wait,
    output rw_cmd_t o_mem_rw,
    input  data_t   i_mem_load_data,
    output data_t   o_mem_store_data
);

endmodule
