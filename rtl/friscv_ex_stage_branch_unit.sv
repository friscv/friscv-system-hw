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

module branch_unit (
    input  branch_jal_sel_t branch_jal_sel_in,
    input  branch_cond_t    branch_cond_in,
    input  data_t           src1_in,
    input  data_t           src2_in,
    output logic            branch_ok_out
);

data_t gen, prop, carry;
logic  n, z, c, v;  // Negative, Zero, Carry, Overflow

genvar i;
generate
    for (i = 0; i < DATA_WIDTH; i++) begin
        assign gen[i]   = src1_in[i] & ~src2_in[i];
        assign prop[i]  = src1_in[i] | ~src2_in[i];
        assign carry[i] = (i == 0) ? gen[i] | prop[i] : gen[i] | (prop[i] & carry[i-1]);
    end
endgenerate

always_comb begin
    n = src1_in[DATA_WIDTH-1] ^ ~src2_in[DATA_WIDTH-1] ^ carry[DATA_WIDTH-2];
    z = (src1_in == src2_in);
    c = carry[DATA_WIDTH-1];
    v = carry[DATA_WIDTH-1] ^ carry[DATA_WIDTH-2];

    case (branch_jal_sel_in)
        BRANCH_INSTR: begin
            case (branch_cond_in)     
                COND_EQ:  branch_ok_out = z;
                COND_NE:  branch_ok_out = ~z;
                COND_LT:  branch_ok_out = n ^ v;
                COND_GE:  branch_ok_out = ~(n ^ v);
                COND_LTU: branch_ok_out = ~c;
                COND_GEU: branch_ok_out = c;
                default:  branch_ok_out = 0;
            endcase
        end
        JAL_INSTR: begin
            branch_ok_out = 1;
        end
        default: begin
            branch_ok_out = 0;
        end
    endcase
end

endmodule
