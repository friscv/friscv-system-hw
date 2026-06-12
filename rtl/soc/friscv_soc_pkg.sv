// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Version info is listed in friscv_pkg.sv

/*
 * This package defines SoC-specific configuration parameters for the FRISC-V reference design
 * targeting the PYNQ-Z2 / Zynq platform. It includes address remapping configuration and
 * platform-specific address map entries.
 *
 * Modules that are part of the generic core should not import this package.
 */

`timescale 1ns / 1ps

package friscv_soc_pkg;

    import friscv_pkg::*;

    // Address space remapping
    localparam logic ENABLE_REMAP = 1;
    // Remaps standard CLINT address to a free address in the AXI map: 0x0200_0000 -> 0x4010_0000
    localparam logic ENABLE_REMAP_CLINT = 1;
    // Remaps UART: 0x1000_0000 -> 0x4060_0000
    localparam logic ENABLE_REMAP_UART = 1;

    // Platform address map
    // Must not be less than 0x00100000 — range reserved on Zynq for OCM
    localparam addr_t DRAM_START_AT   = 32'h00100000;
    localparam addr_t CLINT_REAL_BASE = 32'h40100000;  // Must match AXI address map
    localparam addr_t CLINT_PHY_BASE  = 32'h02000000;  // RISC-V convention
    localparam addr_t UART_REAL_BASE  = 32'h40600000;
    localparam addr_t UART_PHY_BASE   = 32'h10000000;  // RISC-V convention

endpackage
