// Copyright 2026 FER, HPC Architecture and Application Research Center
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
//
// Version info is listed in friscv_pkg.sv

/*
 * A debouncer module that takes a noisy input signal (i_sig) and produces a clean output signal (o_sig)
 * that only changes state after the input has been stable for a certain number of clock cycles.
 * The COUNT parameter determines how many clock cycles the input must be stable before the output changes.
 *
 * This module assumes that the input signal is already synchronized to the clock domain of clk.
 */

`timescale 1ns / 1ps

module debounce #(
    parameter COUNT = 2_000_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire i_sig,
    output reg  o_sig
);

    localparam CNT_W = $clog2(COUNT + 1);

    reg [CNT_W-1:0] r_cnt;
    reg             r_sig_sync0, r_sig_sync1;

    always @(posedge clk) begin
        if (!rst_n) begin
            r_sig_sync0 <= 1'b0;
            r_sig_sync1 <= 1'b0;
        end else begin
            r_sig_sync0 <= i_sig;
            r_sig_sync1 <= r_sig_sync0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_cnt  <= {CNT_W{1'b0}};
            o_sig  <= 1'b0;
        end else begin
            if (r_sig_sync1 != o_sig) begin
                if (r_cnt == COUNT - 1) begin
                    o_sig <= r_sig_sync1;
                    r_cnt <= {CNT_W{1'b0}};
                end else begin
                    r_cnt <= r_cnt + 1'b1;
                end
            end else begin
                r_cnt <= {CNT_W{1'b0}};
            end
        end
    end

endmodule
