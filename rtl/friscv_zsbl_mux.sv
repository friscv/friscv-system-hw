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

module friscv_zsbl_mux (
    input  addr_t i_addr,
    input  logic  i_en,
    input  inst_t i_zsbl_data,
    input  inst_t i_mem_data,
    output inst_t o_data,
    output logic  o_mem_en
);

logic w_addr_is_zsbl;
assign w_addr_is_zsbl = (i_addr >= RESET_VEC && i_addr < RESET_VEC + ZSBL_ROM_SIZE);
assign o_data = w_addr_is_zsbl ? i_zsbl_data : i_mem_data;
assign o_mem_en = i_en && !w_addr_is_zsbl;

endmodule
