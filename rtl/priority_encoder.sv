module priority_encoder #(parameter WIDTH=4, LSB=0)(
    input  logic [WIDTH-1:0]         i_vec,
    output logic [$clog2(WIDTH)-1:0] o_idx,
    output logic                     o_valid
);

always_comb begin
    o_idx   = '0;
    o_valid = 0;

    for (int i = 0; i < WIDTH; i++) begin
        if (i_vec[i]) begin
            o_idx   = i;
            o_valid = 1;
            // Stop on lowest set bit if LSB has priority
            if (LSB) break;
        end
    end
end

endmodule
