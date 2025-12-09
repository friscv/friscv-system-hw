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

module friscv_if_stage(
// global inputs  
    input logic                     clk_in,

// stage control inputs
    input logic                     rst_n_in,
    input logic                     stage_stall_in,
    input logic                     jump_branch_in,
    
// inputs from EX stage
    input logic [ADDR_WIDTH-1:0]    jump_branch_addr_in,
 
 // outputs to ID stage
    output logic [ADDR_WIDTH-1:0]   pc_out,
    output logic [ADDR_WIDTH-1:0]   pc_plus_4_out,
    output logic [DATA_WIDTH-1:0]   ir_out,

//  instruction memory interface
    output logic [ADDR_WIDTH-1:0]   i_mem_addr_out,
    input  logic [DATA_WIDTH-1:0]   i_mem_data_in,
    output logic                    i_mem_en_out
);

// input registers, clk_in driven
logic [ADDR_WIDTH-1:0] pc_reg;


always_ff @(posedge clk_in) begin
    if (~rst_n_in) begin
        pc_reg <= (RESET_VEC-4);
    end else if (~stage_stall_in) begin
        if (jump_branch_in) begin
            pc_reg <= {jump_branch_addr_in[ADDR_WIDTH-1:2], 2'b00};
        end else begin
            pc_reg <= pc_plus_4_out;
        end
    end
end

always_comb begin
    pc_out = pc_reg;
    pc_plus_4_out = pc_reg + 4;
    i_mem_addr_out = pc_reg;
    ir_out = i_mem_data_in;
    if (~stage_stall_in) i_mem_en_out = 1;
    else i_mem_en_out = 0;
end

endmodule
