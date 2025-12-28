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

module friscv_pipeline_control(
    input  logic            clk_in,
    input  logic            rst_n_cpu_in,

    output logic            rst_n_if_out,
    output logic            rst_n_id_out,
    output logic            rst_n_ex_out,
    output logic            rst_id_wb_ok_out,
    
    // IF stage    
    output logic            stall_if_out,
    output logic            stall_id_out,
    output logic            stall_ex_out,
    output logic            stall_mem_out,
    output logic            flush_ex_out,
    output logic            jump_branch_out,

    // ID stage
    input  reg_addr_t       id_rs1_sel_in,
    input  reg_addr_t       id_rs2_sel_in,
    input  branch_jal_sel_t id_branch_jal_sel_in,

    // EX stage   
    input  reg_addr_t       ex_rd_sel_in,
    input  logic            branch_ok_in,

    // MEM stage
    input  reg_addr_t       mem_rd_sel_in,

    // Memory wait signals
    input  logic            if_wait_in,
    input  logic            mem_wait_in
);

logic [3:0] rst_buff;
logic [4:0] stall_buff;
logic       rst_id_wb_ok_buff;
logic       branch_ok_buff;
logic [1:0] jal_delay_buff;
logic       do_stall_prev;

logic rst_buff_0_in;
logic rst_buff_1_in;
logic rst_buff_2_in;

logic stall_if, stall_id, stall_ex, stall_mem;
logic flush_ex;

logic rst_id_wb_ok;
logic start_jal;

logic w_src_is_ex_dest, w_src_is_mem_dest;
logic mem_stall, hazard_stall, do_stall;

always_ff @(negedge clk_in) begin
    if (~rst_n_cpu_in) begin
        rst_buff          <= 0;
        stall_buff        <= 0;
        rst_id_wb_ok_buff <= 0;
        branch_ok_buff    <= 0;
        jal_delay_buff    <= 0;
        do_stall_prev     <= 0;
    end
    else begin
        rst_buff          <= {rst_buff[2], rst_buff_2_in, rst_buff_1_in, rst_buff_0_in};
        stall_buff        <= {flush_ex, stall_mem, stall_ex, stall_id, stall_if};
        rst_id_wb_ok_buff <= ~rst_buff_1_in;
        branch_ok_buff    <= branch_ok_in;
        jal_delay_buff    <= {jal_delay_buff[0], start_jal && ~branch_ok_buff};
        do_stall_prev     <= do_stall;
    end
end

always_comb begin
    rst_id_wb_ok_out = rst_id_wb_ok_buff;

    rst_n_if_out = rst_buff[0];
    rst_n_id_out = rst_buff[1];
    rst_n_ex_out = rst_buff[2];

    stall_if_out = stall_buff[0];
    stall_id_out = stall_buff[1];
    stall_ex_out = stall_buff[2];
    stall_mem_out= stall_buff[3];
    flush_ex_out = stall_buff[4];

    w_src_is_ex_dest  = (id_rs1_sel_in == ex_rd_sel_in)  || (id_rs2_sel_in == ex_rd_sel_in);
    w_src_is_mem_dest = (id_rs1_sel_in == mem_rd_sel_in) || (id_rs2_sel_in == mem_rd_sel_in);

    mem_stall    = if_wait_in || mem_wait_in;
    hazard_stall = (ex_rd_sel_in  != 0) && w_src_is_ex_dest ||
                   (mem_rd_sel_in != 0) && w_src_is_mem_dest;
    do_stall     = mem_stall || hazard_stall;

    stall_if = do_stall;
    stall_id = do_stall;
    stall_ex = mem_stall;
    stall_mem = mem_stall;

    flush_ex = hazard_stall && ~mem_stall;

    rst_buff_0_in = ~(jal_delay_buff[0] && ~branch_ok_in);
    rst_buff_1_in = rst_buff[0] && ~branch_ok_in && ~jal_delay_buff[0];
    rst_buff_2_in = rst_buff[1] && ~branch_ok_in && ~hazard_stall;
    
    // Wait until JAL is ready to execute due to possible DATA HAZARD and is not overridden by prior successful branch
    // Don't trigger start_jal if we're already processing a jump (jal_delay_buff != 0) to prevent double jump
    start_jal = id_branch_jal_sel_in == JAL_INSTR && ~stall_id && ~branch_ok_in && (jal_delay_buff == 0);
    jump_branch_out = branch_ok_buff || jal_delay_buff[1];
end
endmodule
