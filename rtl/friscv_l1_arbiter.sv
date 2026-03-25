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

module friscv_l1_arbiter (
    input  logic       i_clk,
    input  logic       i_rstn,

    // Instruction Memory Interface
    input  addr_t      i_inst_addr,
    output data_t      o_inst_data,
    input  logic       i_inst_en,
    output logic       o_inst_wait,

    // Data Memory Interface
    input  addr_t      i_data_addr,
    input  mem_width_e i_data_size,
    input  data_t      i_data_wdata,
    output data_t      o_data_rdata,
    input  logic       i_data_en,
    input  logic       i_data_wr,
    output logic       o_data_wait,
    input  amo_op_e    i_amo_op,

    // External Interface
    output addr_t      o_mem_addr,
    output mem_width_e o_mem_size,
    output data_t      o_mem_wdata,
    input  data_t      i_mem_rdata,
    output rw_cmd_e    o_mem_rw,
    input  logic       i_mem_wait,
    output amo_op_e    o_amo_op,
    output logic       o_grant_inst
);

// FSM States
typedef enum logic [1:0] {
    S_IDLE,
    S_GRANT_INST,
    S_GRANT_DATA
} state_t;

state_t state, next_state;
logic priority_flag; // 0=Inst, 1=Data

// FSM Update
always_ff @(posedge i_clk) begin
    if (!i_rstn) begin
        state <= S_IDLE;
        priority_flag <= 1'b0;
    end else begin
        state <= next_state;
        // Rotate priority on transaction completion
        if (state != S_IDLE && next_state == S_IDLE) begin
            priority_flag <= !priority_flag;
        end
    end
end

// Next State Logic
always_comb begin
    next_state = state;
    case (state)
        S_IDLE: begin
            if (i_data_en && i_inst_en) begin
                next_state = (priority_flag) ? S_GRANT_DATA : S_GRANT_INST;
            end else if (i_data_en) begin
                next_state = S_GRANT_DATA;
            end else if (i_inst_en) begin
                next_state = S_GRANT_INST;
            end
        end
        S_GRANT_INST: begin
            if (!i_mem_wait) next_state = S_IDLE;
        end
        S_GRANT_DATA: begin
            if (!i_mem_wait) next_state = S_IDLE;
        end
        default: ;
    endcase
end

// Output Logic
always_comb begin
    o_mem_addr  = 32'h0;
    o_mem_size  = WIDTH_I32;
    o_mem_wdata = 32'h0;
    o_mem_rw    = RW_IDLE;
    o_inst_wait = 1'b0;
    o_data_wait = 1'b0;
    o_amo_op    = AMO_NONE;

    case (state)
        S_IDLE: begin
            // If requesting, insert wait cycle for arbitration
            if (i_inst_en) o_inst_wait = 1'b1;
            if (i_data_en) o_data_wait = 1'b1;
        end
        S_GRANT_INST: begin
            o_mem_addr  = i_inst_addr;
            o_mem_size  = WIDTH_I32;
            o_mem_rw    = RW_READ;
            o_inst_wait = i_mem_wait;
            if (i_data_en) o_data_wait = 1'b1;
        end
        S_GRANT_DATA: begin
            o_mem_addr  = i_data_addr;
            o_mem_size  = i_data_size;
            o_mem_wdata = i_data_wdata;
            o_mem_rw    = i_data_wr ? RW_WRITE : RW_READ;
            o_data_wait = i_mem_wait;
            o_amo_op    = i_amo_op;
            if (i_inst_en) o_inst_wait = 1'b1;
        end
        default: ;
    endcase
end

assign o_inst_data  = i_mem_rdata;
assign o_data_rdata = i_mem_rdata;
assign o_grant_inst = (state == S_GRANT_INST);

endmodule
