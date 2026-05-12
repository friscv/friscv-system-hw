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

import friscv_pkg::*;

module friscv_divider(
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

    logic [32:0] A;
    data_t       M, Q;
    logic [5:0]  Counter;
    logic        quotient_sign, remainder_sign, edge_case;
    typedef 	 enum logic [1:0] {IDLE, ACTIVE, DONE} state_e;
    state_e	 current_state;

    always_ff @(posedge clk_in) begin
        logic [32:0] next_A;
        data_t       next_Q;

        if(!rst_n_in) begin
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
        end
        else if (flush_in) begin
            current_state  <= IDLE;
            active_out     <= 1'b0;
            done_out       <= 1'b0;
        end
        else begin
            case(current_state)
                IDLE: begin
                    done_out <= 1'b0;
                    if (division_detected_in) begin
                        A       <= 33'h0;
                        Counter <= 6'd32;

                        if (divisor == 32'd0) begin
                            remainder     <= dividend;
                            quotient      <= 32'hFFFFFFFF;
                            edge_case     <= 1'b1;
                            current_state <= DONE;
                        end else if (signed_division_in && dividend == 32'h80000000 && divisor == 32'hFFFFFFFF) begin
                            remainder     <= 32'd0;
                            quotient      <= 32'h80000000;
                            edge_case     <= 1'b1;
                            current_state <= DONE;
                        end

                        else begin
                            edge_case  <= 1'b0;
                            active_out <= 1'b1;
                            if(signed_division_in) begin
                                quotient_sign  <= dividend[31] ^ divisor[31];
                                remainder_sign <= dividend[31];
                                Q <= dividend[31] ? (~dividend + 1'b1) : dividend;
                                M <= divisor[31]  ? (~divisor + 1'b1)  : divisor;
                            end else begin
                                quotient_sign  <= 1'b0;
                                remainder_sign <= 1'b0;
                                Q <= dividend;
                                M <= divisor;
                            end
                            current_state <= ACTIVE;
                        end
                    end else begin
                        active_out <= 1'b0;
                    end
                end

                ACTIVE: begin
                    if(Counter == 0) begin
                        current_state <= DONE;
                    end else begin
                        {next_A, next_Q} = {A, Q} << 1;

                        next_A    = (A[32] == 1'b0) ? (next_A - {1'b0, M}) : (next_A + {1'b0, M});
                        next_Q[0] = (next_A[32] == 1'b0) ? 1'b1 : 1'b0;

                        A <= next_A;
                        Q <= next_Q;

                        Counter <= Counter - 1'b1;
                    end
                end

                DONE: begin
                    if(~edge_case) begin
                        logic [32:0] final_A;
                        final_A = A[32] ? (A + {1'b0, M}) : A;
					    quotient  <= (quotient_sign) ? ~Q + 1'b1 : Q;
                        remainder <= (remainder_sign) ? ~final_A[31:0] + 1'b1 : final_A[31:0];
                    end

                    active_out    <= 1'b0;
                    done_out      <= 1'b1;
                    current_state <= IDLE;
                end

                default: current_state <= IDLE;
            endcase
        end
    end
endmodule
