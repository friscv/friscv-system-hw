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

module friscv_tlb #(
    parameter int ENTRY_COUNT = 32
) (
    input  logic        i_clk,
    input  logic        i_rstn,

    // Lookup
    input  logic [19:0] i_match_vpn,
    input  logic [8:0]  i_match_asid,
    output logic [19:0] o_ppn,
    output perm_t       o_perm,
    output logic        o_is_super,
    output logic        o_hit,

    // Fill
    input  logic [19:0] i_fill_vpn,
    input  logic [19:0] i_fill_ppn,
    input  logic [8:0]  i_fill_asid,
    input  perm_t       i_fill_perm,
    input  logic        i_fill_is_super,
    input  logic        i_fill_en,

    // Flush
    input  logic        i_flush,
    input  logic [19:0] i_flush_vpn,
    input  logic        i_flush_vpn_en,
    input  logic [8:0]  i_flush_asid,
    input  logic        i_flush_asid_en
);

typedef struct packed {
    logic [19:0] vpn;
    logic [19:0] ppn;
    logic [8:0]  asid;
    logic        is_super;
    perm_t       perm;
} tlb_entry_t;

tlb_entry_t r_tlb [ENTRY_COUNT];

logic [ENTRY_COUNT-1:0]         r_ref;       // Clock reference bits (set on fill, cleared on sweep)
logic [$clog2(ENTRY_COUNT)-1:0] r_clock_ptr; // Clock hand position

logic                           w_any_invalid;
logic [$clog2(ENTRY_COUNT)-1:0] w_invalid_slot, w_clock_victim, w_hit_idx;

// Initialize to prevent X in simulation
initial r_ref       = '0;
initial r_clock_ptr = '0;

genvar g;
generate
    for (g = 0; g < ENTRY_COUNT; g++) begin : tlb_init
        initial r_tlb[g] = '0;
    end
endgenerate

// ============================================================
// Fill and flush
// ============================================================

always_ff @(posedge i_clk) begin

    if (!i_rstn) begin

        for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_reset
            r_tlb[g] <= '0;
        end

        r_ref       <= '0;
        r_clock_ptr <= '0;

    end else begin

        // Set ref bit on hit so recently-used entries get a second chance
        if (o_hit)
            r_ref[w_hit_idx] <= 1'b1;

        if (i_flush) begin  // Global flush enable, has priority

            if (i_flush_vpn_en && i_flush_asid_en) begin  // sfence.vma rs1, rs2: VPN+ASID match, not global

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_va_asid
                    logic vpn_match;
                    vpn_match = (!r_tlb[g].is_super && i_flush_vpn == r_tlb[g].vpn) ||
                                ( r_tlb[g].is_super && i_flush_vpn[19:10] == r_tlb[g].vpn[19:10]);
                    if (vpn_match && r_tlb[g].asid == i_flush_asid && !r_tlb[g].perm.g)
                        r_tlb[g] <= '0;
                end

            end else if (i_flush_vpn_en) begin  // sfence.vma rs1, x0: VPN match, all ASIDs and global

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_va
                    logic vpn_match;
                    vpn_match = (!r_tlb[g].is_super && i_flush_vpn == r_tlb[g].vpn) ||
                                ( r_tlb[g].is_super && i_flush_vpn[19:10] == r_tlb[g].vpn[19:10]);
                    if (vpn_match)
                        r_tlb[g] <= '0;
                end

            end else if (i_flush_asid_en) begin  // sfence.vma x0, rs2: ASID match, not global

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_asid
                    if (r_tlb[g].asid == i_flush_asid && !r_tlb[g].perm.g)
                        r_tlb[g] <= '0;
                end

            end else begin  // sfence.vma x0, x0: flush all

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_all
                    r_tlb[g] <= '0;
                end

            end

        end else if (i_fill_en) begin  // Insert or replace with new entry

            logic [$clog2(ENTRY_COUNT)-1:0] victim;
            victim = w_any_invalid ? w_invalid_slot : w_clock_victim;

            r_tlb[victim].vpn      <= i_fill_is_super ? {i_fill_vpn[19:10], 10'b0} : i_fill_vpn;
            r_tlb[victim].ppn      <= i_fill_ppn;
            r_tlb[victim].asid     <= i_fill_asid;
            r_tlb[victim].is_super <= i_fill_is_super;
            r_tlb[victim].perm     <= i_fill_perm;
            r_ref[victim]          <= 1'b1;  // Mark newly added entry as recently used

            if (!w_any_invalid) begin
                // Clear ref bits of all entries the clock hand swept past on its way to the victim
                // Entries at distance 0 to dist_victim-1 from r_clock_ptr are cleared (not recently used)
                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_sweep_ref
                    // 5-bit unsigned circular distances from clock_ptr to g and to victim
                    if (($clog2(ENTRY_COUNT))'(g) - r_clock_ptr < w_clock_victim - r_clock_ptr)
                        r_ref[g] <= 1'b0;
                end
                r_clock_ptr <= (w_clock_victim == ($clog2(ENTRY_COUNT))'(ENTRY_COUNT-1)) ? '0 : w_clock_victim + 1;
            end

        end

    end
end

// ============================================================
// Victim decision
// ============================================================

always_comb begin : tlb_detect_invalid_slot
    w_any_invalid = 1'b0;
    w_invalid_slot = '0;
    for (int g = 0; g < ENTRY_COUNT; g++) begin
        if (!r_tlb[g].perm.v && !w_any_invalid) begin
            w_any_invalid = 1'b1;
            w_invalid_slot = g[$clog2(ENTRY_COUNT)-1:0];
        end
    end
end

// Clock victim - first entry with r_ref=0 starting from r_clock_ptr, circular.
// If all refs are 1, defaults to r_clock_ptr.
always_comb begin : tlb_detect_clock_victim
    w_clock_victim = r_clock_ptr;
    for (int i = ENTRY_COUNT-1; i >= 0; i--) begin
        if (!r_ref[r_clock_ptr + i[$clog2(ENTRY_COUNT)-1:0]])
            w_clock_victim = r_clock_ptr + i[$clog2(ENTRY_COUNT)-1:0];
    end
end

// ============================================================
// Lookup
// ============================================================

always_comb begin
    o_ppn      = '0;
    o_perm     = '0;
    o_is_super = 1'b0;
    o_hit      = 1'b0;
    w_hit_idx  = '0;

    for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_lookup
        logic vpn_match;
        vpn_match = (!r_tlb[g].is_super && i_match_vpn == r_tlb[g].vpn) ||
                    ( r_tlb[g].is_super && i_match_vpn[19:10] == r_tlb[g].vpn[19:10]);

        if (r_tlb[g].perm.v && (r_tlb[g].perm.g || i_match_asid == r_tlb[g].asid) && vpn_match) begin
            o_ppn      = r_tlb[g].is_super ? {r_tlb[g].ppn[19:10], i_match_vpn[9:0]} : r_tlb[g].ppn;
            o_perm     = r_tlb[g].perm;
            o_is_super = r_tlb[g].is_super;
            o_hit      = 1'b1;
            w_hit_idx  = g[$clog2(ENTRY_COUNT)-1:0];
        end
    end
end

endmodule
