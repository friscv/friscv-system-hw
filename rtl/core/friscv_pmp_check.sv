// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Version info is listed in friscv_pkg.sv

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_pmp_check (
    input  addr_t      i_pa,
    input  logic       i_access_r,
    input  logic       i_access_w,
    input  logic       i_access_x,
    input  logic       i_mpp,
    input  mode_e      i_mode,
    input  pmp_table_t i_pmp_table,
    output logic       o_allow,
    output logic       o_fault
);

endmodule
