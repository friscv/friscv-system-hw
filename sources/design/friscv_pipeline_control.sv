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
// global inputs
    input logic                     clk_in,
    input logic                     rst_n_cpu_in,

// stage control outputs all    
    output logic rst_n_if_out, rst_n_id_out, rst_n_ex_out, rst_n_mem_out,
    output logic stall_if_out, stall_id_out, 
    output logic rst_id_wb_ok_out,     
// IF stage    

// stage control outputs
    output logic                     jump_branch_out,

// ID stage
    input logic [REG_SEL_WIDTH-1:0] id_rs1_sel_in,
    input logic [REG_SEL_WIDTH-1:0] id_rs2_sel_in,
    input branch_jal_sel_t          id_branch_jal_sel_in,

// EX stage   
    input logic [REG_SEL_WIDTH-1:0] ex_rd_sel_in,
    input logic branch_ok_in,

// MEM stage
    input logic [REG_SEL_WIDTH-1:0] mem_rd_sel_in
);

// internal registers for pipeline control
logic [3:0] rst_buff;
logic [1:0] stall_buff;
logic rst_id_wb_ok_buff;
logic branch_ok_buff;
logic [1:0] jal_delay_buff;

logic rst_buff_0_in;
logic rst_buff_1_in;
logic rst_buff_2_in;

logic stall_if;
logic stall_id;

logic rst_id_wb_ok;

logic jal_active;

// global pipeline controls

// reset
always_ff @(negedge clk_in) begin
    if (~rst_n_cpu_in) begin
        rst_buff <= 0;
        stall_buff <= 0;
        rst_id_wb_ok_buff <= 0;
        branch_ok_buff <= 0;
        jal_delay_buff <= 0;
    end
    else begin
        rst_buff <= {rst_buff[2],rst_buff_2_in,rst_buff_1_in,rst_buff_0_in};
        stall_buff <= {stall_id, stall_if};
        rst_id_wb_ok_buff <= rst_id_wb_ok || jal_delay_buff[0];
        branch_ok_buff <= branch_ok_in;
        jal_delay_buff <= {jal_delay_buff[0] ,jal_active && ~branch_ok_buff};
    end   
end


assign    rst_n_if_out = rst_buff[0]; 
assign    rst_n_id_out = rst_buff[1];
assign    rst_n_ex_out = rst_buff[2];
assign    rst_n_mem_out= rst_buff[3];

assign    stall_if_out = stall_buff[0]; 
assign    stall_id_out = stall_buff[1];

assign    rst_id_wb_ok_out = rst_id_wb_ok_buff;


always_comb
    stall_if = (((ex_rd_sel_in != 0) && ((id_rs1_sel_in == ex_rd_sel_in) || (id_rs2_sel_in == ex_rd_sel_in))) || 
                ((mem_rd_sel_in != 0) && ((id_rs1_sel_in == mem_rd_sel_in) || (id_rs2_sel_in == mem_rd_sel_in))));
    
always_comb
    stall_id = (((ex_rd_sel_in != 0) && ((id_rs1_sel_in == ex_rd_sel_in) || (id_rs2_sel_in == ex_rd_sel_in))) || 
                ((mem_rd_sel_in != 0) && ((id_rs1_sel_in == mem_rd_sel_in) || (id_rs2_sel_in == mem_rd_sel_in))));

always_comb    
    rst_id_wb_ok = branch_ok_in || jal_delay_buff [0] || jal_active;

always_comb
    rst_buff_0_in = ~(jal_active && ~branch_ok_in);

always_comb
    rst_buff_1_in = rst_buff[0] && ~branch_ok_in && ~jal_active;

always_comb    
    rst_buff_2_in = rst_buff[1] && ~branch_ok_in &&
       ~(((ex_rd_sel_in != 0) && ((id_rs1_sel_in == ex_rd_sel_in) || (id_rs2_sel_in == ex_rd_sel_in))) || 
        ((mem_rd_sel_in != 0) && ((id_rs1_sel_in == mem_rd_sel_in) || (id_rs2_sel_in == mem_rd_sel_in))));
    
always_comb
    // Wait until JAL is ready to execute due to possible DATA HAZARD and is not overridden by prior successful branch
    jal_active = (id_branch_jal_sel_in == JAL_INSTR && ~stall_id && ~branch_ok_in);

always_comb
    // Next PC control
    jump_branch_out = branch_ok_buff || jal_delay_buff [1];    
    
endmodule
