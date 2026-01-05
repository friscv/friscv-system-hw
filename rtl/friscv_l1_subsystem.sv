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

module friscv_l1_subsystem (
    input  logic       i_clk,
    input  logic       i_rstn,

    // Instruction Memory Interface
    input  addr_t      i_inst_addr,
    output data_t      o_inst_data,
    input  logic       i_inst_en,
    output logic       o_inst_wait,

    // Data Memory Interface
    input  addr_t      i_data_addr,
    input  mem_width_t i_data_size,
    input  data_t      i_data_wdata,
    output data_t      o_data_rdata,
    input  logic       i_data_en,
    input  logic       i_data_wr,
    output logic       o_data_wait,

    // External Interface
    output addr_t      o_mem_addr,
    output mem_width_t o_mem_size,
    output data_t      o_mem_wdata,
    input  data_t      i_mem_rdata,
    output rw_cmd_t    o_mem_rw,
    input  logic       i_mem_wait
);

// Grant signals from arbiter
logic w_data_grant;
logic w_inst_grant;

// When a master completes while the other is waiting, yield for one cycle
logic r_inst_yield;
logic r_data_yield;

always_ff @(posedge i_clk) begin
    if (~i_rstn) begin
        r_inst_yield <= 1'b0;
        r_data_yield <= 1'b0;
    end else begin
        // Mark if inst master completed while data was waiting
        r_inst_yield <= w_inst_grant && ~i_mem_wait && i_data_en;
        r_data_yield <= w_data_grant && ~i_mem_wait && i_inst_en;
    end
end

// Drop request for one cycle after completion with contention
logic w_inst_req, w_data_req;
assign w_inst_req = i_inst_en && !r_inst_yield;
assign w_data_req = i_data_en && !r_data_yield;

round_robin_arbiter #(.PORTS(2)) l2_arbiter (
    .i_clk       ( i_clk                        ),
    .i_rstn      ( i_rstn                       ),
    .i_req_vec   ( {w_data_req,   w_inst_req}   ),
    .o_grant_vec ( {w_data_grant, w_inst_grant} )
);

// Wait signal generation
// Wait is high when:
// 1. Master has a request but not granted, OR
// 2. Master has a request and is granted but downstream is waiting
always_comb begin
    o_inst_wait = i_inst_en && (!w_inst_grant || i_mem_wait);
    o_data_wait = i_data_en && (!w_data_grant || i_mem_wait);
end

// Forward granted master to bus
always_comb begin
    // Use address of the granted master
    o_mem_addr = (w_data_grant) ? i_data_addr : (w_inst_grant) ? i_inst_addr : '0;
    
    // Use i_data_size if data has grant, else use Word
    o_mem_size = (w_data_grant) ? i_data_size : WIDTH_I32;

    // Set write data if write-enabled master is granted
    o_mem_wdata = (w_data_grant) ? i_data_wdata : '0;

    // Both masters can passively read data
    o_inst_data  = i_mem_rdata;
    o_data_rdata = i_mem_rdata;
    
    // Set operation based on grant and memory stage request
    o_mem_rw = (w_data_grant &&  i_data_wr) ? RW_WRITE :
               (w_data_grant && !i_data_wr) ? RW_READ  :
               (w_inst_grant)               ? RW_READ  : RW_IDLE;
end

endmodule
