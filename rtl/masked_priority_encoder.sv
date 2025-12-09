module masked_priority_encoder #(parameter WIDTH=4, LSB=0)(
    input  logic [WIDTH-1:0]         i_vec,
    input  logic [$clog2(WIDTH)-1:0] i_pivot,
    output logic [$clog2(WIDTH)-1:0] o_idx,
    output logic                     o_valid
);

logic [WIDTH-1:0] w_masked_right;
logic [$clog2(WIDTH)-1:0] w_idx_right;
logic w_valid_right;

logic [WIDTH-1:0] w_masked_left;
logic [$clog2(WIDTH)-1:0] w_idx_left;
logic w_valid_left;

priority_encoder #(WIDTH, LSB) encoder_left (
    .i_vec   (w_masked_left),
    .o_idx   (w_idx_left),
    .o_valid (w_valid_left)
);

priority_encoder #(WIDTH, LSB) encoder_right (
    .i_vec   (w_masked_right),
    .o_idx   (w_idx_right),
    .o_valid (w_valid_right)
);

always_comb begin
    o_valid = w_valid_right | w_valid_left;

    // Right to left
    if (LSB) begin
        w_masked_right = i_vec &  ((WIDTH'(1) << (i_pivot + 1)) - 1);
        w_masked_left  = i_vec & ~((WIDTH'(1) << (i_pivot + 1)) - 1);

        // Prefer left (higher indexes), then right (lower indexes)
        o_idx = (w_valid_left) ? w_idx_left : (w_valid_right) ? w_idx_right : '0;
    end

    // Left to right
    else begin
        w_masked_right = i_vec &  ((WIDTH'(1) << i_pivot) - 1);
        w_masked_left  = i_vec & ~((WIDTH'(1) << i_pivot) - 1);

        // Prefer right (lower indexes), than left (higher indexes)
        o_idx = (w_valid_right) ? w_idx_right : (w_valid_left) ? w_idx_left : '0;
    end
end

endmodule
