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
    output vpn_t        o_fill_vpn,
    output ppn_t        o_fill_ppn,
    output asid_t       o_fill_asid,
    output perm_t       o_fill_perm,
    output pte_level_t  o_fill_level,
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
assign o_fill_level    = '0;
assign o_fill_itlb_en  = 1'b0;
assign o_fill_dtlb_en  = 1'b0;
assign o_inst_fault    = 1'b0;
assign o_load_fault    = 1'b0;
assign o_store_fault   = 1'b0;
assign o_fault_addr    = '0;

logic [2:0] r_level;      // Current walk level
logic [2:0] w_max_level;  // Walk depth

always_comb begin
    case (satp_mode_e'(i_satp.mode))
        SATP_SV32: w_max_level = 3'd1;  // Levels 1,0
        SATP_SV39: w_max_level = 3'd2;  // Levels 2,1,0
        SATP_SV48: w_max_level = 3'd3;
        SATP_SV57: w_max_level = 3'd4;
        default:   w_max_level = 3'd1;
    endcase
end

endmodule
