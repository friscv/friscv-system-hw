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

module friscv_ptw (
    input  logic        i_clk,
    input  logic        i_rstn,

    // Translation control
    input  satp_t       i_satp,

    // Walk trigger
    input  logic        i_itlb_miss,
    input  logic        i_dtlb_miss,
    input  addr_t       i_req_va,
    input  logic        i_req_is_write,

    // External bus
    output addr_t       o_walk_addr,
    output logic        o_walk_en,
    input  data_t       i_walk_rdata,
    input  logic        i_walk_wait,

    // Arbiter stall
    output logic        o_stall,

    // TLB fill
    output logic [19:0] o_fill_vpn,
    output logic [19:0] o_fill_ppn,
    output logic [8:0]  o_fill_asid,
    output perm_t       o_fill_perm,
    output logic        o_fill_is_super,
    output logic        o_fill_itlb_en,
    output logic        o_fill_dtlb_en,

    // Page fault outputs
    output logic        o_inst_fault,
    output logic        o_load_fault,
    output logic        o_store_fault,
    output addr_t       o_fault_addr
);

assign o_walk_addr     = '0;
assign o_walk_en       = 1'b0;
assign o_stall         = 1'b0;
assign o_fill_vpn      = '0;
assign o_fill_ppn      = '0;
assign o_fill_asid     = '0;
assign o_fill_perm     = '0;
assign o_fill_is_super = 1'b0;
assign o_fill_itlb_en  = 1'b0;
assign o_fill_dtlb_en  = 1'b0;
assign o_inst_fault    = 1'b0;
assign o_load_fault    = 1'b0;
assign o_store_fault   = 1'b0;
assign o_fault_addr    = '0;

endmodule
