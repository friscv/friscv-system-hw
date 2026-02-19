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
    input  logic      rst_n_in,

    // Stage control signals
    input  logic      flush_in,
    input  logic      stage_stall_in,

    // Outputs to control logic
    output reg_addr_t rs1_sel_out,
    output reg_addr_t rs2_sel_out,
    output reg_addr_t rd_sel_out,

    output logic      jal_ok_out,
    output addr_t     jal_target_out,

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

data_t regfile [REGISTER_NUM];

// Initialize regfile to prevent X in simulation
genvar g;
generate
    for (g = 0; g < REGISTER_NUM; g++) begin : init_regfile
        initial regfile[g] = '0;
    end
endgenerate

instr_op_t ir_buff;
addr_t     pc_in_buff;
addr_t     pc_plus_4_in_buff;
imm_t      imm_sel;

// MEM-EX forwarding
assign rs1_out = (rd_sel_in != 0 && rs1_sel_out == rd_sel_in) ? rd_data_in : regfile[rs1_sel_out];
assign rs2_out = (rd_sel_in != 0 && rs2_sel_out == rd_sel_in) ? rd_data_in : regfile[rs2_sel_out];

assign pc_out = pc_in_buff;
assign pc_plus_4_out = pc_plus_4_in_buff;

// ============================================================
// Input capture
// ============================================================

always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        // Do not reset regfile to synthesize as distributed RAM
        pc_in_buff <= 32'h0;
        pc_plus_4_in_buff <= 32'h0;
        ir_buff <= NOP;
    end else begin
        if (rd_sel_in != 0) begin
            regfile[rd_sel_in] <= rd_data_in;
        end

        if (flush_in) begin
            ir_buff <= NOP;
            pc_in_buff <= 32'h0;
            pc_plus_4_in_buff <= 32'h0;
        end else if (!stage_stall_in) begin
            ir_buff <= ir_in;
            pc_in_buff <= pc_in;
            pc_plus_4_in_buff <= pc_plus_4_in;
        end
    end
end

// ============================================================
// Immediate generation
// ============================================================

always_comb begin
    case (imm_sel)
        I_TYPE:    imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};
        I2_TYPE:   imm32_out = {27'h0, ir_buff.b[24:20]};
        S_TYPE:    imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:25], ir_buff.b[11:7]};
        B_TYPE:    imm32_out = {{20{ir_buff.b[31]}}, ir_buff.b[7], ir_buff.b[30:25], ir_buff.b[11:8], 1'b0};
        U_TYPE:    imm32_out = {ir_buff.b[31], ir_buff.b[30:12], 12'b0};
        J_TYPE:    imm32_out = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};
        ZERO_TYPE: imm32_out = 32'h0;
        default:   imm32_out = 32'h0;
    endcase
end

// ============================================================
// Early JAL/JALR
// ============================================================

always_comb begin
    if (ENABLE_EARLY_JAL_JALR) begin
        addr_t jal_target_base;
        data_t jal_imm;
        jal_target_base = 32'h0;
        jal_imm = 32'h0;

        case (ir_buff.r.opcode)
            JALR: begin
                jal_ok_out = 1'b1;
                jal_target_base = (rd_sel_in != 0 && ir_buff.r.rs1 == rd_sel_in) ? rd_data_in : regfile[ir_buff.r.rs1];
                jal_imm = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};  // I-type immediate
                jal_target_out = (jal_target_base + jal_imm) & ~32'h1;
            end
            JAL: begin
                jal_ok_out = 1'b1;
                jal_imm = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};  // J-type immediate
                jal_target_out = pc_in_buff + jal_imm;
            end
            default: begin
                jal_ok_out = 1'b0;
                jal_target_out = 32'h0;
            end
        endcase
    end else begin
        jal_ok_out = 1'b0;
        jal_target_out = 32'h0;
    end
end

// ============================================================
// Instruction decoding
// ============================================================

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
    instr_ex_out.reserve = 1'b0;
    instr_ex_out.conditional = 1'b0;
    rs1_sel_out = 5'b0;
    rs2_sel_out = 5'b0;
    rd_sel_out  = 5'b0;
    illegal_inst = 1'b0;
    imm_sel = I_TYPE;

    case (ir_buff.r.opcode)
        LOAD: begin
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
            instr_ex_out.load_store_width = ir_buff.r.funct3;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rd_sel_out  = ir_buff.r.rd;
        end

        MISC_MEM: begin
            case (ir_buff.r.funct3)
                3'b000: begin  // FENCE
                end
                3'b001: begin  // FENCE.I
                    illegal_inst = !ENABLE_EXTENSION_ZIFENCEI;
                end
                default: begin
                    illegal_inst = 1'b1;
                end
            endcase
        end

        STORE: begin
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
            instr_ex_out.load_store_width = ir_buff.r.funct3;

            imm_sel = S_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
        end

        AMO: begin
            if (ENABLE_EXTENSION_A) begin
                case (ir_buff.r.funct3)
                    3'b010: begin  // RV32A Standard Extension instructions
                        rd_sel_out  = ir_buff.r.rd;
                        rs2_sel_out = ir_buff.r.rs2;
                        rs1_sel_out = ir_buff.r.rs1;

                        case (ir_buff.r.funct7[6:2])
                            5'b00010: begin  // LR.W
                                instr_ex_out.mux1_sel = RS;
                                instr_ex_out.mux2_sel = RS;
                                instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
                                instr_ex_out.load_store_width = WIDTH_I32;
                                instr_ex_out.reserve = 1'b1;
                                rs2_sel_out = 5'b0;
                                instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;
                            end
                            5'b00011: begin  // SC.W
                                instr_ex_out.mux1_sel = RS;
                                instr_ex_out.mux2_sel = OTHER;
                                instr_ex_out.alu_op = ADD_OP;
                                instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
                                instr_ex_out.load_store_width = WIDTH_I32;
                                instr_ex_out.conditional = 1'b1;
                                imm_sel = ZERO_TYPE;  // AMO has no offset, address = rs1 + 0
                                instr_ex_out.wb_data_sel = WB_DATA_SEL_SC_RES;
                            end
                            5'b00001: begin  // AMOSWAP.W
                            end
                            5'b00000: begin  // AMOADD.W
                            end
                            5'b00100: begin  // AMOXOR.W
                            end
                            5'b01100: begin  // AMOAND.W
                            end
                            5'b01000: begin  // AMOOR.W
                            end
                            5'b10000: begin  // AMOMIN.W
                            end
                            5'b10100: begin  // AMOMAX.W
                            end
                            5'b11000: begin  // AMOMINU.W
                            end
                            5'b11100: begin  // AMOMAXU.W
                            end
                            default:  begin
                                illegal_inst = 1'b1;
                                rd_sel_out = 5'b0;
                                rs1_sel_out = 5'b0;
                                rs2_sel_out = 5'b0;
                            end
                        endcase
                    end
                    default: begin
                        illegal_inst = 1'b1;
                    end
                endcase
            end else begin
                illegal_inst = 1'b1;
            end
        end

        OP: begin
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

        OP_IMM: begin
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
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
            instr_ex_out.mux1_sel = OTHER;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        LUI: begin
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = OTHER;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
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
            rd_sel_out  = ir_buff.r.rd;
        end

        default: begin
            illegal_inst = 1'b1;
        end
    endcase
end

endmodule
