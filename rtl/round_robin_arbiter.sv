module round_robin_arbiter #(parameter PORTS=2, ZERO_CYCLE=1)(
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
    .i_vec   (i_req_vec),
    .i_pivot (r_grant_idx),
    .o_idx   (w_enc_grant_idx),
    .o_valid (w_enc_has_req)
);

// Next state logic
always_comb begin
    w_next_grant_idx = r_grant_idx;
    w_next_has_grant = r_has_grant;
    w_next_grant_vec = '0;

    // Hold current grant
    if (r_has_grant && i_req_vec[r_grant_idx]) begin
        w_next_grant_vec = PORTS'(1) << r_grant_idx;
    end

    // Switch to new grant
    else if (w_enc_has_req) begin
        w_next_grant_idx = w_enc_grant_idx;
        w_next_has_grant = 1;
        w_next_grant_vec = PORTS'(1) << w_enc_grant_idx;
    end

    // Idle
    else begin
        w_next_has_grant = 0;
    end
end

// Zero cycle output switch
generate
    if (ZERO_CYCLE) begin
        assign o_grant_vec = (!i_rstn) ? '0 : w_next_grant_vec;
    end else begin
        logic [PORTS-1:0] r_grant_vec;
        assign o_grant_vec = r_grant_vec;
        always_ff @(posedge i_clk or negedge i_rstn) begin
            r_grant_vec <= (!i_rstn) ? '0 : w_next_grant_vec;
        end
    end
endgenerate

// State update
always_ff @(posedge i_clk) begin
    r_has_grant <= (!i_rstn) ?  0 : w_next_has_grant;
    r_grant_idx <= (!i_rstn) ? '0 : w_next_grant_idx;
end

endmodule
