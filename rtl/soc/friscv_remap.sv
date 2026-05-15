// (c) FER, HPC Architecture and Application Research Center, All rights reserved
// License and version info is listed in friscv_pkg.sv

/*
 * This module implements address remapping specific for the FRISC-V reference design.
 * It handles remapping of the CLINT and UART peripherals to their "real" addresses on the PYNQ-Z2 AXI bus.
 */

`timescale 1ns / 1ps

import friscv_pkg::*;
import friscv_soc_pkg::*;

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
