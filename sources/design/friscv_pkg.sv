/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK, 
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or 
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

*/

/*
Version history:

v 0.1.0     Mario Kovac, 2022, Initial design 
v 0.2.0     Matej Grzunov, Duje Strunje, 2022_06, pipeline debug, ALU debug, initial instruction set 
v 0.5.0		Mario Kovac, 2024_05, memory debug & update, system update
v 0.9.0     Petra Kelkovic, Luka Kokic, 2024_06, cpu & system verification, external debug interface, PC & ARM SW, External IO board connections
v 1.0.0     Mario Kovac, 2025_02, some signals renaming, if update, v1.0.0 official   

*/

`ifndef FRISCV_PKG_DEF
`define FRISCV_PKG_DEF

package friscv_pkg;

	parameter int unsigned XLEN =32;
	
	parameter int unsigned ADDR_WIDTH = XLEN;
	parameter int unsigned DATA_WIDTH = XLEN;
	
	parameter int unsigned REG_SEL_WIDTH = 5;
	parameter int unsigned REGISTER_NUM = 32;
	
	parameter int unsigned RESET_VEC = 32'h0;
	
	parameter int unsigned MEM_SIZE = 2**16;
	
    parameter int unsigned GPIO1_ADDR = 32'H10000;
    parameter int unsigned GPIO1_WIDTH = 1;

	parameter int unsigned GPIO2_ADDR = 32'H20000;
    parameter int unsigned GPIO2_WIDTH = 1;

    parameter int unsigned NOP = 32'H00000013; // ADDI x0,x0,0

	typedef enum logic [2:0] {
		I_TYPE  = 3'b000,
		I2_TYPE = 3'b001,
		S_TYPE  = 3'b010,
		B_TYPE  = 3'b011,
		U_TYPE  = 3'b100,
		J_TYPE  = 3'b101
	} imm_t;

	typedef struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r_type;

// Load/Store instruction funct3
	typedef logic [2:0] load_store_width_t;

	typedef union packed {
		logic [31:0] b;
		r_type r;
	} instr_op_t;


	typedef enum logic [1:0] {
	    BRANCH_JAL_NONE = 2'b00,
	    BRANCH_INSTR = 2'b01,
	    JAL_INSTR = 2'b10
	} branch_jal_sel_t;

	typedef enum logic [2:0] {
	    COND_EQ = 3'b000, 
	    COND_NE = 3'b001, 
	    COND_LT = 3'b100, 
	    COND_GE = 3'b101, 
	    COND_LTU = 3'b110, 
	    COND_GEU = 3'b111
	} branch_cond_t;

	typedef enum logic {
	    RS = 1'b0,
	    OTHER = 1'b1
	} mux_sel_t;

	typedef enum logic [3:0] {
		ADD_OP =  4'b0000,
		SUB_OP =  4'b1000,
		AND_OP =  4'b0111,
		OR_OP =   4'b0110,
		XOR_OP =  4'b0100,
		SLL_OP =  4'b0001,
		SRL_OP =  4'b0101,
		SRA_OP =  4'b1101,
		SLT_OP =  4'b0010,
        SLTU_OP = 4'b0011
	} alu_op_t;

	typedef enum logic [1:0] {
	    MEM_INSTR_NONE = 2'b00,
	    MEM_INSTR_LOAD = 2'b01,
	    MEM_INSTR_STORE = 2'b10
	} mem_instr_sel_t;

	typedef enum logic [1:0] {
	    WB_DATA_SEL_PC_PLUS_4 = 2'b00,
	    WB_DATA_SEL_ALU = 2'b01,
	    WB_DATA_SEL_MEM = 2'b10
    } wb_data_sel_t;
	
	// Instruction types
	typedef enum logic [6:0] {
		LOAD = 		7'b0000011, 
		FENCE = 	7'b0001111,
		ALOP_IMM = 	7'b0010011,
		AUIPC = 	7'b0010111,
		STORE = 	7'b0100011,
		ALOP = 		7'b0110011,
		LUI = 		7'b0110111,
		BRANCH = 	7'b1100011,
		JALR = 		7'b1100111,
		JAL = 		7'b1101111,
		ENV = 		7'b1110011
	} opcode_t;

	typedef struct packed {
		branch_jal_sel_t branch_jal_sel;
		branch_cond_t branch_cond;
		mux_sel_t mux1_sel;
		mux_sel_t mux2_sel;
		alu_op_t alu_op;
		mem_instr_sel_t mem_instr_sel;
		load_store_width_t load_store_width;
		wb_data_sel_t wb_data_sel;
	} instr_ex_t;

endpackage

import friscv_pkg::*;
`endif
