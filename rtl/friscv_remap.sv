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

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_remap (
    input  addr_t i_addr,
    output addr_t o_addr
);

always_comb begin
    if (ENABLE_REMAP_CLINT && i_addr[31:16] == CLINT_PHY_BASE[31:16] && i_addr[15:0] <= 16'hBFFF)
        o_addr = {CLINT_REAL_BASE[31:16], i_addr[15:0]};
    else if (ENABLE_REMAP_UART && i_addr[31:16] == UART_PHY_BASE[31:16] && i_addr[15:0] <= 16'hBFFF)
        o_addr = {UART_REAL_BASE[31:16], i_addr[15:0]};
    else if (DRAM_BASE == 32'h8000_0000)
        o_addr = i_addr[31] ? {1'b0, i_addr[30:0]} + DRAM_START_AT : i_addr;
    else if (DRAM_BASE == 32'h0)
        o_addr = i_addr + DRAM_START_AT;
    else
        o_addr = (i_addr < DRAM_BASE) ? i_addr : (i_addr - DRAM_BASE) + DRAM_START_AT;
end

endmodule
