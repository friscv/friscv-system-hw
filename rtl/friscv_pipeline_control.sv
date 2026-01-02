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

module friscv_pipeline_control (
    input  logic      clk_in,
    input  logic      rst_n_cpu_in,

    output logic      rst_n_if_out,
    output logic      rst_n_id_out,
    output logic      rst_id_wb_ok_out,
    
    // IF stage    
    output logic      stall_if_out,
    output logic      stall_id_out,
    output logic      stall_ex_out,
    output logic      stall_mem_out,
    output logic      flush_ex_out,
    output logic      jump_branch_out,

    // ID stage
    input  reg_addr_t id_rs1_sel_in,
    input  reg_addr_t id_rs2_sel_in,

    // EX stage   
    input  reg_addr_t ex_rd_sel_in,
    input  logic      branch_ok_in,

    // MEM stage
    input  reg_addr_t mem_rd_sel_in,

    // Memory wait signals
    input  logic      if_wait_in,
    input  logic      mem_wait_in
);

logic rst_if_id_in, rst_ex_in;
logic src_is_ex_dest, src_is_mem_dest;
logic mem_stall, hazard_stall;

always_ff @(negedge clk_in) begin
    if (~rst_n_cpu_in) begin
        {rst_n_if_out, rst_n_id_out} <= '0;
        {stall_if_out, stall_id_out, stall_ex_out, stall_mem_out} <= '0;
        flush_ex_out     <= 0;
        rst_id_wb_ok_out <= 0;
        jump_branch_out  <= 0;
    end else begin
        rst_n_if_out <= rst_if_id_in;
        rst_n_id_out <= rst_if_id_in;

        stall_if_out  <= mem_stall || hazard_stall;
        stall_id_out  <= mem_stall || hazard_stall;
        stall_ex_out  <= mem_stall;
        stall_mem_out <= mem_stall;
        flush_ex_out  <= hazard_stall && ~mem_stall;

        rst_id_wb_ok_out <= ~rst_if_id_in;
        jump_branch_out  <= branch_ok_in;
    end
end

always_comb begin
    mem_stall    = if_wait_in || mem_wait_in;
    hazard_stall = (ex_rd_sel_in != 0) && ((id_rs1_sel_in == ex_rd_sel_in)  || (id_rs2_sel_in == ex_rd_sel_in));
    rst_if_id_in = rst_n_cpu_in && ~branch_ok_in;
end

endmodule
