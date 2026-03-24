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
    localparam int ENTRY_COUNT = 32
) (
    input  logic        i_clk,
    input  logic        i_rstn,

    // Lookup
    input  logic [19:0] i_match_va,
    input  logic [8:0]  i_match_asid,
    output logic [19:0] o_pa,
    output logic [7:0]  o_perm,  // {D,A,G,U,X,W,R,V}
    output logic        o_is_super,
    output logic        o_hit,

    // Fill
    input  logic [19:0] i_new_va,
    input  logic [19:0] i_new_pa,
    input  logic [8:0]  i_new_asid,
    input  logic [7:0]  i_new_perm,
    input  logic        i_new_is_super,
    input  logic        i_new_en,

    // Flush
    input  logic        i_flush,
    input  logic [19:0] i_flush_va,
    input  logic        i_flush_va_en,
    input  logic [8:0]  i_flush_asid,
    input  logic        i_flush_asid_en
);

typedef struct packed {
    logic d, a, g, u, x, w, r, v;
} page_perm_t;

typedef struct packed {
    logic [19:0] va;
    logic [19:0] pa;
    logic [8:0]  asid;
    logic        is_super;
    page_perm_t  perm;
} tlb_entry_t;

tlb_entry_t r_tlb [ENTRY_COUNT];

logic [ENTRY_COUNT-1:0]         r_ref;       // Clock reference bits (set on fill, cleared on sweep)
logic [$clog2(ENTRY_COUNT)-1:0] r_clock_ptr; // Clock hand position

logic                           w_any_invalid;
logic [$clog2(ENTRY_COUNT)-1:0] w_invalid_slot, w_clock_victim;

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

        if (i_flush) begin  // Global flush enable, has priority

            if (i_flush_va_en && i_flush_asid_en) begin  // sfence.vma rs1, rs2: VA+ASID match, not global

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_va_asid
                    logic va_match;
                    va_match = (!r_tlb[g].is_super && i_flush_va == r_tlb[g].va) ||
                               ( r_tlb[g].is_super && i_flush_va[19:10] == r_tlb[g].va[19:10]);
                    if (va_match && r_tlb[g].asid == i_flush_asid && !r_tlb[g].perm.g)
                        r_tlb[g] <= '0;
                end

            end else if (i_flush_va_en) begin  // sfence.vma rs1, x0: VA match, all ASIDs and global

                for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_flush_va
                    logic va_match;
                    va_match = (!r_tlb[g].is_super && i_flush_va == r_tlb[g].va) ||
                               ( r_tlb[g].is_super && i_flush_va[19:10] == r_tlb[g].va[19:10]);
                    if (va_match)
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

        end else if (i_new_en) begin  // Insert or replace with new entry

            logic [$clog2(ENTRY_COUNT)-1:0] victim;
            victim = w_any_invalid ? w_invalid_slot : w_clock_victim;

            r_tlb[victim].va       <= i_new_is_super ? {i_new_va[19:10], 10'b0} : i_new_va;
            r_tlb[victim].pa       <= i_new_pa;
            r_tlb[victim].asid     <= i_new_asid;
            r_tlb[victim].is_super <= i_new_is_super;
            r_tlb[victim].perm     <= i_new_perm;
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
    o_pa       = '0;
    o_perm     = '0;
    o_is_super = 1'b0;
    o_hit      = 1'b0;

    for (int g = 0; g < ENTRY_COUNT; g++) begin : tlb_lookup
        logic va_match;
        va_match = (!r_tlb[g].is_super && i_match_va == r_tlb[g].va) ||
                   ( r_tlb[g].is_super && i_match_va[19:10] == r_tlb[g].va[19:10]);

        if (r_tlb[g].perm.v && (r_tlb[g].perm.g || i_match_asid == r_tlb[g].asid) && va_match) begin
            o_pa       = r_tlb[g].is_super ? {r_tlb[g].pa[19:10], i_match_va[9:0]} : r_tlb[g].pa;
            o_perm     = r_tlb[g].perm;
            o_is_super = r_tlb[g].is_super;
            o_hit      = 1'b1;
        end
    end
end

endmodule
