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

module friscv_cpu_subsystem_core (
    input  logic         i_clk,
    input  logic         i_rstn,
    output logic         o_end,

    input  logic         i_msip,
    input  logic         i_mtip,
    input  logic         i_meip,
    friscv_mem_if.master mem_if
);

mem_width_e  w_size;
logic [31:0] w_phy_addr;
logic [31:0] w_dram_addr;
logic [31:0] w_wdata;
logic [31:0] w_rdata;
rw_cmd_e     w_rw;
logic        w_wait;
logic        w_burst_en;
logic        w_beat_valid;

// The error line is part of the protocol, but it is intentionally ignored for now
logic w_unused_mem_err;
assign w_unused_mem_err = mem_if.err;

// Address translation
always_comb begin
    if (ENABLE_REMAP_CLINT && w_phy_addr[31:16] == CLINT_PHY_BASE[31:16] && w_phy_addr[15:0] <= 16'hBFFF) begin
        w_dram_addr = {CLINT_REAL_BASE[31:16], w_phy_addr[15:0]};
    end else if (DRAM_BASE == 32'h8000_0000) begin
        w_dram_addr = w_phy_addr[31] ? {1'b0, w_phy_addr[30:0]} + DRAM_START_AT : w_phy_addr;
    end else if (DRAM_BASE == 32'h0) begin
        w_dram_addr = w_phy_addr + DRAM_START_AT;
    end else begin
        w_dram_addr = (w_phy_addr < DRAM_BASE) ? w_phy_addr : (w_phy_addr - DRAM_BASE) + DRAM_START_AT;
    end
end

// Metastability protection for reset
logic [1:0]  r_rstn_sync = 2'b00;

always_ff @(posedge i_clk) begin
    r_rstn_sync <= {r_rstn_sync[0], i_rstn};
end

friscv_core_complex #(
    .HART_ID(0)
) cc_0 (
    .i_clk        ( i_clk          ),
    .i_rstn       ( r_rstn_sync[1] ),
    .o_end        ( o_end          ),
    .i_msip       ( i_msip         ),
    .i_mtip       ( i_mtip         ),
    .i_meip       ( i_meip         ),
    .o_mem_size   ( w_size         ),
    .o_mem_addr   ( w_phy_addr     ),
    .o_mem_wdata  ( w_wdata        ),
    .i_mem_rdata  ( w_rdata        ),
    .o_mem_rw     ( w_rw           ),
    .i_mem_wait   ( w_wait         ),
    .o_burst_en   ( w_burst_en     ),
    .i_beat_valid ( w_beat_valid   )
);

// External memory reset sequencer
// Wait for transactions to complete before resetting the bus adapter.
logic r_mem_reset_req;
logic r_mem_in_reset = 1'b1;  // Start in reset

always_ff @(posedge i_clk or negedge r_rstn_sync[1]) begin
    if (!r_rstn_sync[1]) begin
        r_mem_reset_req <= 1'b1;  // Request reset when button pressed
    end else begin
        r_mem_reset_req <= 1'b0;  // Clear request when button released
    end
end

always_ff @(posedge i_clk) begin
    if (r_mem_reset_req && !w_wait) begin
        // Once transaction completes and reset is requested, assert reset
        r_mem_in_reset <= 1'b1;
    end else if (!r_mem_reset_req) begin
        // Only release reset when external reset is released
        r_mem_in_reset <= 1'b0;
    end
end

assign mem_if.size      = w_size;
assign mem_if.addr      = w_dram_addr;
assign mem_if.wdata     = w_wdata;
assign mem_if.rw        = w_rw;
assign mem_if.burst_en  = w_burst_en;
assign mem_if.rstn      = !r_mem_in_reset;

assign w_rdata          = mem_if.rdata;
assign w_wait           = mem_if.wait_req || r_mem_in_reset;
assign w_beat_valid     = mem_if.beat_valid;

endmodule
