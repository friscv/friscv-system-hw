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
    input  logic           rst_n_in,

    // Stage control signals
    input  logic           stage_stall_in,
    input  logic           stage_flush_in,
  
    // Inputs from ID stage 
    input  addr_t          pc_in,
    input  addr_t          pc_plus_4_in,
    input  data_t          rs1_in,
    input  data_t          rs2_in,
    input  data_t          imm32_in,
    input  data_t          csr_in,
    input  reg_addr_t      rd_sel_in,
    input  reg_addr_t      rs1_sel_in,
    input  reg_addr_t      rs2_sel_in,
    input  instr_ex_t      instr_ex_in,

    // Outputs to MEM stage
    output addr_t          pc_plus_4_out,
    output data_t          alu_data_out,
    output reg_addr_t      rd_sel_out,
    output data_t          store_data_out,
    output mem_instr_sel_e mem_instr_sel_out,
	output mem_width_e     load_store_width_out,
    output wb_data_sel_e   wb_data_sel_out,
    output logic           reserve_out,
    output logic           conditional_out,
    output amo_op_e        amo_op_out,
    output csr_addr_e      csr_sel_out,
    output data_t          csr_readback_out,
    output logic           csr_en_out,
    output logic           instr_valid_out,

    // Outputs to control logic
    output logic           branch_ok_out,

    // TLB flush
    output logic           flush_tlb_out,
    output logic [19:0]    flush_vpn_out,
    output logic           flush_vpn_en_out,
    output logic [8:0]     flush_asid_out,
    output logic           flush_asid_en_out
);

// Input registers
addr_t pc_buff;
addr_t pc_plus_4_buff;
data_t rs1_buff;
data_t rs2_buff;
data_t imm32_buff;
data_t csr_buff;

reg_addr_t rd_sel_buff;
reg_addr_t rs1_sel_buff;
reg_addr_t rs2_sel_buff;
instr_ex_t instr_buff;

friscv_ex_stage_branch_unit branch_unit (
    .branch_jal_sel_in ( instr_buff.branch_jal_sel ),
    .branch_cond_in    ( instr_buff.branch_cond    ),
    .src1_in           ( rs1_buff                  ),
    .src2_in           ( rs2_buff                  ),
    .branch_ok_out     ( branch_ok_out             )
);

// ============================================================
// Input capture
// ============================================================

always_ff @(posedge clk_in) begin
    if (!rst_n_in) begin
        pc_plus_4_buff <= 32'h0;
        pc_buff      <= 32'h0;
        rs1_buff     <= 32'h0;
        rs2_buff     <= 32'h0;
        imm32_buff   <= 32'h0;
        csr_buff     <= 32'h0;
        rd_sel_buff  <= 5'b0;
        rs1_sel_buff <= 5'b0;
        rs2_sel_buff <= 5'b0;
        instr_buff   <= NOP_CTRL;
    end else if (!stage_stall_in) begin
        if (stage_flush_in || branch_ok_out) begin
            pc_buff     <= 32'h0;
            rd_sel_buff <= 5'b0;
            instr_buff  <= NOP_CTRL;
        end else begin
            pc_plus_4_buff <= pc_plus_4_in;
            pc_buff        <= pc_in;
            rs1_buff       <= rs1_in;
            rs2_buff       <= rs2_in;
            imm32_buff     <= imm32_in;
            csr_buff       <= csr_in;
            rd_sel_buff    <= rd_sel_in;
            rs1_sel_buff   <= rs1_sel_in;
            rs2_sel_buff   <= rs2_sel_in;
            instr_buff     <= instr_ex_in;
        end
    end
end

// ============================================================
// Assign outputs
// ============================================================

assign pc_plus_4_out        = pc_plus_4_buff;
assign mem_instr_sel_out    = instr_buff.mem_instr_sel;
assign load_store_width_out = instr_buff.load_store_width;
assign wb_data_sel_out      = instr_buff.wb_data_sel;
assign reserve_out          = instr_buff.reserve;
assign conditional_out      = instr_buff.conditional;
assign amo_op_out           = instr_buff.amo_op;
assign rd_sel_out           = rd_sel_buff;
assign csr_sel_out          = instr_buff.csr_addr;
assign csr_readback_out     = csr_buff;
assign csr_en_out           = instr_buff.csr_op;
assign instr_valid_out      = instr_buff.instr_valid;
assign flush_tlb_out        = instr_buff.sfence_vma;
assign flush_vpn_out        = rs1_buff[31:12];
assign flush_vpn_en_out     = (rs1_sel_buff != 5'b0);
assign flush_asid_out       = rs2_buff[8:0];
assign flush_asid_en_out    = (rs2_sel_buff != 5'b0);

// ============================================================
// ALU input select
// ============================================================

data_t a_bus;
data_t b_bus;
data_t alu_input_a;
data_t alu_input_b;

always_comb begin
    case (instr_buff.a_bus_sel)
        RS1:     a_bus = rs1_buff;
        PC:      a_bus = pc_buff;
        RS1_SEL: a_bus = {27'b0, rs1_sel_buff};
        default: a_bus = 32'b0;
    endcase

    case (instr_buff.b_bus_sel)
        RS2:     b_bus = rs2_buff;
        IMM:     b_bus = imm32_buff;
        CSR:     b_bus = csr_buff;
        default: b_bus = 32'b0;
    endcase
end

assign alu_input_a = (instr_buff.invert_op_a) ? ~a_bus : a_bus;
assign alu_input_b = b_bus;

// ============================================================
// Execute operation
// ============================================================

always_comb begin
    case (instr_buff.alu_op)
        ADD_OP:  alu_data_out = alu_input_a + alu_input_b;
        SUB_OP:  alu_data_out = alu_input_a - alu_input_b;
        AND_OP:  alu_data_out = alu_input_a & alu_input_b;
        OR_OP:   alu_data_out = alu_input_a | alu_input_b;
        XOR_OP:  alu_data_out = alu_input_a ^ alu_input_b;
        SLL_OP:  alu_data_out = alu_input_a << alu_input_b[4:0];
        SRL_OP:  alu_data_out = alu_input_a >> alu_input_b[4:0];
        SRA_OP:  alu_data_out = $signed(alu_input_a) >>> alu_input_b[4:0];
        SLT_OP:  alu_data_out = {31'b0, $signed(alu_input_a) < $signed(alu_input_b)};
        SLTU_OP: alu_data_out = {31'b0, alu_input_a < alu_input_b};
        default: alu_data_out = 32'h0;
    endcase
end

// ============================================================
// Position store data
// ============================================================

always_comb begin
    case (instr_buff.load_store_width)
        3'b000: begin   // B
            case (alu_data_out[1:0]) 
                2'b00: store_data_out = {24'h0, rs2_buff[7:0]};
                2'b01: store_data_out = {16'h0, rs2_buff[7:0],  8'h0};
                2'b10: store_data_out = { 8'h0, rs2_buff[7:0], 16'h0};
                2'b11: store_data_out = {rs2_buff[7:0], 24'h0};
            endcase
        end
        3'b001: begin   // H
            if (alu_data_out[1]) store_data_out = {rs2_buff[15:0], 16'h0};
            else                 store_data_out = {16'h0, rs2_buff[15:0]};
        end
        3'b010:  store_data_out = rs2_buff; // W
        default: store_data_out = 32'h0;
    endcase
end

endmodule
