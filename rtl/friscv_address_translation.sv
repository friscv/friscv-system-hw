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

module friscv_address_translation (
    input  logic  i_clk,
    input  logic  i_rstn,
    
    // Translation parameters
    input  addr_t i_base_addr,

    // Translated address
    input  addr_t i_cpu_addr,
    output addr_t o_dram_addr
);

addr_t r_base_addr;

// Translation logic:
// - Addresses below DRAM_BASE are MMIO, pass through unchanged
// - Addresses >= DRAM_BASE are DRAM, translate by: (cpu_addr - DRAM_BASE) + base_addr
assign o_dram_addr = (i_cpu_addr < DRAM_BASE) ? i_cpu_addr : (i_cpu_addr - DRAM_BASE) + r_base_addr;

always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
        r_base_addr <= i_base_addr;
    end
end

endmodule
