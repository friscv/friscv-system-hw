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

(* ram_style = "block" *) inst_t mem [0:(ZSBL_ROM_SIZE_BYTES/4)-1];
localparam int unsigned ZSBL_PROG_WORDS = 155;

logic [31:0] w_word_offset;
logic        w_valid;
inst_t       r_data;

assign w_word_offset = (i_addr - RESET_VEC) >> 2;
assign w_valid = (i_addr >= RESET_VEC && w_word_offset < (ZSBL_ROM_SIZE_BYTES/4));

// Registered read for BRAM inference
always_ff @(posedge i_clk) begin
    if (w_valid) begin
        r_data <= mem[w_word_offset];
    end else begin
        r_data <= NOP;
    end
end

assign o_data = r_data;

initial begin
    // Auto-generated program at RESET_VEC (0x1000)
    mem[0] = 32'h8100_0137;  // lui	x2,0x81000
    mem[1] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[2] = 32'h0030_0293;  // addi	x5,x0,3
    mem[3] = 32'h0053_a623;  // sw	x5,12(x7) # 4060000c <UART_BASE+0xc>
    mem[4] = 32'h0003_a623;  // sw	x0,12(x7)
    mem[5] = 32'h0000_0517;  // auipc	x10,0x0
    mem[6] = 32'h1ec5_0513;  // addi	x10,x10,492 # 1200 <ready_msg>
    mem[7] = 32'h0c40_00ef;  // jal	x1,10e0 <uart_puts>
    mem[8] = 32'h4000_04b7;  // lui	x9,0x40000
    mem[9] = 32'h4001_0937;  // lui	x18,0x40010
    mem[10] = 32'h0084_a403;  // lw	x8,8(x9) # 40000008 <GPIO0_BASE+0x8>
    mem[11] = 32'h0004_1a63;  // bne	x8,x0,1040 <.skip_direct_jump>
    mem[12] = 32'h0000_0517;  // auipc	x10,0x0
    mem[13] = 32'h1df5_0513;  // addi	x10,x10,479 # 120f <dram_msg>
    mem[14] = 32'h0a80_00ef;  // jal	x1,10e0 <uart_puts>
    mem[15] = 32'h06c0_006f;  // jal	x0,10a8 <execute_loaded>
    mem[16] = 32'h0010_0313;  // addi	x6,x0,1
    mem[17] = 32'h0064_1c63;  // bne	x8,x6,105c <.skip_uart>
    mem[18] = 32'h0000_0517;  // auipc	x10,0x0
    mem[19] = 32'h1db5_0513;  // addi	x10,x10,475 # 1223 <uart_msg>
    mem[20] = 32'h0900_00ef;  // jal	x1,10e0 <uart_puts>
    mem[21] = 32'h0f00_00ef;  // jal	x1,1144 <uart_boot>
    mem[22] = 32'h00c0_006f;  // jal	x0,1064 <.try_sd>
    mem[23] = 32'h0020_0313;  // addi	x6,x0,2
    mem[24] = 32'h0064_1c63;  // bne	x8,x6,1078 <.skip_sd>
    mem[25] = 32'h0000_0517;  // auipc	x10,0x0
    mem[26] = 32'h1d35_0513;  // addi	x10,x10,467 # 1237 <sd_msg>
    mem[27] = 32'h0740_00ef;  // jal	x1,10e0 <uart_puts>
    mem[28] = 32'h18c0_00ef;  // jal	x1,11fc <sd_boot>
    mem[29] = 32'h00c0_006f;  // jal	x0,1080 <.try_wait>
    mem[30] = 32'h0030_0313;  // addi	x6,x0,3
    mem[31] = 32'h0264_1063;  // bne	x8,x6,109c <.invalid_mode>
    mem[32] = 32'h0000_0517;  // auipc	x10,0x0
    mem[33] = 32'h1c95_0513;  // addi	x10,x10,457 # 1249 <wait_msg>
    mem[34] = 32'h0580_00ef;  // jal	x1,10e0 <uart_puts>
    mem[35] = 32'h0009_2303;  // lw	x6,0(x18) # 40010000 <GPIO1_BASE>
    mem[36] = 32'h0013_7313;  // andi	x6,x6,1
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
    mem[56] = 32'hffc1_0113;  // addi	x2,x2,-4 # 80fffffc <DRAM_BASE+0xfffffc>
    mem[57] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[58] = 32'h0005_0393;  // addi	x7,x10,0
    mem[59] = 32'h0003_c503;  // lbu	x10,0(x7)
    mem[60] = 32'h0005_0863;  // beq	x10,x0,1100 <uart_puts+0x20>
    mem[61] = 32'hfbdf_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[62] = 32'h0013_8393;  // addi	x7,x7,1
    mem[63] = 32'hff1f_f06f;  // jal	x0,10ec <uart_puts+0xc>
    mem[64] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[65] = 32'h0083_a283;  // lw	x5,8(x7) # 40600008 <UART_BASE+0x8>
    mem[66] = 32'h0042_f293;  // andi	x5,x5,4
    mem[67] = 32'hfe02_8ce3;  // beq	x5,x0,1104 <uart_puts+0x24>
    mem[68] = 32'h0001_2083;  // lw	x1,0(x2)
    mem[69] = 32'h0041_0113;  // addi	x2,x2,4
    mem[70] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[71] = 32'h4060_0337;  // lui	x6,0x40600
    mem[72] = 32'h0083_2283;  // lw	x5,8(x6) # 40600008 <UART_BASE+0x8>
    mem[73] = 32'h0012_f293;  // andi	x5,x5,1
    mem[74] = 32'h0002_9a63;  // bne	x5,x0,113c <uart_getc_timeout+0x20>
    mem[75] = 32'hfff5_8593;  // addi	x11,x11,-1
    mem[76] = 32'hfe05_98e3;  // bne	x11,x0,1120 <uart_getc_timeout+0x4>
    mem[77] = 32'hfff0_0513;  // addi	x10,x0,-1
    mem[78] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[79] = 32'h0003_4503;  // lbu	x10,0(x6)
    mem[80] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[81] = 32'hff01_0113;  // addi	x2,x2,-16
    mem[82] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[83] = 32'h0081_2223;  // sw	x8,4(x2)
    mem[84] = 32'h0091_2423;  // sw	x9,8(x2)
    mem[85] = 32'h0121_2623;  // sw	x18,12(x2)
    mem[86] = 32'h8000_0437;  // lui	x8,0x80000
    mem[87] = 32'h0010_0493;  // addi	x9,x0,1
    mem[88] = 32'h0100_0913;  // addi	x18,x0,16
    mem[89] = 32'h0430_0513;  // addi	x10,x0,67
    mem[90] = 32'hf49f_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[91] = 32'h0098_95b7;  // lui	x11,0x989
    mem[92] = 32'h6805_8593;  // addi	x11,x11,1664 # 989680 <UART_TIMEOUT_COUNT>
    mem[93] = 32'hfa9f_f0ef;  // jal	x1,111c <uart_getc_timeout>
    mem[94] = 32'hfff0_0293;  // addi	x5,x0,-1
    mem[95] = 32'h0055_0463;  // beq	x10,x5,1184 <.xmodem_check_retry>
    mem[96] = 32'h0280_006f;  // jal	x0,11a8 <.check_char>
    mem[97] = 32'hfff9_0913;  // addi	x18,x18,-1
    mem[98] = 32'hfc09_1ee3;  // bne	x18,x0,1164 <.xmodem_start_retry>
    mem[99] = 32'h0001_2083;  // lw	x1,0(x2)
    mem[100] = 32'h0041_2403;  // lw	x8,4(x2)
    mem[101] = 32'h0081_2483;  // lw	x9,8(x2)
    mem[102] = 32'h00c1_2903;  // lw	x18,12(x2)
    mem[103] = 32'h0101_0113;  // addi	x2,x2,16
    mem[104] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[105] = 32'hf25f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[106] = 32'h0040_0293;  // addi	x5,x0,4
    mem[107] = 32'h0455_0263;  // beq	x10,x5,11f0 <.transfer_done>
    mem[108] = 32'h0010_0293;  // addi	x5,x0,1
    mem[109] = 32'hfe55_18e3;  // bne	x10,x5,11a4 <.next_packet>
    mem[110] = 32'hf11f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[111] = 32'hf0df_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[112] = 32'h0800_0313;  // addi	x6,x0,128
    mem[113] = 32'hf05f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[114] = 32'h00a4_0023;  // sb	x10,0(x8) # 80000000 <DRAM_BASE>
    mem[115] = 32'h0014_0413;  // addi	x8,x8,1
    mem[116] = 32'hfff3_0313;  // addi	x6,x6,-1
    mem[117] = 32'hfe03_18e3;  // bne	x6,x0,11c4 <.check_char+0x1c>
    mem[118] = 32'hef1f_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[119] = 32'heedf_f0ef;  // jal	x1,10c8 <uart_getc>
    mem[120] = 32'h0060_0513;  // addi	x10,x0,6
    mem[121] = 32'hecdf_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[122] = 32'h0014_8493;  // addi	x9,x9,1
    mem[123] = 32'hfb9f_f06f;  // jal	x0,11a4 <.next_packet>
    mem[124] = 32'h0060_0513;  // addi	x10,x0,6
    mem[125] = 32'hebdf_f0ef;  // jal	x1,10b0 <uart_putc>
    mem[126] = 32'heb1f_f06f;  // jal	x0,10a8 <execute_loaded>
    mem[127] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[128] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[129] = 32'h5220_5d4c;  // .word	0x52205d4c
    mem[130] = 32'h7964_6165;  // .word	0x79646165
    mem[131] = 32'h5b00_0a0d;  // .3byte	0x000a0d
    mem[132] = 32'h4c42_535a;  // 
    mem[133] = 32'h6f4d_205d;  // 
    mem[134] = 32'h203a_6564;  // 
    mem[135] = 32'h4d41_5244;  // 
    mem[136] = 32'h5b00_0a0d;  // 
    mem[137] = 32'h4c42_535a;  // 
    mem[138] = 32'h6f4d_205d;  // 
    mem[139] = 32'h203a_6564;  // 
    mem[140] = 32'h5452_4155;  // 
    mem[141] = 32'h5b00_0a0d;  // 
    mem[142] = 32'h4c42_535a;  // 
    mem[143] = 32'h6f4d_205d;  // 
    mem[144] = 32'h203a_6564;  // 
    mem[145] = 32'h0a0d_4453;  // 
    mem[146] = 32'h535a_5b00;  // 
    mem[147] = 32'h205d_4c42;  // 
    mem[148] = 32'h7469_6157;  // 
    mem[149] = 32'h2067_6e69;  // 
    mem[150] = 32'h2072_6f66;  // 
    mem[151] = 32'h304e_5442;  // 
    mem[152] = 32'h6572_7020;  // 
    mem[153] = 32'h0a0d_7373;  // 
    mem[154] = 32'h0001_0000;  // 

    for (int i = ZSBL_PROG_WORDS; i < (ZSBL_ROM_SIZE_BYTES/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
