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
