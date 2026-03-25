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

// Lookup lines
logic [19:0] w_itlb_ppn, w_dtlb_ppn;
logic [7:0]  w_itlb_perm, w_dtlb_perm;
logic        w_itlb_super, w_dtlb_super;
logic        w_itlb_hit, w_dtlb_hit;

// Fill lines
logic [19:0] w_fill_vpn, w_fill_ppn;
logic [8:0]  w_fill_asid;
logic [7:0]  w_fill_perm;
logic        w_fill_super;
logic        w_fill_itlb, w_fill_dtlb;

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
    .i_fill_vpn      ( w_fill_vpn   ),
    .i_fill_ppn      ( w_fill_ppn   ),
    .i_fill_asid     ( w_fill_asid  ),
    .i_fill_perm     ( w_fill_perm  ),
    .i_fill_is_super ( w_fill_super ),
    .i_fill_en       ( w_fill_itlb  ),

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
    .i_fill_vpn      ( w_fill_vpn   ),
    .i_fill_ppn      ( w_fill_ppn   ),
    .i_fill_asid     ( w_fill_asid  ),
    .i_fill_perm     ( w_fill_perm  ),
    .i_fill_is_super ( w_fill_super ),
    .i_fill_en       ( w_fill_dtlb  ),

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

// Granted request lines
addr_t      w_grant_addr;
mem_width_e w_grant_size;
data_t      w_grant_wdata;
rw_cmd_e    w_grant_rw;
logic       w_stall;
amo_op_e    w_grant_amo;
logic       w_grant_inst;

friscv_l1_arbiter l1_arbiter (
    .i_clk        ( i_clk         ),
    .i_rstn       ( i_rstn        ),

    .i_inst_addr  ( i_inst_addr   ),
    .o_inst_data  ( o_inst_data   ),
    .i_inst_en    ( i_inst_en     ),
    .o_inst_wait  ( o_inst_wait   ),

    .i_data_addr  ( i_data_addr   ),
    .i_data_size  ( i_data_size   ),
    .i_data_wdata ( i_data_wdata  ),
    .o_data_rdata ( o_data_rdata  ),
    .i_data_en    ( i_data_en     ),
    .i_data_wr    ( i_data_wr     ),
    .o_data_wait  ( o_data_wait   ),
    .i_amo_op     ( i_amo_op      ),

    .o_mem_addr   ( w_grant_addr  ),
    .o_mem_size   ( w_grant_size  ),
    .o_mem_wdata  ( w_grant_wdata ),
    .i_mem_rdata  ( i_mem_rdata   ),
    .o_mem_rw     ( w_grant_rw    ),
    .i_mem_wait   ( w_stall       ),
    .o_amo_op     ( w_grant_amo   ),
    .o_grant_inst ( w_grant_inst  )
);

// ============================================================
// Paging layer
// ============================================================

// Paging active when satp.MODE != 0 and not in M-mode
logic w_paging_en;
assign w_paging_en = (|i_satp.mode) && (i_mode != M_MODE);

// Arbiter is in a grant state when it drives a non-idle command
logic w_grant_active;
assign w_grant_active = (w_grant_rw != RW_IDLE);

// TLB miss - arbiter has granted the request, paging is on, and the TLB did not hit
logic w_itlb_miss, w_dtlb_miss;
assign w_itlb_miss = w_grant_active &&  w_grant_inst && !w_itlb_hit && w_paging_en;
assign w_dtlb_miss = w_grant_active && !w_grant_inst && !w_dtlb_hit && w_paging_en;

logic [19:0] w_grant_vpn;
assign w_grant_vpn = w_grant_addr[31:12];

logic w_grant_wr;
assign w_grant_wr = w_grant_rw == RW_WRITE;

// PTW memory interface
addr_t w_walk_addr;
logic  w_walk_en;
data_t w_walk_rdata;
logic  w_walk_wait;

friscv_ptw ptw (
    .i_clk           ( i_clk         ),
    .i_rstn          ( i_rstn        ),

    // Translation control
    .i_satp          ( i_satp        ),
    .i_mode          ( i_mode        ),
    .i_sum           ( i_sum         ),
    .i_mxr           ( i_mxr         ),

    // Walk trigger
    .i_itlb_miss     ( w_itlb_miss   ),
    .i_dtlb_miss     ( w_dtlb_miss   ),
    .i_req_vpn       ( w_grant_vpn   ),
    .i_req_is_write  ( w_grant_wr    ),

    // External bus
    .o_walk_addr     ( w_walk_addr   ),
    .o_walk_en       ( w_walk_en     ),
    .i_walk_rdata    ( w_walk_rdata  ),
    .i_walk_wait     ( w_walk_wait   ),

    // Arbiter stall
    .o_stall         ( w_stall       ),

    // TLB fill
    .o_fill_vpn      ( w_fill_vpn    ),
    .o_fill_ppn      ( w_fill_ppn    ),
    .o_fill_asid     ( w_fill_asid   ),
    .o_fill_perm     ( w_fill_perm   ),
    .o_fill_is_super ( w_fill_super  ),
    .o_fill_itlb_en  ( w_fill_itlb   ),
    .o_fill_dtlb_en  ( w_fill_dtlb   ),

    // Page fault outputs
    .o_inst_fault    ( o_inst_fault  ),
    .o_load_fault    ( o_load_fault  ),
    .o_store_fault   ( o_store_fault ),
    .o_fault_addr    ( o_fault_addr  )
);

// ============================================================
// PTW / arbiter bus mux
// ============================================================

// Physical address for the granted request
logic [19:0] w_granted_ppn;
assign w_granted_ppn = w_grant_inst ? w_itlb_ppn : w_dtlb_ppn;

// PTW walk signals routed directly to/from external memory
assign w_walk_rdata = i_mem_rdata;
assign w_walk_wait  = i_mem_wait;

// When PTW is walking it owns the bus
assign w_stall = w_walk_en ? 1'b1 : i_mem_wait;

assign o_mem_addr = w_walk_en ? w_walk_addr                            :
                    w_paging_en ? {w_granted_ppn, w_grant_addr[11:0]}  :
                    w_grant_addr;

assign o_mem_rw    = w_walk_en ? RW_READ    : w_grant_rw;
assign o_mem_size  = w_walk_en ? WIDTH_I32  : w_grant_size;
assign o_mem_wdata = w_walk_en ? '0         : w_grant_wdata;
assign o_amo_op    = w_walk_en ? AMO_NONE   : w_grant_amo;

endmodule
