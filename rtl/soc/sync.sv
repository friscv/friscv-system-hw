// (c) FER, HPC Architecture and Application Research Center, All rights reserved
// License and version info is listed in friscv_pkg.sv

/*
 * A synchronizer module that takes an asynchronous input signal (i_unsync) and produces a synchronized output signal (o_synced).
 * The synchronization is done using a two-stage flip-flop synchronizer to reduce the chance of metastability.
 * The WIDTH parameter allows for synchronizing multiple bits at once.
 *
 * Use this anywhere where you need to synchronize an asynchronous signal to the clock domain of i_clk.
 * Do not synchronize signals in other ways.
 */

`timescale 1ns / 1ps

module sync #(
    parameter WIDTH=1
) (
    input  logic             i_clk,
    input  logic [WIDTH-1:0] i_unsync,
    output logic [WIDTH-1:0] o_synced
);

logic [WIDTH-1:0] r_sync [2];

always_ff @(posedge i_clk) begin
    r_sync <= '{r_sync[0], i_unsync};
end

assign o_synced = r_sync[1];

endmodule
