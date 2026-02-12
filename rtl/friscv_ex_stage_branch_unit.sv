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

module friscv_ex_stage_branch_unit (
    input  branch_jal_sel_t branch_jal_sel_in,
    input  branch_cond_t    branch_cond_in,
    input  data_t           src1_in,
    input  data_t           src2_in,
    output logic            branch_ok_out
);

logic [DATA_WIDTH:0] w_sub;
logic  n, z, c, v;

// src1 + ~src2 + 1 = src1 - src2, infers CARRY4 chain
assign w_sub = {1'b0, src1_in} + {1'b0, ~src2_in} + (DATA_WIDTH+1)'(1);

always_comb begin
    n = w_sub[DATA_WIDTH-1];
    z = (src1_in == src2_in);
    c = w_sub[DATA_WIDTH];
    v = (src1_in[DATA_WIDTH-1] ^ src2_in[DATA_WIDTH-1]) & (src1_in[DATA_WIDTH-1] ^ w_sub[DATA_WIDTH-1]);

    case (branch_jal_sel_in)
        BRANCH_INSTR: begin
            case (branch_cond_in)     
                COND_EQ:  branch_ok_out = z;
                COND_NE:  branch_ok_out = !z;
                COND_LT:  branch_ok_out = n ^ v;
                COND_GE:  branch_ok_out = !(n ^ v);
                COND_LTU: branch_ok_out = !c;
                COND_GEU: branch_ok_out = c;
                default:  branch_ok_out = 1'b0;
            endcase
        end
        JAL_INSTR: begin
            branch_ok_out = 1'b1;
        end
        default: begin
            branch_ok_out = 1'b0;
        end
    endcase
end

endmodule
