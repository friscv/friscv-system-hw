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

module friscv_amo_unit (
    input  logic    i_clk,
    input  logic    i_rstn,

    // Requested atomic operation
    input  amo_op_e i_amo_op,

    // Core interface
    input  data_t   i_rs2_val,
    output data_t   o_core_load_data,
    output logic    o_core_wait,

    // External interface
    input  logic    i_mem_wait,
    output rw_cmd_e o_mem_rw,
    input  data_t   i_mem_load_data,
    output data_t   o_mem_store_data
);

typedef enum logic [1:0] {
    S_IDLE,
    S_LOAD,
    S_STORE
} state_e;

state_e r_state, w_next_state;
data_t  r_load_data;
data_t  w_load_data;  // r_load_data, or live rdata on the cycle the load completes
amo_op_e r_amo_op;
data_t   r_rs2_val;

// Use live rdata on load-completion cycle (r_load_data not yet updated),
// use the registered capture for all S_STORE cycles
assign w_load_data = (r_state == S_LOAD && !i_mem_wait) ? i_mem_load_data : r_load_data;

assign o_core_load_data = r_load_data;
assign o_core_wait = w_next_state != S_IDLE;

always_ff @(posedge i_clk) begin
    if (!i_rstn) begin
        r_state     <= S_IDLE;
        r_load_data <= 32'b0;
        r_amo_op    <= AMO_NONE;
        r_rs2_val   <= 32'b0;
    end else begin
        r_state <= w_next_state;

        // Freeze AMO op/operand for the whole LOAD-STORE sequence.
        if (r_state == S_IDLE && i_amo_op != AMO_NONE) begin
            r_amo_op  <= i_amo_op;
            r_rs2_val <= i_rs2_val;
        end

        if (w_next_state == S_IDLE)
            r_amo_op <= AMO_NONE;

        // Capture load data when load completes
        if (r_state == S_LOAD && !i_mem_wait) begin
            r_load_data <= i_mem_load_data;
        end
    end
end

// Calculate op result using w_load_data, which is stable throughout S_STORE
always_comb begin
    case (r_amo_op)
        AMO_NONE: o_mem_store_data = w_load_data;
        AMO_SWAP: o_mem_store_data = r_rs2_val;
        AMO_ADD:  o_mem_store_data = w_load_data + r_rs2_val;
        AMO_XOR:  o_mem_store_data = w_load_data ^ r_rs2_val;
        AMO_AND:  o_mem_store_data = w_load_data & r_rs2_val;
        AMO_OR:   o_mem_store_data = w_load_data | r_rs2_val;
        AMO_MIN:  o_mem_store_data = ($signed(w_load_data) < $signed(r_rs2_val)) ? w_load_data : r_rs2_val;
        AMO_MAX:  o_mem_store_data = ($signed(w_load_data) > $signed(r_rs2_val)) ? w_load_data : r_rs2_val;
        AMO_MINU: o_mem_store_data = (w_load_data < r_rs2_val) ? w_load_data : r_rs2_val;
        AMO_MAXU: o_mem_store_data = (w_load_data > r_rs2_val) ? w_load_data : r_rs2_val;
        default:  o_mem_store_data = w_load_data;
    endcase
end

// State transition logic
always_comb begin
    w_next_state = r_state;
    o_mem_rw = RW_IDLE;
    
    case (r_state)
        S_IDLE: begin
            if (i_amo_op != AMO_NONE) begin
                w_next_state = S_LOAD;
                o_mem_rw = RW_READ;
            end
        end
        S_LOAD: begin
            w_next_state = (i_mem_wait) ? S_LOAD : S_STORE;
            o_mem_rw = RW_READ;
        end
        S_STORE: begin
            w_next_state = (i_mem_wait) ? S_STORE : S_IDLE;
            o_mem_rw = RW_WRITE;
        end
        default: ;
    endcase
end

endmodule
