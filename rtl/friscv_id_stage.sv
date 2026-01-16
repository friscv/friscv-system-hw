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

module friscv_id_stage (
    input  logic      clk_in,

    // Stage control inputs
    input  logic      rst_n_in,
    input  logic      flush_in,
    input  logic      stage_stall_in,

    output reg_addr_t rs1_sel_out,
    output reg_addr_t rs2_sel_out,
    output reg_addr_t rd_sel_out,

    output logic      illegal_inst,

    // Inputs from IF stage
    input  addr_t     pc_in,
    input  addr_t     pc_plus_4_in,
    input  inst_t     ir_in,

    // Outputs to EX stage
    output addr_t     pc_out,
    output addr_t     pc_plus_4_out,
    output data_t     rs1_out,
    output data_t     rs2_out,
    output data_t     imm32_out,
    output instr_ex_t instr_ex_out,

    // Inputs from WB stage    
    input  reg_addr_t rd_sel_in,
    input  data_t     rd_data_in
);

instr_op_t ir_buff;
addr_t     pc_in_buff;
addr_t     pc_plus_4_in_buff;
data_t     regfile [REGISTER_NUM] = '{REGISTER_NUM{0}};
imm_t      imm_sel;

assign rs1_out = (rd_sel_in != 0 && rs1_sel_out == rd_sel_in) ? rd_data_in : regfile[rs1_sel_out];
assign rs2_out = (rd_sel_in != 0 && rs2_sel_out == rd_sel_in) ? rd_data_in : regfile[rs2_sel_out];

assign pc_out = pc_in_buff;
assign pc_plus_4_out = pc_plus_4_in_buff;

// IF stage input buffers
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        regfile <= '{REGISTER_NUM{0}};
        pc_in_buff <= '0;
        pc_plus_4_in_buff <= '0;
        ir_buff <= NOP;
    end else begin
        if (rd_sel_in != 0) begin
            regfile[rd_sel_in] <= rd_data_in;
        end

        if (flush_in) begin
            ir_buff <= NOP;
            pc_in_buff <= 0;
            pc_plus_4_in_buff <= 0;
        end else if (!stage_stall_in) begin
            ir_buff <= ir_in;
            pc_in_buff <= pc_in;
            pc_plus_4_in_buff <= pc_plus_4_in;
        end
    end
end

always_comb begin
    case (imm_sel)
        I_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};
        I2_TYPE: imm32_out = {27'h0000000, ir_buff.b[24:20]};
        S_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:25], ir_buff.b[11:7]};
        B_TYPE:  imm32_out = {{20{ir_buff.b[31]}}, ir_buff.b[7], ir_buff.b[30:25], ir_buff.b[11:8], 1'b0};
        U_TYPE:  imm32_out = {ir_buff.b[31], ir_buff.b[30:12], 12'b0};
        J_TYPE:  imm32_out = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};
        default: imm32_out = '0;
    endcase  
end

always_comb begin
    // Set signals to have no side effect by default
    instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
    instr_ex_out.branch_cond = COND_NE;
    instr_ex_out.mux1_sel = RS;
    instr_ex_out.mux2_sel = RS;
    instr_ex_out.alu_op = ADD_OP;
    instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
    instr_ex_out.load_store_width = WIDTH_I32;
    instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;
    rs1_sel_out = '0;
    rs2_sel_out = '0;
    rd_sel_out  = '0;
    illegal_inst = 1'b0;
    imm_sel = I_TYPE;

    case (ir_buff.r.opcode)
        LOAD: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
            instr_ex_out.load_store_width = ir_buff.r.funct3;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = '0;
            rd_sel_out  = ir_buff.r.rd;
        end

        STORE: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
            instr_ex_out.load_store_width = ir_buff.r.funct3;

            imm_sel = S_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
            rd_sel_out  = '0;
        end

        ALOP: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = RS;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
            rd_sel_out  = ir_buff.r.rd;

            case (ir_buff.r.funct3)
                3'b000: begin
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = ADD_OP;
                        7'b0100000: instr_ex_out.alu_op = SUB_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
                3'b001: instr_ex_out.alu_op = SLL_OP;
                3'b010: instr_ex_out.alu_op = SLT_OP;
                3'b011: instr_ex_out.alu_op = SLTU_OP;
                3'b100: instr_ex_out.alu_op = XOR_OP;
                3'b101: begin
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = SRL_OP;
                        7'b0100000: instr_ex_out.alu_op = SRA_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
                3'b110: instr_ex_out.alu_op = OR_OP;
                3'b111: instr_ex_out.alu_op = AND_OP;
            endcase
        end

        ALOP_IMM: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = 0;
            rd_sel_out  = ir_buff.r.rd;
        
            case (ir_buff.r.funct3)
                3'b000: instr_ex_out.alu_op = ADD_OP;
                3'b010: instr_ex_out.alu_op = SLT_OP;
                3'b011: instr_ex_out.alu_op = SLTU_OP;
                3'b100: instr_ex_out.alu_op = XOR_OP;
                3'b110: instr_ex_out.alu_op = OR_OP;
                3'b111: instr_ex_out.alu_op = AND_OP;
                3'b001: begin
                    imm_sel = I2_TYPE;
                    instr_ex_out.alu_op = SLL_OP;
                end
                3'b101: begin
                    imm_sel = I2_TYPE;
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = SRL_OP;
                        7'b0100000: instr_ex_out.alu_op = SRA_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
            endcase
        end
        
        AUIPC: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = OTHER;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
            rs1_sel_out = 0;
            rs2_sel_out = 0;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        LUI: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
            rs1_sel_out = 0;
            rs2_sel_out = 0;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        BRANCH: begin
            instr_ex_out.branch_jal_sel = BRANCH_INSTR;
            instr_ex_out.mux1_sel = OTHER;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;

            imm_sel = B_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
            rd_sel_out  = 0;       
                
            case (ir_buff.r.funct3)
                3'b000:  instr_ex_out.branch_cond = COND_EQ;
                3'b001:  instr_ex_out.branch_cond = COND_NE;
                3'b100:  instr_ex_out.branch_cond = COND_LT;
                3'b101:  instr_ex_out.branch_cond = COND_GE;
                3'b110:  instr_ex_out.branch_cond = COND_LTU;
                3'b111:  instr_ex_out.branch_cond = COND_GEU;
                default: illegal_inst = 1'b1;
            endcase
        end
        
        JALR: begin
            instr_ex_out.branch_jal_sel = JAL_INSTR;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_PC_PLUS_4;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = 0;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        JAL: begin
            instr_ex_out.branch_jal_sel = JAL_INSTR;
            instr_ex_out.mux1_sel = OTHER;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_PC_PLUS_4;

            imm_sel = J_TYPE;
            rs1_sel_out = 0;
            rs2_sel_out = 0;
            rd_sel_out  = ir_buff.r.rd;
        end

        default: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;

            rs1_sel_out = 0;
            rs2_sel_out = 0;
            rd_sel_out  = 0;

            illegal_inst = 1'b1;
        end
    endcase
end

endmodule
