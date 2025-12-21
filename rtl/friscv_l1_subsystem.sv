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

module friscv_l1_subsystem(
    input  logic i_clk,
    input  logic i_rstn,

    // Instruction Memory Interface
    input  logic [ADDR_WIDTH-1:0] i_inst_addr,
    output logic [DATA_WIDTH-1:0] o_inst_data,
    input  logic                  i_inst_en,
    output logic                  o_inst_wait,

    // Data Memory Interface
    input  logic [ADDR_WIDTH-1:0] i_data_addr,
    input  logic [DATA_WIDTH-1:0] i_data_wdata,
    output logic [DATA_WIDTH-1:0] o_data_rdata,
    input  logic                  i_data_en,
    input  logic                  i_data_wr,
    output logic                  o_data_wait,

    // External Interface
    output logic [2:0]            o_mem_size,
    output logic [ADDR_WIDTH-1:0] o_mem_addr,
    output logic [DATA_WIDTH-1:0] o_mem_wdata,
    input  logic [DATA_WIDTH-1:0] i_mem_rdata,
    output logic [1:0]            o_mem_rw,
    input  logic                  i_mem_wait
);

// Grant signals from arbiter
logic w_data_grant;
logic w_inst_grant;

round_robin_arbiter #(.PORTS(2)) l2_arbiter (
    .i_clk       (i_clk),
    .i_rstn      (i_rstn),
    .i_req_vec   ({i_data_en, i_inst_en}),
    .o_grant_vec ({w_data_grant, w_inst_grant})
);

// Wait signal generation
// Wait is high when:
// 1. Master has a request but not granted, OR
// 2. Master has a request and is granted but downstream is waiting
always_comb begin
    // Instruction wait: not granted, or granted but memory waiting
    o_inst_wait = i_inst_en && (!w_inst_grant || i_mem_wait);

    // Data wait: not granted, or granted but memory waiting  
    o_data_wait = i_data_en && (!w_data_grant || i_mem_wait);
end

// Forward granted master to bus
always_comb begin
    o_mem_size = AXI_SIZE_WORD;
    
    // Both masters can passively read data
    o_inst_data  = i_mem_rdata;
    o_data_rdata = i_mem_rdata;

    // Use address of the granted master
    o_mem_addr = (w_data_grant) ? i_data_addr  : (w_inst_grant) ? i_inst_addr : '0;
    
    // Set write data if write-enabled master is granted
    o_mem_wdata = (w_data_grant) ? i_data_wdata : '0;
    
    // Set operation based on grant and memory stage request
    o_mem_rw = (w_data_grant &&  i_data_wr) ? RW_WRITE :
               (w_data_grant && !i_data_wr) ? RW_READ  :
               (w_inst_grant)               ? RW_READ  : RW_IDLE;
end

endmodule
