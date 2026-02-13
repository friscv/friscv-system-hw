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
localparam int unsigned ZSBL_PROG_WORDS = 128;

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
    mem[6] = 32'h1805_0513;  // addi	x10,x10,384 # 1194 <ready_msg>
    mem[7] = 32'h0c00_00ef;  // jal	x1,10dc <uart_puts>
    mem[8] = 32'h4000_04b7;  // lui	x9,0x40000
    mem[9] = 32'h0084_a403;  // lw	x8,8(x9) # 40000008 <GPIO_BASE+0x8>
    mem[10] = 32'h0004_1a63;  // bne	x8,x0,103c <.skip_direct_jump>
    mem[11] = 32'h0000_0517;  // auipc	x10,0x0
    mem[12] = 32'h1775_0513;  // addi	x10,x10,375 # 11a3 <dram_msg>
    mem[13] = 32'h0a80_00ef;  // jal	x1,10dc <uart_puts>
    mem[14] = 32'h06c0_006f;  // jal	x0,10a4 <execute_loaded>
    mem[15] = 32'h0010_0313;  // addi	x6,x0,1
    mem[16] = 32'h0064_1c63;  // bne	x8,x6,1058 <.skip_uart>
    mem[17] = 32'h0000_0517;  // auipc	x10,0x0
    mem[18] = 32'h1735_0513;  // addi	x10,x10,371 # 11b7 <uart_msg>
    mem[19] = 32'h0900_00ef;  // jal	x1,10dc <uart_puts>
    mem[20] = 32'h0c80_00ef;  // jal	x1,1118 <uart_boot>
    mem[21] = 32'h00c0_006f;  // jal	x0,1060 <.try_sd>
    mem[22] = 32'h0020_0313;  // addi	x6,x0,2
    mem[23] = 32'h0064_1c63;  // bne	x8,x6,1074 <.skip_sd>
    mem[24] = 32'h0000_0517;  // auipc	x10,0x0
    mem[25] = 32'h16b5_0513;  // addi	x10,x10,363 # 11cb <sd_msg>
    mem[26] = 32'h0740_00ef;  // jal	x1,10dc <uart_puts>
    mem[27] = 32'h1240_00ef;  // jal	x1,1190 <sd_boot>
    mem[28] = 32'h00c0_006f;  // jal	x0,107c <.try_wait>
    mem[29] = 32'h0030_0313;  // addi	x6,x0,3
    mem[30] = 32'h0264_1063;  // bne	x8,x6,1098 <.invalid_mode>
    mem[31] = 32'h0000_0517;  // auipc	x10,0x0
    mem[32] = 32'h1615_0513;  // addi	x10,x10,353 # 11dd <wait_msg>
    mem[33] = 32'h0580_00ef;  // jal	x1,10dc <uart_puts>
    mem[34] = 32'h0004_a303;  // lw	x6,0(x9)
    mem[35] = 32'h0103_7313;  // andi	x6,x6,16
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
    mem[55] = 32'hffc1_0113;  // addi	x2,x2,-4 # 80fffffc <DRAM_BASE+0xfffffc>
    mem[56] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[57] = 32'h0005_0393;  // addi	x7,x10,0
    mem[58] = 32'h0003_c503;  // lbu	x10,0(x7)
    mem[59] = 32'h0005_0863;  // beq	x10,x0,10fc <uart_puts+0x20>
    mem[60] = 32'hfbdf_f0ef;  // jal	x1,10ac <uart_putc>
    mem[61] = 32'h0013_8393;  // addi	x7,x7,1
    mem[62] = 32'hff1f_f06f;  // jal	x0,10e8 <uart_puts+0xc>
    mem[63] = 32'h4060_03b7;  // lui	x7,0x40600
    mem[64] = 32'h0083_a283;  // lw	x5,8(x7) # 40600008 <UART_BASE+0x8>
    mem[65] = 32'h0042_f293;  // andi	x5,x5,4
    mem[66] = 32'hfe02_8ce3;  // beq	x5,x0,1100 <uart_puts+0x24>
    mem[67] = 32'h0001_2083;  // lw	x1,0(x2)
    mem[68] = 32'h0041_0113;  // addi	x2,x2,4
    mem[69] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[70] = 32'hff41_0113;  // addi	x2,x2,-12
    mem[71] = 32'h0011_2023;  // sw	x1,0(x2)
    mem[72] = 32'h0081_2223;  // sw	x8,4(x2)
    mem[73] = 32'h0091_2423;  // sw	x9,8(x2)
    mem[74] = 32'h0430_0513;  // addi	x10,x0,67
    mem[75] = 32'hf81f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[76] = 32'h8000_0437;  // lui	x8,0x80000
    mem[77] = 32'h0010_0493;  // addi	x9,x0,1
    mem[78] = 32'hf8df_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[79] = 32'h0040_0293;  // addi	x5,x0,4
    mem[80] = 32'h0455_0263;  // beq	x10,x5,1184 <.transfer_done>
    mem[81] = 32'h0010_0293;  // addi	x5,x0,1
    mem[82] = 32'hfe55_18e3;  // bne	x10,x5,1138 <.wait_packet>
    mem[83] = 32'hf79f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[84] = 32'hf75f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[85] = 32'h0800_0313;  // addi	x6,x0,128
    mem[86] = 32'hf6df_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[87] = 32'h00a4_0023;  // sb	x10,0(x8) # 80000000 <DRAM_BASE>
    mem[88] = 32'h0014_0413;  // addi	x8,x8,1
    mem[89] = 32'hfff3_0313;  // addi	x6,x6,-1
    mem[90] = 32'hfe03_18e3;  // bne	x6,x0,1158 <.wait_packet+0x20>
    mem[91] = 32'hf59f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[92] = 32'hf55f_f0ef;  // jal	x1,10c4 <uart_getc>
    mem[93] = 32'h0060_0513;  // addi	x10,x0,6
    mem[94] = 32'hf35f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[95] = 32'h0014_8493;  // addi	x9,x9,1
    mem[96] = 32'hfb9f_f06f;  // jal	x0,1138 <.wait_packet>
    mem[97] = 32'h0060_0513;  // addi	x10,x0,6
    mem[98] = 32'hf25f_f0ef;  // jal	x1,10ac <uart_putc>
    mem[99] = 32'hf19f_f06f;  // jal	x0,10a4 <execute_loaded>
    mem[100] = 32'h0000_8067;  // jalr	x0,0(x1)
    mem[101] = 32'h4253_5a5b;  // .word	0x42535a5b
    mem[102] = 32'h5220_5d4c;  // .word	0x52205d4c
    mem[103] = 32'h7964_6165;  // .word	0x79646165
    mem[104] = 32'h5b00_0a0d;  // .3byte	0x000a0d
    mem[105] = 32'h4c42_535a;  // 
    mem[106] = 32'h6f4d_205d;  // 
    mem[107] = 32'h203a_6564;  // 
    mem[108] = 32'h4d41_5244;  // 
    mem[109] = 32'h5b00_0a0d;  // 
    mem[110] = 32'h4c42_535a;  // 
    mem[111] = 32'h6f4d_205d;  // 
    mem[112] = 32'h203a_6564;  // 
    mem[113] = 32'h5452_4155;  // 
    mem[114] = 32'h5b00_0a0d;  // 
    mem[115] = 32'h4c42_535a;  // 
    mem[116] = 32'h6f4d_205d;  // 
    mem[117] = 32'h203a_6564;  // 
    mem[118] = 32'h0a0d_4453;  // 
    mem[119] = 32'h535a_5b00;  // 
    mem[120] = 32'h205d_4c42;  // 
    mem[121] = 32'h7469_6157;  // 
    mem[122] = 32'h2067_6e69;  // 
    mem[123] = 32'h2072_6f66;  // 
    mem[124] = 32'h304e_5442;  // 
    mem[125] = 32'h6572_7020;  // 
    mem[126] = 32'h0a0d_7373;  // 
    mem[127] = 32'h0001_0000;  // 

    for (int i = ZSBL_PROG_WORDS; i < (ZSBL_ROM_SIZE_BYTES/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
