module friscv_address_translation(
    input  logic        i_clk,
    input  logic        i_rstn,
    
    // Translation parameters
    input  logic [31:0] i_base_addr,

    // Translated address
    input  logic [31:0] i_cpu_addr,
    output logic [31:0] o_dram_addr
);

logic r_base_addr;
assign o_dram_addr = (i_cpu_addr < i_base_addr) ? i_cpu_addr : i_cpu_addr - i_base_addr;

always_ff @(posedge i_clk) begin
    if (!i_rstn)
        r_base_addr <= i_base_addr;
end

endmodule
