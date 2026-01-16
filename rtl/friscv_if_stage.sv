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

module friscv_if_stage (
    input  logic  clk_in,

    // Stage control inputs
    input  logic  rst_n_in,
    input  logic  flush_in,
    input  logic  stage_stall_in,
    input  logic  jump_branch_in,
    input  logic  i_mem_wait_in,

    // Inputs from EX stage
    input  addr_t jump_branch_addr_in,
 
    // Outputs to ID stage
    output addr_t pc_out,
    output addr_t pc_plus_4_out,
    output inst_t ir_out,

    // Instruction memory interface
    output addr_t i_mem_addr_out,
    input  inst_t i_mem_data_in,
    output logic  i_mem_en_out
);

addr_t pc_reg;
inst_t ir_buff;
logic  r_fetch_active;

always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        pc_reg         <= RESET_VEC;
        r_fetch_active <= 1'b1;
        ir_buff        <= NOP;
    end else begin
        if (flush_in || jump_branch_in) begin
            pc_reg         <= jump_branch_in ? {jump_branch_addr_in[ADDR_WIDTH-1:2], 2'b00} : RESET_VEC;
            r_fetch_active <= 1'b1;
            ir_buff        <= NOP;
        end else if (!stage_stall_in) begin
            pc_reg         <= pc_plus_4_out;
            r_fetch_active <= 1'b1;
        end else if (r_fetch_active && !i_mem_wait_in) begin
            r_fetch_active <= 1'b0;
            ir_buff        <= i_mem_data_in;
        end 
    end
end

always_comb begin
    pc_out = pc_reg;
    pc_plus_4_out = pc_reg + 4;
    i_mem_addr_out = pc_reg;
    i_mem_en_out = r_fetch_active;

    if (r_fetch_active) begin
        if (i_mem_wait_in) begin
            ir_out = NOP;
        end else begin
            ir_out = i_mem_data_in;
        end
    end else begin
        ir_out = ir_buff;
    end
end

endmodule
