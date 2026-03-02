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
    
    input  logic      irq_in,
    input  logic      branch_ok_in,  // suppress interrupt when EX branch resolves same cycle

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
    input  data_t     rd_data_in,
    
    //Outputs and inputs for handling interrupts
    output addr_t   mtvec_out,
    output addr_t   mepc_out,
    output logic    interrupt_out,
    output logic    mret_id_out,
    
    input addr_t    pc_ex_in
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
imm_e      imm_sel;

// Control and Status Registers
typedef struct packed {
    data_t mstatus;
    data_t mtvec;
    data_t mepc;
} csr_t;

csr_t csr = '0;

csr_addr_e selected_csr;  // Extracted selected CSR from ir_buff
assign selected_csr = csr_addr_e'(ir_buff.b[31:20]);

logic csr_ro;  // Determine if csr is read-only
assign csr_ro = selected_csr[11:10] == 2'b11;

privilege_e csr_privilege;
assign csr_privilege = privilege_e'(selected_csr[9:8]);

// Interrupt signals
logic [1:0] r_mret_inhibit;

assign mtvec_out        = csr.mtvec;
assign mepc_out         = csr.mepc;

assign interrupt_out = irq_in && csr.mstatus[3] && (r_mret_inhibit == 2'b00) && !branch_ok_in;
assign mret_id_out = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.funct3 == 3'b000) && (selected_csr == 12'h302);

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
            ir_buff           <= NOP;
            pc_in_buff        <= 32'h0;
            pc_plus_4_in_buff <= 32'h0;
        end else if (!stage_stall_in) begin
            ir_buff <= ir_in;
            pc_in_buff <= pc_in;
            pc_plus_4_in_buff <= pc_plus_4_in;
        end
    end
end

// ============================================================
// CSR registers
// ============================================================
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if(!rst_n_in) begin
        csr            <= '0;
        r_mret_inhibit <= 2'b00;
    end else begin
        // Only advance countdown when pipeline is not stalled,
        if (mret_id_out)
            r_mret_inhibit <= 2'd2;
        else if (r_mret_inhibit != 2'b00 && !stage_stall_in)
            r_mret_inhibit <= r_mret_inhibit - 1;

        if(interrupt_out) begin
            csr.mepc       <= (|pc_in_buff) ? pc_in_buff : pc_in;
            csr.mstatus[3] <= 1'b0;
        end
        else if(mret_id_out) begin
            csr.mstatus[3] <= 1'b1;
        end
        else if(instr_ex_out.csr_wr_en && !stage_stall_in && !flush_in) begin
            case (instr_ex_out.csr_addr)
                CSR_MSTATUS:    csr.mstatus <= rs1_out;
                CSR_MTVEC:      csr.mtvec <= rs1_out;
                CSR_MEPC:       csr.mepc <= rs1_out;
                default: ;
            endcase
        end
    end
end

// ============================================================
// Immediate generation
// ============================================================

always_comb begin
    unique case (imm_sel)
        I_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};
        I2_TYPE: imm32_out = {27'h0, ir_buff.b[24:20]};
        S_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:25], ir_buff.b[11:7]};
        B_TYPE:  imm32_out = {{20{ir_buff.b[31]}}, ir_buff.b[7], ir_buff.b[30:25], ir_buff.b[11:8], 1'b0};
        U_TYPE:  imm32_out = {ir_buff.b[31], ir_buff.b[30:12], 12'b0};
        J_TYPE:  imm32_out = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};
        ZERO:    imm32_out = 32'h0;
        NEXT_PC: imm32_out = pc_plus_4_in_buff;
    endcase
end

// ============================================================
// Early JAL/JALR
// ============================================================

always_comb begin
    if (ENABLE_EARLY_JAL_JALR && !interrupt_out) begin
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
    instr_ex_out.amo_op = AMO_NONE;
    rs1_sel_out = 5'b0;
    rs2_sel_out = 5'b0;
    rd_sel_out  = 5'b0;
    illegal_inst = 1'b0;
    imm_sel = I_TYPE;
    instr_ex_out.csr_wr_en = 0;
    instr_ex_out.mret_en   = 0;
    instr_ex_out.csr_addr  = CSR_ZERO;

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
                    // BEQ x0, x0, <PC+4> to flush potentially modified fetched instruction
                    if (ENABLE_EXTENSION_ZIFENCEI) begin
                        instr_ex_out.branch_jal_sel = BRANCH_INSTR;
                        instr_ex_out.branch_cond = COND_EQ;
                        instr_ex_out.mux1_sel = RS;    // Branch address = x0 + next_pc
                        instr_ex_out.mux2_sel = OTHER;
                        imm_sel = NEXT_PC;
                        instr_ex_out.alu_op = ADD_OP;
                        instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
                    end else begin
                        illegal_inst = 1'b1;
                    end
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
                        instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;
                        instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
                        instr_ex_out.load_store_width = WIDTH_I32;
                        instr_ex_out.alu_op = ADD_OP;
                        instr_ex_out.mux1_sel = RS;
                        instr_ex_out.mux2_sel = OTHER;
                        imm_sel = ZERO;  // AMO has no offset, address = rs1 + 0
                        rd_sel_out  = ir_buff.r.rd;
                        rs2_sel_out = ir_buff.r.rs2;
                        rs1_sel_out = ir_buff.r.rs1;

                        case (ir_buff.r.funct7[6:2])
                            5'b00011: begin  // SC.W
                                instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
                                instr_ex_out.conditional = 1'b1;
                                instr_ex_out.wb_data_sel = WB_DATA_SEL_SC_RES;
                            end
                            5'b00010: instr_ex_out.reserve = 1'b1;     // LR.W
                            5'b00001: instr_ex_out.amo_op = AMO_SWAP;  // AMOSWAP.W
                            5'b00000: instr_ex_out.amo_op = AMO_ADD;   // AMOADD.W
                            5'b00100: instr_ex_out.amo_op = AMO_XOR;   // AMOXOR.W
                            5'b01100: instr_ex_out.amo_op = AMO_AND;   // AMOAND.W
                            5'b01000: instr_ex_out.amo_op = AMO_OR;    // AMOOR.W
                            5'b10000: instr_ex_out.amo_op = AMO_MIN;   // AMOMIN.W
                            5'b10100: instr_ex_out.amo_op = AMO_MAX;   // AMOMAX.W
                            5'b11000: instr_ex_out.amo_op = AMO_MINU;  // AMOMINU.W
                            5'b11100: instr_ex_out.amo_op = AMO_MAXU;  // AMOMAXU.W
                            default:  illegal_inst = 1'b1;
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
        
        SYSTEM: begin
            instr_ex_out.branch_jal_sel = BRANCH_JAL_NONE;
            instr_ex_out.mux1_sel = RS;
            instr_ex_out.mux2_sel = RS;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;
            
            instr_ex_out.csr_wr_en = 0;
            instr_ex_out.mret_en   = 0;
            instr_ex_out.csr_addr  = selected_csr;
            
            case (ir_buff.r.funct3)
                3'b000: begin // mret
                    if (selected_csr == 12'h302) begin
                        instr_ex_out.mret_en = 1;
                    end
                end
                3'b001: begin // csrw
                    instr_ex_out.csr_wr_en = 1;
                    rs1_sel_out = ir_buff.r.rs1;
                    rd_sel_out  = ir_buff.r.rd;
                end
                default: ;
            endcase
            imm_sel = I_TYPE;
        end

        default: begin
            illegal_inst = 1'b1;
        end
    endcase
end

endmodule
