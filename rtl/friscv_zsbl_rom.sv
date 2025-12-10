`include "friscv_pkg.sv"

module friscv_zsbl_rom(
    input  logic [11:0] i_addr,
    output logic [31:0] o_data
);

logic [31:0] mem [0:ZSBL_ROM_SIZE-1];

logic [31:0] w_word_offset;
assign w_word_offset = (i_addr - RESET_VEC) >> 2;

assign o_data = (i_addr >= RESET_VEC && w_word_offset < ZSBL_ROM_SIZE) ?
                mem[w_word_offset] : 32'hDEADC0DE;

initial begin
    mem[0] = 32'h0000_0513;  // addi a0, x0, 0 - replace with csrr when implemented
    // mem[0] = 32'hF140_2573;  // csrr a0, mhartid
    mem[1] = 32'h8000_02B7;  // lui  t0, 0x80000
    mem[1] = 32'h0002_8067;  // jalr x0, 0(t0)

    for (int i = 16; i < ZSBL_ROM_SIZE; i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
