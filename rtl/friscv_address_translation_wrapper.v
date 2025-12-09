module friscv_address_translation_wrapper(
    input  wire        i_clk,
    input  wire        i_rstn,
    
    // Translation parameters
    input  wire [31:0] i_base_addr,

    // Translated address
    input  wire [31:0] i_cpu_addr,
    output wire [31:0] o_dram_addr
);

friscv_address_translation address_translation (
    .i_clk       (i_clk),
    .i_rstn      (i_rstn),
    .i_base_addr (i_base_addr),
    .i_cpu_addr  (i_cpu_addr),
    .o_dram_addr (o_dram_addr)
);

endmodule
