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
 * This wrapper was used in a legacy debugging system, and is no longer used in the current design.
 * Do not change or use this module.
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
