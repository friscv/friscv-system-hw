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
    // Control signals
    output logic      flush_if_out,
    output logic      flush_id_out,
    output logic      flush_ex_out,
    output logic      stall_if_out,
    output logic      stall_id_out,
    output logic      stall_ex_out,
    output logic      stall_mem_out,

    // IF stage
    output logic      jump_ok_out,
    output addr_t     jump_target_out,

    // ID stage
    input  reg_addr_t id_rs1_sel_in,
    input  reg_addr_t id_rs2_sel_in,
    input  logic      jal_ok_in,
    input  addr_t     jal_target_in,
    input  logic      id_csr_en_in,
    input  csr_addr_e id_csr_sel_in,

    // EX stage
    input  reg_addr_t ex_rd_sel_in,
    input  logic      branch_ok_in,
    input  addr_t     branch_target_in,
    input  logic      ex_csr_en_in,
    input  csr_addr_e ex_csr_sel_in,

    // MEM stage
    input  logic      mem_csr_en_in,
    input  csr_addr_e mem_csr_sel_in,

    // Memory wait signals
    input  logic      if_wait_in,
    input  logic      mem_wait_in,
    
    // Interrupts
    input logic       interrupt_in,
    input logic       mret_in
);

logic reg_hazard, csr_hazard;
logic mem_stall, hazard_stall;

// Early JAL/JALR must be suppressed when
//  1) EX cannot capture the decoded instruction (mem_stall) or
//  2) JALR's rs1 has a data hazard with EX (hazard_stall)
logic effective_jal;

always_comb begin
    mem_stall = if_wait_in || mem_wait_in;
    
    reg_hazard = (ex_rd_sel_in != 0) && ((id_rs1_sel_in == ex_rd_sel_in) || (id_rs2_sel_in == ex_rd_sel_in));
    csr_hazard = (id_csr_en_in && ex_csr_en_in  && (id_csr_sel_in == ex_csr_sel_in)) ||
                 (id_csr_en_in && mem_csr_en_in && (id_csr_sel_in == mem_csr_sel_in));

    hazard_stall = reg_hazard || csr_hazard;

    effective_jal = jal_ok_in && !mem_stall && !hazard_stall;

    stall_if_out  = mem_stall || hazard_stall;
    stall_id_out  = mem_stall || hazard_stall;
    stall_ex_out  = mem_stall;
    stall_mem_out = mem_stall;

    flush_if_out = branch_ok_in || effective_jal || interrupt_in || mret_in;
    flush_id_out = branch_ok_in || effective_jal || interrupt_in || mret_in;
    flush_ex_out = (hazard_stall && !mem_stall) || interrupt_in;

    jump_ok_out     = branch_ok_in || effective_jal;
    jump_target_out = (branch_ok_in) ? branch_target_in : jal_target_in;
end

endmodule
