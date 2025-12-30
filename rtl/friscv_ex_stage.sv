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

module friscv_ex_stage (
    input  logic           clk_in,

    // Stage control inputs
    input  logic           rst_n_in,
    input  logic           stage_stall_in,
    input  logic           stage_flush_in,
  
    // Inputs from ID stage 
    input  addr_t          pc_in,
    input  addr_t          pc_plus_4_in,
    input  data_t          rs1_in,
    input  data_t          rs2_in,
    input  data_t          imm32_in,
    input  reg_addr_t      rd_sel_in,
    input  instr_ex_t      instr_ex_in,

    // Outputs to MEM stage 
    output addr_t          pc_plus_4_out,
    output data_t          alu_data_out,
    output reg_addr_t      rd_sel_out,
    output data_t          store_data_out,
    output mem_instr_sel_t mem_instr_sel_out,
	output mem_width_t     load_store_width_out,
    output wb_data_sel_t   wb_data_sel_out,

    // Outputs to control logic
    output logic              branch_ok_out
);

// Input registers
addr_t     pc_buff;
addr_t     pc_plus_4_buff;
data_t     rs1_buff;
data_t     rs2_buff;
data_t     imm32_buff;
reg_addr_t rd_sel_buff;
instr_ex_t instr_ex_buff;

// Duplicate detection
addr_t last_captured_pc;
logic  forwarded_to_mem;

// ALU inputs
data_t alu_input_a;
data_t alu_input_b;

branch_unit branch_unit (
    .branch_jal_sel_in ( instr_ex_buff.branch_jal_sel ),
    .branch_cond_in    ( instr_ex_buff.branch_cond    ),
    .src1_in           ( rs1_buff                     ),
    .src2_in           ( rs2_buff                     ),
    .branch_ok_out     ( branch_ok_out                )
);

// Stage inputs buffering
always_ff @(posedge clk_in) begin
    if (~rst_n_in) begin
        last_captured_pc <= 0;
        forwarded_to_mem <= 1;
    end
    
    if (~stage_stall_in) begin
        // Check if we're taking a branch THIS cycle
        // If so, ignore the instruction from ID since it's the wrong path
        // Also check for duplicate: same PC as before AND we didn't forward last time
        if (stage_flush_in || branch_ok_out || (pc_in == last_captured_pc && ~forwarded_to_mem)) begin
            pc_buff <= 0;
            pc_plus_4_buff <= 0;
            rs1_buff <= 0;
            rs2_buff <= 0;
            imm32_buff <= 0;
            rd_sel_buff <= 0;
            instr_ex_buff <= '{
                branch_jal_sel: BRANCH_JAL_NONE,
                branch_cond: COND_EQ,
                mux1_sel: RS,
                mux2_sel: RS,
                alu_op: ADD_OP,
                mem_instr_sel: MEM_INSTR_NONE,
                load_store_width: W,
                wb_data_sel: WB_DATA_SEL_ALU
            };
            forwarded_to_mem <= 0;
        end else begin
            pc_buff <= pc_in;
            pc_plus_4_buff <= pc_plus_4_in;
            rs1_buff <= rs1_in;
            rs2_buff <= rs2_in;
            imm32_buff <= imm32_in;
            rd_sel_buff <= rd_sel_in;
            instr_ex_buff <= instr_ex_in;
            last_captured_pc <= pc_in;
            forwarded_to_mem <= 1;
        end
    end else begin
        // Stalled - didn't forward to MEM
        forwarded_to_mem <= 0;
    end
end

always_comb begin
    pc_plus_4_out = pc_plus_4_buff;
    mem_instr_sel_out = instr_ex_buff.mem_instr_sel;
    load_store_width_out = instr_ex_buff.load_store_width;
    wb_data_sel_out = instr_ex_buff.wb_data_sel;
    rd_sel_out = rd_sel_buff;
end

always_comb begin
    if (instr_ex_buff.mux1_sel == RS) begin
        alu_input_a = rs1_buff;
    end else begin
        alu_input_a = pc_buff;
    end
    
    if (instr_ex_buff.mux2_sel == OTHER) begin
        alu_input_b = imm32_buff;
    end else begin
        alu_input_b = rs2_buff;
    end
end

always_comb begin
    case (instr_ex_buff.alu_op)
        ADD_OP:  alu_data_out = alu_input_a + alu_input_b;
        SUB_OP:  alu_data_out = alu_input_a - alu_input_b;
        AND_OP:  alu_data_out = alu_input_a & alu_input_b;
        OR_OP:   alu_data_out = alu_input_a | alu_input_b;
        XOR_OP:  alu_data_out = alu_input_a ^ alu_input_b;
        SLL_OP:  alu_data_out = alu_input_a << alu_input_b;
        SRL_OP:  alu_data_out = alu_input_a >> alu_input_b;
        SRA_OP:  alu_data_out = $signed(alu_input_a) >>> alu_input_b;
        SLT_OP:  alu_data_out = ($signed(alu_input_a) < $signed(alu_input_b));
        SLTU_OP: alu_data_out = (alu_input_a < alu_input_b);
        default: alu_data_out = 0;
    endcase
end

// Store data positioning
always_comb begin
    case (instr_ex_buff.load_store_width)
        3'b000: begin   //B
            case (alu_data_out[1:0]) 
                2'b00: store_data_out = {24'h000000, rs2_buff[7:0]};
                2'b01: store_data_out = {16'h0000, rs2_buff[7:0], 8'h00};
                2'b10: store_data_out = {8'h00, rs2_buff[7:0], 16'h0000};
                2'b11: store_data_out = {rs2_buff[7:0], 24'h000000};
            endcase
        end
        3'b001: begin   //H
            if (alu_data_out[1]) store_data_out = {rs2_buff[15:0], 16'h0000};
            else                 store_data_out = {16'h0000, rs2_buff[15:0]};
        end
        3'b010:  store_data_out = rs2_buff; //W
        default: store_data_out = 0;
    endcase
end

endmodule
