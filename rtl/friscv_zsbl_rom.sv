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
    input  logic  i_clk,
    input  addr_t i_addr,
    output inst_t o_data
);

(* ram_style = "block" *) inst_t mem [ZSBL_ROM_SIZE_BYTES/4];
localparam int unsigned ZSBL_PROG_WORDS = 152;

logic [31:0] w_word_offset;
logic        w_valid;
inst_t       r_data;

assign w_word_offset = (i_addr - RESET_VEC) >> 2;
assign w_valid = (i_addr >= RESET_VEC && w_word_offset < (ZSBL_ROM_SIZE_BYTES/4));

// Registered read for BRAM inference
always_ff @(posedge i_clk) begin
    // Do not reset r_data, will not synthesize as BRAM if reset added
    if (w_valid) begin
        r_data <= mem[w_word_offset];
    end else begin
        r_data <= NOP;
    end
end

assign o_data = r_data;

initial begin
    // Auto-generated program at RESET_VEC (0x1000)
    mem[0] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[1] = 32'h0030_0293;  // addi	x5,x0,3
    mem[2] = 32'h0053_a623;  // sw	x5,12(x7) # 4060000c <UART_BASE+0xc>
    mem[3] = 32'h0003_a623;  // sw	x0,12(x7)
    mem[4] = 32'h0000_0517;  // auipc	x10,0x0
    mem[5] = 32'h1e45_0513;  // addi	x10,x10,484 # 11f4 <ready_msg>
    mem[6] = 32'h0c40_00ef;  // jal	x1,10dc <uart_puts>
    mem[7] = 32'h4000_04b7;  // lui	x9,0x40000
    mem[8] = 32'h4001_0937;  // lui	x18,0x40010
    mem[9] = 32'h0084_a403;  // lw	x8,8(x9) # 40000008 <GPIO0_BASE+0x8>
    mem[10] = 32'h0004_1a63;  // bne	x8,x0,103c <.skip_direct_jump>
    mem[11] = 32'h0000_0517;  // auipc	x10,0x0
    mem[12] = 32'h1d75_0513;  // addi	x10,x10,471 # 1203 <dram_msg>
    mem[13] = 32'h0a80_00ef;  // jal	x1,10dc <uart_puts>
    mem[14] = 32'h06c0_006f;  // jal	x0,10a4 <execute_loaded>
    mem[15] = 32'h0010_0313;  // addi	x6,x0,1
    mem[16] = 32'h0064_1c63;  // bne	x8,x6,1058 <.skip_uart>
    mem[17] = 32'h0000_0517;  // auipc	x10,0x0
    mem[18] = 32'h1d35_0513;  // addi	x10,x10,467 # 1217 <uart_msg>
    mem[19] = 32'h0900_00ef;  // jal	x1,10dc <uart_puts>
    mem[20] = 32'h0e80_00ef;  // jal	x1,1138 <uart_boot>
    mem[21] = 32'h00c0_006f;  // jal	x0,1060 <.try_sd>
    mem[22] = 32'h0020_0313;  // addi	x6,x0,2
    mem[23] = 32'h0064_1c63;  // bne	x8,x6,1074 <.skip_sd>
    mem[24] = 32'h0000_0517;  // auipc	x10,0x0
    mem[25] = 32'h1cb5_0513;  // addi	x10,x10,459 # 122b <sd_msg>
    mem[26] = 32'h0740_00ef;  // jal	x1,10dc <uart_puts>
    mem[27] = 32'h1840_00ef;  // jal	x1,11f0 <sd_boot>
    mem[28] = 32'h00c0_006f;  // jal	x0,107c <.try_wait>
    mem[29] = 32'h0030_0313;  // addi	x6,x0,3
    mem[30] = 32'h0264_1063;  // bne	x8,x6,1098 <.invalid_mode>
    mem[31] = 32'h0000_0517;  // auipc	x10,0x0
    mem[32] = 32'h1c15_0513;  // addi	x10,x10,449 # 123d <wait_msg>
    mem[33] = 32'h0580_00ef;  // jal	x1,10dc <uart_puts>
    mem[34] = 32'h0009_2303;  // lw	x6,0(x18) # 40010000 <GPIO1_BASE>
    mem[35] = 32'h0013_7313;  // andi	x6,x6,1
    mem[36] = 32'hfe03_0ce3;  // beq	x6,x0,1088 <.try_wait+0xc>
    mem[37] = 32'h0100_006f;  // jal	x0,10a4 <execute_loaded>
    mem[38] = 32'h5000_02b7;  // lui	x5,0x50000
    mem[39] = 32'h0002_a023;  // sw	x0,0(x5) # 50000000 <HALT_ADDR>
    mem[40] = 32'hff9f_f06f;  // jal	x0,1098 <.invalid_mode>
    mem[41] = 32'h8000_02b7;  // lui	x5,0x80000
    mem[42] = 32'h0002_8067;  // jalr	x0,0(x5) # 80000000 <DRAM_BASE>
    mem[43] = 32'h4060_0337;  // lui	x6,0x40600
    mem[44] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[45] = 32'h0082_f293;  // andi	x5,x5,8
    mem[46] = 32'hfe02_9ce3;  // bne	x5,x0,10b0 <uart_putc+0x4>
    mem[47] = 32'h00a3_2223;  // sw	x10,4(x6)
    mem[48] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[49] = 32'h4060_0337;  // lui	x6,0x40600
    mem[50] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[51] = 32'h0012_f293;  // andi	x5,x5,1
    mem[52] = 32'hfe02_8ce3;  // beq	x5,x0,10c8 <uart_getc+0x4>
    mem[53] = 32'h0003_4503;  // lbu	x10,0(x6)
    mem[54] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[55] = 32'h0000_8993;  // addi	x19,x1,0
    mem[56] = 32'h0005_0393;  // addi	x7,x10,0
    mem[57] = 32'h0003_c503;  // lbu	x10,0(x7)
    mem[58] = 32'h0005_0863;  // beq	x10,x0,10f8 <uart_puts+0x1c>
    mem[59] = 32'hfc1f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[60] = 32'h0013_8393;  // addi	x7,x7,1
    mem[61] = 32'hff1f_f06f;  // jal	x0,10e4 <uart_puts+0x8>
    mem[62] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[63] = 32'h0083_a283;  // lw	x5,8(x7) # 40600008 <UART_BASE+0x8>
    mem[64] = 32'h0042_f293;  // andi	x5,x5,4
    mem[65] = 32'hfe02_8ce3;  // beq	x5,x0,10fc <uart_puts+0x20>
    mem[66] = 32'h0009_8093;  // addi	x1,x19,0
    mem[67] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[68] = 32'h4060_0337;  // lui	x6,0x40600
    mem[69] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[70] = 32'h0012_f293;  // andi	x5,x5,1
    mem[71] = 32'h0002_9a63;  // bne	x5,x0,1130 <uart_getc_timeout+0x20>
    mem[72] = 32'hfff5_8593;  // addi	x11,x11,-1
    mem[73] = 32'hfe05_98e3;  // bne	x11,x0,1114 <uart_getc_timeout+0x4>
    mem[74] = 32'hfff0_0513;  // addi	x10,x0,-1
    mem[75] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[76] = 32'h0003_4503;  // lbu	x10,0(x6)
    mem[77] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[78] = 32'h0000_8a13;  // addi	x20,x1,0
    mem[79] = 32'h8000_0ab7;  // lui	x21,0x80000
    mem[80] = 32'h0010_0b13;  // addi	x22,x0,1
    mem[81] = 32'h0100_0b93;  // addi	x23,x0,16
    mem[82] = 32'h0010_0293;  // addi	x5,x0,1
    mem[83] = 32'h0054_a023;  // sw	x5,0(x9)
    mem[84] = 32'h0430_0513;  // addi	x10,x0,67
    mem[85] = 32'hf59f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[86] = 32'h0098_95b7;  // lui	x11,0x989
    mem[87] = 32'h6805_8593;  // addi	x11,x11,1664 # 989680 <UART_TIMEOUT_COUNT>
    mem[88] = 32'hfb1f_f0ef;  // jal	x1,1110 <uart_getc_timeout>
    mem[89] = 32'hfff0_0293;  // addi	x5,x0,-1
    mem[90] = 32'h0055_0463;  // beq	x10,x5,1170 <.xmodem_check_retry>
    mem[91] = 32'h01c0_006f;  // jal	x0,1188 <.check_char>
    mem[92] = 32'hfffb_8b93;  // addi	x23,x23,-1
    mem[93] = 32'hfc0b_9ee3;  // bne	x23,x0,1150 <.xmodem_start_retry>
    mem[94] = 32'h0004_a023;  // sw	x0,0(x9)
    mem[95] = 32'h000a_0093;  // addi	x1,x20,0
    mem[96] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[97] = 32'hf41f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[98] = 32'h0040_0293;  // addi	x5,x0,4
    mem[99] = 32'h0455_0463;  // beq	x10,x5,11d4 <.transfer_done>
    mem[100] = 32'h0010_0293;  // addi	x5,x0,1
    mem[101] = 32'hfe55_18e3;  // bne	x10,x5,1184 <.next_packet>
    mem[102] = 32'h0004_a023;  // sw	x0,0(x9)
    mem[103] = 32'hf29f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[104] = 32'hf25f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[105] = 32'h0800_0c13;  // addi	x24,x0,128
    mem[106] = 32'hf1df_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[107] = 32'h00aa_8023;  // sb	x10,0(x21) # 80000000 <DRAM_BASE>
    mem[108] = 32'h001a_8a93;  // addi	x21,x21,1
    mem[109] = 32'hfffc_0c13;  // addi	x24,x24,-1
    mem[110] = 32'hfe0c_18e3;  // bne	x24,x0,11a8 <.check_char+0x20>
    mem[111] = 32'hf09f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[112] = 32'hf05f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[113] = 32'h0060_0513;  // addi	x10,x0,6
    mem[114] = 32'hee5f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[115] = 32'h001b_0b13;  // addi	x22,x22,1
    mem[116] = 32'hfb5f_f06f;  // jal	x0,1184 <.next_packet>
    mem[117] = 32'h0060_0513;  // addi	x10,x0,6
    mem[118] = 32'hed5f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[119] = 32'h4060_0337;  // lui	x6,0x40600
    mem[120] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[121] = 32'h0042_f293;  // andi	x5,x5,4
    mem[122] = 32'hfe02_8ce3;  // beq	x5,x0,11e0 <.transfer_done+0xc>
    mem[123] = 32'heb9f_f06f;  // jal	x0,10a4 <execute_loaded>
    mem[124] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[125] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[126] = 32'h5220_5d4c;  // .word	0x52205d4c
    mem[127] = 32'h7964_6165;  // .word	0x79646165
    mem[128] = 32'h5b00_0a0d;  // .3byte	0x000a0d
    mem[129] = 32'h4c42_535a;  // 
    mem[130] = 32'h6f4d_205d;  // 
    mem[131] = 32'h203a_6564;  // 
    mem[132] = 32'h4d41_5244;  // 
    mem[133] = 32'h5b00_0a0d;  // 
    mem[134] = 32'h4c42_535a;  // 
    mem[135] = 32'h6f4d_205d;  // 
    mem[136] = 32'h203a_6564;  // 
    mem[137] = 32'h5452_4155;  // 
    mem[138] = 32'h5b00_0a0d;  // 
    mem[139] = 32'h4c42_535a;  // 
    mem[140] = 32'h6f4d_205d;  // 
    mem[141] = 32'h203a_6564;  // 
    mem[142] = 32'h0a0d_4453;  // 
    mem[143] = 32'h535a_5b00;  // 
    mem[144] = 32'h205d_4c42;  // 
    mem[145] = 32'h7469_6157;  // 
    mem[146] = 32'h2067_6e69;  // 
    mem[147] = 32'h2072_6f66;  // 
    mem[148] = 32'h304e_5442;  // 
    mem[149] = 32'h6572_7020;  // 
    mem[150] = 32'h0a0d_7373;  // 
    mem[151] = 32'h0001_0000;  // 

    for (int i = ZSBL_PROG_WORDS; i < (ZSBL_ROM_SIZE_BYTES/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
