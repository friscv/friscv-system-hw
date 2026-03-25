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

module friscv_mmu (
    input  logic       i_clk,
    input  logic       i_rstn,

    // Instruction Memory Interface (from core IF stage)
    input  addr_t      i_inst_addr,
    output data_t      o_inst_data,
    input  logic       i_inst_en,
    output logic       o_inst_wait,

    // Data Memory Interface (from core MEM stage)
    input  addr_t      i_data_addr,
    input  mem_width_e i_data_size,
    input  data_t      i_data_wdata,
    output data_t      o_data_rdata,
    input  logic       i_data_en,
    input  logic       i_data_wr,
    output logic       o_data_wait,
    input  amo_op_e    i_amo_op,

    // External Memory Interface
    output addr_t      o_mem_addr,
    output mem_width_e o_mem_size,
    output data_t      o_mem_wdata,
    input  data_t      i_mem_rdata,
    output rw_cmd_e    o_mem_rw,
    input  logic       i_mem_wait,
    output amo_op_e    o_amo_op,

    // Protection and Translation Control (from core ID stage CSRs)
    input  satp_t      i_satp,
    input  logic       i_sum,
    input  logic       i_mxr,
    input  mode_e      i_mode,
    input  logic       i_flush_tlb,

    // Page fault signals
    output logic       o_inst_fault,
    output logic       o_load_fault,
    output logic       o_store_fault,
    output addr_t      o_fault_addr
);

logic [19:0] w_inst_vpn, w_data_vpn;
assign w_inst_vpn = i_inst_addr[31:12];
assign w_data_vpn = i_data_addr[31:12];

// ============================================================
// TLB layer
// ============================================================

logic [19:0] w_itlb_ppn, w_dtlb_ppn;
logic [7:0]  w_itlb_perm, w_dtlb_perm;
logic        w_itlb_super, w_dtlb_super;
logic        w_itlb_hit, w_dtlb_hit;

friscv_tlb #(
    .ENTRY_COUNT(TLB_ENTRIES)
) itlb (
    .i_clk           ( i_clk        ),
    .i_rstn          ( i_rstn       ),

    // Lookup
    .i_match_vpn     ( w_inst_vpn   ),
    .i_match_asid    ( i_satp.asid  ),
    .o_ppn           ( w_itlb_ppn   ),
    .o_perm          ( w_itlb_perm  ),
    .o_is_super      ( w_itlb_super ),
    .o_hit           ( w_itlb_hit   ),

    // Fill
    .i_new_vpn       ( '0           ),
    .i_new_ppn       ( '0           ),
    .i_new_asid      ( '0           ),
    .i_new_perm      ( '0           ),
    .i_new_is_super  ( 1'b0         ),
    .i_new_en        ( 1'b0         ),

    // Flush
    .i_flush         ( i_flush_tlb  ),
    .i_flush_vpn     ( '0           ),
    .i_flush_vpn_en  ( 1'b0         ),
    .i_flush_asid    ( '0           ),
    .i_flush_asid_en ( 1'b0         )
);

friscv_tlb #(
    .ENTRY_COUNT(TLB_ENTRIES)
) dtlb (
    .i_clk           ( i_clk        ),
    .i_rstn          ( i_rstn       ),

    // Lookup
    .i_match_vpn     ( w_data_vpn   ),
    .i_match_asid    ( i_satp.asid  ),
    .o_ppn           ( w_dtlb_ppn   ),
    .o_perm          ( w_dtlb_perm  ),
    .o_is_super      ( w_dtlb_super ),
    .o_hit           ( w_dtlb_hit   ),

    // Fill
    .i_new_vpn       ( '0           ),
    .i_new_ppn       ( '0           ),
    .i_new_asid      ( '0           ),
    .i_new_perm      ( '0           ),
    .i_new_is_super  ( 1'b0         ),
    .i_new_en        ( 1'b0         ),

    // Flush
    .i_flush         ( i_flush_tlb  ),
    .i_flush_vpn     ( '0           ),
    .i_flush_vpn_en  ( 1'b0         ),
    .i_flush_asid    ( '0           ),
    .i_flush_asid_en ( 1'b0         )
);

// ============================================================
// Arbitration layer
// ============================================================

friscv_l1_arbiter l1_arbiter (
    .i_clk        ( i_clk        ),
    .i_rstn       ( i_rstn       ),

    .i_inst_addr  ( i_inst_addr  ),
    .o_inst_data  ( o_inst_data  ),
    .i_inst_en    ( i_inst_en    ),
    .o_inst_wait  ( o_inst_wait  ),

    .i_data_addr  ( i_data_addr  ),
    .i_data_size  ( i_data_size  ),
    .i_data_wdata ( i_data_wdata ),
    .o_data_rdata ( o_data_rdata ),
    .i_data_en    ( i_data_en    ),
    .i_data_wr    ( i_data_wr    ),
    .o_data_wait  ( o_data_wait  ),
    .i_amo_op     ( i_amo_op     ),

    .o_mem_addr   ( o_mem_addr   ),
    .o_mem_size   ( o_mem_size   ),
    .o_mem_wdata  ( o_mem_wdata  ),
    .i_mem_rdata  ( i_mem_rdata  ),
    .o_mem_rw     ( o_mem_rw     ),
    .i_mem_wait   ( i_mem_wait   ),
    .o_amo_op     ( o_amo_op     )
);

// ============================================================
// Paging layer
// ============================================================

// TODO remove when implemented
assign o_inst_fault  = 1'b0;
assign o_load_fault  = 1'b0;
assign o_store_fault = 1'b0;
assign o_fault_addr  = '0;

endmodule
