/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK, 
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or 
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

Version info is listed in friscv_pkg.sv

AUTO-GENERATED FROM: zsbl.S
*/

`include "friscv_pkg.sv"

module friscv_zsbl_rom (
    input  addr_t i_addr,
    output inst_t o_data
);

inst_t mem [0:(ZSBL_ROM_SIZE/4)-1];
localparam int unsigned ZSBL_PROG_WORDS = 127;

logic [31:0] w_word_offset;
assign w_word_offset = (i_addr - RESET_VEC) >> 2;

assign o_data = (i_addr >= RESET_VEC && w_word_offset < (ZSBL_ROM_SIZE/4)) ? mem[w_word_offset] : NOP;

initial begin
    // Auto-generated program at RESET_VEC (0x1000)
    mem[0] = 32'h8000_0137;  // lui	x2,0x80000
    mem[1] = 32'h1001_0113;  // addi	x2,x2,256 # 80000100 <DRAM_BASE+0x100>
    mem[2] = 32'h0000_0517;  // auipc	x10,0x0
    mem[3] = 32'h1805_0513;  // addi	x10,x10,384 # 1188 <ready_msg>
    mem[4] = 32'h0d00_00ef;  // jal	x1,10e0 <uart_puts>
    mem[5] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[6] = 32'h0030_0293;  // addi	x5,x0,3
    mem[7] = 32'h0053_a623;  // sw	x5,12(x7) # 4060000c <UART_BASE+0xc>
    mem[8] = 32'h0003_a623;  // sw	x0,12(x7)
    mem[9] = 32'h4000_04b7;  // lui	x9,0x40000
    mem[10] = 32'h0044_a403;  // lw	x8,4(x9) # 40000004 <GPIO_BASE+0x4>
    mem[11] = 32'h0004_1a63;  // bne	x8,x0,1040 <.skip_direct_jump>
    mem[12] = 32'h0000_0517;  // auipc	x10,0x0
    mem[13] = 32'h1675_0513;  // addi	x10,x10,359 # 1197 <dram_msg>
    mem[14] = 32'h0a80_00ef;  // jal	x1,10e0 <uart_puts>
    mem[15] = 32'h06c0_006f;  // jal	x0,10a8 <execute_loaded>
    mem[16] = 32'h0010_0313;  // addi	x6,x0,1
    mem[17] = 32'h0064_1c63;  // bne	x8,x6,105c <.skip_uart>
    mem[18] = 32'h0000_0517;  // auipc	x10,0x0
    mem[19] = 32'h1635_0513;  // addi	x10,x10,355 # 11ab <uart_msg>
    mem[20] = 32'h0900_00ef;  // jal	x1,10e0 <uart_puts>
    mem[21] = 32'h0b80_00ef;  // jal	x1,110c <uart_boot>
    mem[22] = 32'h00c0_006f;  // jal	x0,1064 <.try_sd>
    mem[23] = 32'h0020_0313;  // addi	x6,x0,2
    mem[24] = 32'h0064_1c63;  // bne	x8,x6,1078 <.skip_sd>
    mem[25] = 32'h0000_0517;  // auipc	x10,0x0
    mem[26] = 32'h15b5_0513;  // addi	x10,x10,347 # 11bf <sd_msg>
    mem[27] = 32'h0740_00ef;  // jal	x1,10e0 <uart_puts>
    mem[28] = 32'h1140_00ef;  // jal	x1,1184 <sd_boot>
    mem[29] = 32'h00c0_006f;  // jal	x0,1080 <.try_wait>
    mem[30] = 32'h0030_0313;  // addi	x6,x0,3
    mem[31] = 32'h0264_1063;  // bne	x8,x6,109c <.invalid_mode>
    mem[32] = 32'h0000_0517;  // auipc	x10,0x0
    mem[33] = 32'h1515_0513;  // addi	x10,x10,337 # 11d1 <wait_msg>
    mem[34] = 32'h0580_00ef;  // jal	x1,10e0 <uart_puts>
    mem[35] = 32'h0004_a303;  // lw	x6,0(x9)
    mem[36] = 32'h0103_7313;  // andi	x6,x6,16
    mem[37] = 32'hfe03_0ce3;  // beq	x6,x0,108c <.try_wait+0xc>
    mem[38] = 32'h0100_006f;  // jal	x0,10a8 <execute_loaded>
    mem[39] = 32'h5000_02b7;  // lui	x5,0x50000
    mem[40] = 32'h0002_a023;  // sw	x0,0(x5) # 50000000 <HALT_ADDR>
    mem[41] = 32'hff9f_f06f;  // jal	x0,109c <.invalid_mode>
    mem[42] = 32'h8000_02b7;  // lui	x5,0x80000
    mem[43] = 32'h0002_8067;  // jalr	x0,0(x5) # 80000000 <DRAM_BASE>
    mem[44] = 32'h4060_0337;  // lui	x6,0x40600
    mem[45] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[46] = 32'h0082_f293;  // andi	x5,x5,8
    mem[47] = 32'hfe02_9ce3;  // bne	x5,x0,10b4 <uart_putc+0x4>
    mem[48] = 32'h00a3_2223;  // sw	x10,4(x6)
    mem[49] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[50] = 32'h4060_0337;  // lui	x6,0x40600
    mem[51] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[52] = 32'h0012_f293;  // andi	x5,x5,1
    mem[53] = 32'hfe02_8ce3;  // beq	x5,x0,10cc <uart_getc+0x4>
    mem[54] = 32'h0003_4503;  // lbu	x10,0(x6)
    mem[55] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[56] = 32'hffc1_0113;  // addi	x2,x2,-4
    mem[57] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[58] = 32'h0005_0393;  // addi	x7,x10,0
    mem[59] = 32'h0003_c503;  // lbu	x10,0(x7)
    mem[60] = 32'h0005_0863;  // beq	x10,x0,1100 <uart_puts+0x20>
    mem[61] = 32'hfbdf_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[62] = 32'h0013_8393;  // addi	x7,x7,1
    mem[63] = 32'hff1f_f06f;  // jal	x0,10ec <uart_puts+0xc>
    mem[64] = 32'h0001_2083;  // lw	x1,0(x2)
    mem[65] = 32'h0041_0113;  // addi	x2,x2,4
    mem[66] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[67] = 32'hff41_0113;  // addi	x2,x2,-12
    mem[68] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[69] = 32'h0081_2223;  // sw	x8,4(x2)
    mem[70] = 32'h0091_2423;  // sw	x9,8(x2)
    mem[71] = 32'h0430_0513;  // addi	x10,x0,67
    mem[72] = 32'hf91f_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[73] = 32'h8000_0437;  // lui	x8,0x80000
    mem[74] = 32'h0010_0493;  // addi	x9,x0,1
    mem[75] = 32'hf9df_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[76] = 32'h0040_0293;  // addi	x5,x0,4
    mem[77] = 32'h0455_0263;  // beq	x10,x5,1178 <.transfer_done>
    mem[78] = 32'h0010_0293;  // addi	x5,x0,1
    mem[79] = 32'hfe55_18e3;  // bne	x10,x5,112c <.wait_packet>
    mem[80] = 32'hf89f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[81] = 32'hf85f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[82] = 32'h0800_0313;  // addi	x6,x0,128
    mem[83] = 32'hf7df_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[84] = 32'h00a4_0023;  // sb	x10,0(x8) # 80000000 <DRAM_BASE>
    mem[85] = 32'h0014_0413;  // addi	x8,x8,1
    mem[86] = 32'hfff3_0313;  // addi	x6,x6,-1
    mem[87] = 32'hfe03_18e3;  // bne	x6,x0,114c <.wait_packet+0x20>
    mem[88] = 32'hf69f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[89] = 32'hf65f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[90] = 32'h0060_0513;  // addi	x10,x0,6
    mem[91] = 32'hf45f_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[92] = 32'h0014_8493;  // addi	x9,x9,1
    mem[93] = 32'hfb9f_f06f;  // jal	x0,112c <.wait_packet>
    mem[94] = 32'h0060_0513;  // addi	x10,x0,6
    mem[95] = 32'hf35f_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[96] = 32'hf29f_f06f;  // jal	x0,10a8 <execute_loaded>
    mem[97] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[98] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[99] = 32'h5220_5d4c;  // .word	0x52205d4c
    mem[100] = 32'h7964_6165;  // .word	0x79646165
    mem[101] = 32'h0000_0a0d;  // .3byte	0x000a0d
    mem[102] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[103] = 32'h4d20_5d4c;  // .word	0x4d205d4c
    mem[104] = 32'h3a65_646f;  // .word	0x3a65646f
    mem[105] = 32'h4152_4420;  // .word	0x41524420
    mem[106] = 32'h000a_0d4d;  // .word	0x000a0d4d
    mem[107] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[108] = 32'h4d20_5d4c;  // .word	0x4d205d4c
    mem[109] = 32'h3a65_646f;  // .word	0x3a65646f
    mem[110] = 32'h5241_5520;  // .word	0x52415520
    mem[111] = 32'h000a_0d54;  // .word	0x000a0d54
    mem[112] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[113] = 32'h4d20_5d4c;  // .word	0x4d205d4c
    mem[114] = 32'h3a65_646f;  // .word	0x3a65646f
    mem[115] = 32'h0d44_5320;  // .word	0x0d445320
    mem[116] = 32'h0000_000a;  // .short	0x000a
    mem[117] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[118] = 32'h5720_5d4c;  // .word	0x57205d4c
    mem[119] = 32'h6974_6961;  // .word	0x69746961
    mem[120] = 32'h6620_676e;  // .word	0x6620676e
    mem[121] = 32'h4220_726f;  // .word	0x4220726f
    mem[122] = 32'h2030_4e54;  // .word	0x20304e54
    mem[123] = 32'h7365_7270;  // .word	0x73657270
    mem[124] = 32'h000a_0d73;  // .word	0x000a0d73
    mem[125] = 32'h0000_0000;  // .byte	0x00
    mem[126] = 32'h0000_0001;  // .insn	2, 0x0001

    for (int i = ZSBL_PROG_WORDS; i < (ZSBL_ROM_SIZE/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
