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

module friscv_address_translation(
    input  logic        i_clk,
    input  logic        i_rstn,
    
    // Translation parameters
    input  logic [31:0] i_base_addr,

    // Translated address
    input  logic [31:0] i_cpu_addr,
    output logic [31:0] o_dram_addr
);

logic r_base_addr;
assign o_dram_addr = (i_cpu_addr < i_base_addr) ? i_cpu_addr : i_cpu_addr - i_base_addr;

always_ff @(posedge i_clk) begin
    if (!i_rstn)
        r_base_addr <= i_base_addr;
end

endmodule
