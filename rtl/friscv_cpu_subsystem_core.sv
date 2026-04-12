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

    input  mtime_t       i_mtime,

    friscv_mem_if.master mem_if
);

// Metastability protection for reset
logic w_rstn_sync;
sync #(.WIDTH(1)) rstn_sync (
    .i_clk    ( i_clk       ),
    .i_unsync ( i_rstn      ),
    .o_synced ( w_rstn_sync )
);

mem_width_e w_size;
addr_t      w_phy_addr;
addr_t      w_dram_addr;
data_t      w_wdata;
data_t      w_rdata;
rw_cmd_e    w_rw;
logic       w_wait;
logic       w_burst_en;
logic       w_beat_valid;

// The error line is part of the protocol, but it is intentionally ignored for now
logic w_unused_mem_err;
assign w_unused_mem_err = mem_if.err;

// Address space remapping
if (ENABLE_REMAP) begin
    friscv_remap remapper (
        .i_addr ( w_phy_addr  ),
        .o_addr ( w_dram_addr )
    );
end else begin
    assign w_dram_addr = w_phy_addr;
end

friscv_core_complex #(
    .HART_ID(0)
) cc_0 (
    .i_clk        ( i_clk        ),
    .i_rstn       ( w_rstn_sync  ),
    .o_end        ( o_end        ),
    .i_msip       ( i_msip       ),
    .i_mtip       ( i_mtip       ),
    .i_meip       ( i_meip       ),
    .i_mtime      ( i_mtime      ),
    .o_mem_size   ( w_size       ),
    .o_mem_addr   ( w_phy_addr   ),
    .o_mem_wdata  ( w_wdata      ),
    .i_mem_rdata  ( w_rdata      ),
    .o_mem_rw     ( w_rw         ),
    .i_mem_wait   ( w_wait       ),
    .o_burst_en   ( w_burst_en   ),
    .i_beat_valid ( w_beat_valid )
);

// External memory reset sequencer
// Wait for transactions to complete before resetting the bus adapter.
logic r_mem_reset_req;
logic r_mem_in_reset = 1'b1;  // Start in reset

always_ff @(posedge i_clk or negedge w_rstn_sync) begin
    if (!w_rstn_sync) begin
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
