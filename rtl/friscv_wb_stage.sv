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
/*OLD MK*/
`include "friscv_pkg.sv"

module friscv_wb_stage(

// inputs from MEM stage
    input logic [DATA_WIDTH-1:0]    rd_data_in,
    input logic [REG_SEL_WIDTH-1:0] rd_sel_in,

 // outputs to ID stage
    output logic [DATA_WIDTH-1:0]   rd_data_out,
    output logic [REG_SEL_WIDTH-1:0] rd_sel_out
);

assign rd_data_out = rd_data_in;
assign rd_sel_out = rd_sel_in;

endmodule
