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

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_divider (
    input  logic  clk_in,
    input  logic  rst_n_in,
    input  logic  flush_in,
    input  logic  division_detected_in,
    input  logic  signed_division_in,
    input  data_t divisor,
    input  data_t dividend,
    output data_t quotient,
    output data_t remainder,
    output logic  active_out,
    output logic  done_out
);

    typedef enum logic [1:0] {IDLE, ACTIVE, DONE} state_e;

    state_e      current_state;
    logic [32:0] A;
    data_t       M, Q;
    logic [5:0]  Counter;
    logic        quotient_sign, remainder_sign, edge_case;

    // Next-state combinatorial signals
    state_e      next_state;
    logic [32:0] next_A;
    data_t       next_M, next_Q;
    logic [5:0]  next_Counter;
    logic        next_quotient_sign, next_remainder_sign, next_edge_case;
    data_t       next_quotient, next_remainder;
    logic        next_active, next_done;

    // Intermediate computation for ACTIVE state
    logic [32:0] shifted_A;
    data_t       shifted_Q;
    logic [32:0] trial_A;
    data_t       trial_Q;

    // Intermediate computation for DONE state
    logic [32:0] final_A;

    always_comb begin
        // Default: hold current values
        next_state          = current_state;
        next_A              = A;
        next_M              = M;
        next_Q              = Q;
        next_Counter        = Counter;
        next_quotient_sign  = quotient_sign;
        next_remainder_sign = remainder_sign;
        next_edge_case      = edge_case;
        next_quotient       = quotient;
        next_remainder      = remainder;
        next_active         = active_out;
        next_done           = done_out;

        // ACTIVE state intermediates
        {shifted_A, shifted_Q} = {A, Q} << 1;
        trial_A    = (A[32] == 1'b0) ? (shifted_A - {1'b0, M}) : (shifted_A + {1'b0, M});
        trial_Q    = shifted_Q;
        trial_Q[0] = (trial_A[32] == 1'b0) ? 1'b1 : 1'b0;

        // DONE state intermediate
        final_A = A[32] ? (A + {1'b0, M}) : A;

        if (flush_in) begin
            next_state  = IDLE;
            next_active = 1'b0;
            next_done   = 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    next_done = 1'b0;
                    if (division_detected_in) begin
                        next_A       = 33'h0;
                        next_Counter = 6'd32;

                        if (divisor == 32'd0) begin
                            next_remainder = dividend;
                            next_quotient  = 32'hFFFFFFFF;
                            next_edge_case = 1'b1;
                            next_state     = DONE;
                        end else if (signed_division_in && dividend == 32'h80000000 && divisor == 32'hFFFFFFFF) begin
                            next_remainder = 32'd0;
                            next_quotient  = 32'h80000000;
                            next_edge_case = 1'b1;
                            next_state     = DONE;
                        end else begin
                            next_edge_case = 1'b0;
                            next_active    = 1'b1;
                            if (signed_division_in) begin
                                next_quotient_sign  = dividend[31] ^ divisor[31];
                                next_remainder_sign = dividend[31];
                                next_Q = dividend[31] ? (~dividend + 1'b1) : dividend;
                                next_M = divisor[31]  ? (~divisor + 1'b1)  : divisor;
                            end else begin
                                next_quotient_sign  = 1'b0;
                                next_remainder_sign = 1'b0;
                                next_Q = dividend;
                                next_M = divisor;
                            end
                            next_state = ACTIVE;
                        end
                    end else begin
                        next_active = 1'b0;
                    end
                end

                ACTIVE: begin
                    if (Counter == 0) begin
                        next_state = DONE;
                    end else begin
                        next_A       = trial_A;
                        next_Q       = trial_Q;
                        next_Counter = Counter - 1'b1;
                    end
                end

                DONE: begin
                    if (~edge_case) begin
                        next_quotient  = (quotient_sign) ? ~Q + 1'b1 : Q;
                        next_remainder = (remainder_sign) ? ~final_A[31:0] + 1'b1 : final_A[31:0];
                    end
                    next_active = 1'b0;
                    next_done   = 1'b1;
                    next_state  = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    always_ff @(posedge clk_in) begin
        if (!rst_n_in) begin
            A              <= 33'h0;
            M              <= 32'h0;
            Q              <= 32'h0;
            Counter        <= 6'd0;
            current_state  <= IDLE;
            active_out     <= 1'b0;
            done_out       <= 1'b0;
            quotient       <= 32'h0;
            remainder      <= 32'h0;
            quotient_sign  <= 1'b0;
            remainder_sign <= 1'b0;
            edge_case      <= 1'b0;
        end else begin
            current_state  <= next_state;
            A              <= next_A;
            M              <= next_M;
            Q              <= next_Q;
            Counter        <= next_Counter;
            quotient_sign  <= next_quotient_sign;
            remainder_sign <= next_remainder_sign;
            edge_case      <= next_edge_case;
            quotient       <= next_quotient;
            remainder      <= next_remainder;
            active_out     <= next_active;
            done_out       <= next_done;
        end
    end
endmodule
