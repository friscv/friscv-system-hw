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

`include "friscv_pkg.sv"

module friscv_zsbl_rom (
    input  logic [15:0] i_addr,
    output logic [31:0] o_data
);

logic [31:0] mem [0:(ZSBL_ROM_SIZE/4)-1];

logic [31:0] w_word_offset;
assign w_word_offset = (i_addr - RESET_VEC) >> 2;

assign o_data = (i_addr >= RESET_VEC && w_word_offset < (ZSBL_ROM_SIZE/4)) ?
                mem[w_word_offset] : 32'hDEADC0DE;

initial begin
    mem[0] = 32'h8000_02B7;  // lui  t0, 0x80000
    mem[1] = 32'h0002_8067;  // jalr x0, 0(t0)

    for (int i = 2; i < (ZSBL_ROM_SIZE/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
