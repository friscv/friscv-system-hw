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

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_wb_stage (
    input  logic         clk_in,
    input  logic         rst_n_in,

    // Stage control
    input  logic         stage_stall_in,

    // Inputs from MEM stage
    input  addr_t        pc_plus_4_in,
    input  data_t        alu_data_in,
    input  data_t        load_data_in,
    input  data_t        sc_res_in,
    input  wb_data_sel_e wb_data_sel_in,
    input  reg_addr_t    rd_sel_in,
    input  csr_addr_e    csr_sel_in,
    input  data_t        csr_data_in,
    input  data_t        csr_readback_in,
    input  logic         csr_en_in,
    input  logic         instr_valid_in,

    // Outputs to ID stage (regfile write, CSR write, instret)
    output data_t        rd_data_out,
    output reg_addr_t    rd_sel_out,
    output csr_addr_e    csr_sel_out,
    output data_t        csr_data_out,
    output logic         csr_en_out,
    output logic         instr_valid_out,
    output logic         inst_ret_out
);

addr_t        pc_plus_4_buff;
data_t        alu_data_buff;
data_t        load_data_buff;
data_t        sc_res_buff;
wb_data_sel_e wb_data_sel_buff;
reg_addr_t    rd_sel_buff;
csr_addr_e    csr_sel_buff;
data_t        csr_data_buff;
data_t        csr_readback_buff;
logic         csr_en_buff;
logic         instr_valid_buff;

always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        pc_plus_4_buff    <= 32'h0;
        alu_data_buff     <= 32'h0;
        load_data_buff    <= 32'h0;
        sc_res_buff       <= 32'h0;
        wb_data_sel_buff  <= WB_DATA_SEL_ALU;
        rd_sel_buff       <= 5'b0;
        csr_sel_buff      <= CSR_ZERO;
        csr_data_buff     <= 32'h0;
        csr_readback_buff <= 32'h0;
        csr_en_buff       <= 1'b0;
        instr_valid_buff  <= 1'b0;
    end else if (!stage_stall_in) begin
        pc_plus_4_buff    <= pc_plus_4_in;
        alu_data_buff     <= alu_data_in;
        load_data_buff    <= load_data_in;
        sc_res_buff       <= sc_res_in;
        wb_data_sel_buff  <= wb_data_sel_in;
        rd_sel_buff       <= rd_sel_in;
        csr_sel_buff      <= csr_sel_in;
        csr_data_buff     <= csr_data_in;
        csr_readback_buff <= csr_readback_in;
        csr_en_buff       <= csr_en_in;
        instr_valid_buff  <= instr_valid_in;
    end
end

assign rd_sel_out   = rd_sel_buff;
assign csr_sel_out  = csr_sel_buff;
assign csr_data_out = csr_data_buff;
assign csr_en_out   = csr_en_buff;
assign instr_valid_out = instr_valid_buff;
assign inst_ret_out = instr_valid_buff && !stage_stall_in;

// ============================================================
// Result mux
// ============================================================

always_comb begin
    case (wb_data_sel_buff)
        WB_DATA_SEL_PC_PLUS_4: rd_data_out = pc_plus_4_buff;
        WB_DATA_SEL_ALU:       rd_data_out = alu_data_buff;
        WB_DATA_SEL_MEM:       rd_data_out = load_data_buff;
        WB_DATA_SEL_SC_RES:    rd_data_out = sc_res_buff;
        WB_DATA_SEL_CSR:       rd_data_out = csr_readback_buff;
        default:               rd_data_out = 32'b0;
    endcase
end

endmodule
