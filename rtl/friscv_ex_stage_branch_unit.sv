// (c) FER, HPC Architecture and Application Research Center, All rights reserved
// License and version info is listed in friscv_pkg.sv

/*
 * This module implements the branch unit of the EX stage, which is responsible for
 * evaluating branch conditions and determining whether a branch or jump (if not ENABLE_EARLY_JAL_JALR) is taken.
 * It asserts misaligned_out if the target address is not properly aligned, and the redirect should otherwise be taken.
 */

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_ex_stage_branch_unit (
    input  jump_sel_e    branch_jal_sel_in,
    input  branch_cond_e branch_cond_in,
    input  data_t        src1_in,
    input  data_t        src2_in,
    input  addr_t        target,
    output logic         branch_ok_out,
    output logic         misaligned_out
);

logic [DATA_WIDTH:0] w_sub;
logic  n, z, c, v;

// src1 + ~src2 + 1 = src1 - src2, infers CARRY4 chain
assign w_sub = {1'b0, src1_in} + {1'b0, ~src2_in} + (DATA_WIDTH+1)'(1);

assign misaligned_out = branch_ok_out && (target[1:0] != 2'b0);

always_comb begin
    n = w_sub[DATA_WIDTH-1];
    z = (src1_in == src2_in);
    c = w_sub[DATA_WIDTH];
    v = (src1_in[DATA_WIDTH-1] ^ src2_in[DATA_WIDTH-1]) & (src1_in[DATA_WIDTH-1] ^ w_sub[DATA_WIDTH-1]);

    case (branch_jal_sel_in)
        BRANCH_INSTR: begin
            case (branch_cond_in)     
                COND_EQ:     branch_ok_out = z;
                COND_NE:     branch_ok_out = !z;
                COND_ALWAYS: branch_ok_out = 1'b1;
                COND_LT:     branch_ok_out = n ^ v;
                COND_GE:     branch_ok_out = !(n ^ v);
                COND_LTU:    branch_ok_out = !c;
                COND_GEU:    branch_ok_out = c;
                default:     branch_ok_out = 1'b0;
            endcase
        end
        JAL_INSTR: begin
            if (ENABLE_EARLY_JAL_JALR) begin
                branch_ok_out = 1'b0;
            end else begin
                branch_ok_out = 1'b1;
            end
        end
        default: begin
            branch_ok_out = 1'b0;
        end
    endcase
end

endmodule
