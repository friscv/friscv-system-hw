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

module round_robin_arbiter #(
    parameter PORTS = 2
) (
    input  logic i_clk,
    input  logic i_rstn,
    input  logic [PORTS-1:0] i_req_vec,
    output logic [PORTS-1:0] o_grant_vec
);

// State registers
logic [$clog2(PORTS)-1:0] r_grant_idx;
logic r_has_grant;

// Next state signals
logic [$clog2(PORTS)-1:0] w_next_grant_idx;
logic w_next_has_grant;
logic [PORTS-1:0] w_next_grant_vec;

// Encoder outputs
logic [$clog2(PORTS)-1:0] w_enc_grant_idx;
logic w_enc_has_req;

// Encoder pivots around registered index
masked_priority_encoder #(PORTS, 1) masked_encoder (
    .i_vec   ( i_req_vec       ),
    .i_pivot ( r_grant_idx     ),
    .o_idx   ( w_enc_grant_idx ),
    .o_valid ( w_enc_has_req   )
);

// Next state logic
always_comb begin
    w_next_grant_idx = r_grant_idx;
    w_next_has_grant = r_has_grant;
    w_next_grant_vec = '0;

    if (r_has_grant && i_req_vec[r_grant_idx]) begin
        // Hold current grant
        w_next_grant_vec = PORTS'(1) << r_grant_idx;
    end else if (w_enc_has_req) begin
        // Switch to new grant
        w_next_grant_idx = w_enc_grant_idx;
        w_next_has_grant = 1;
        w_next_grant_vec = PORTS'(1) << w_enc_grant_idx;
    end else begin
        // Idle
        w_next_has_grant = 0;
    end
end

assign o_grant_vec = (!i_rstn) ? '0 : w_next_grant_vec;

// State update
always_ff @(posedge i_clk) begin
    r_has_grant <= (!i_rstn) ?  0 : w_next_has_grant;
    r_grant_idx <= (!i_rstn) ? '0 : w_next_grant_idx;
end

endmodule
