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

module branch_unit
  (
    input branch_jal_sel_t branch_jal_sel_in,
    input branch_cond_t branch_cond_in,
    input [DATA_WIDTH-1:0] src1_in,
    input [DATA_WIDTH-1:0] src2_in,
    output logic branch_ok_out
   );

    logic [DATA_WIDTH:0]     c_int;
    logic [DATA_WIDTH-1:0]   G_int, P_int;

    logic c_flag; // Carry
    logic v_flag; // Overflow
    logic z_flag; // Zero
    logic n_flag; // Negative

    // generate subtract unit
    genvar i;
    generate
    for (i=0; i<DATA_WIDTH; i=i+1) 
        begin
        assign G_int[i]   = src1_in[i] & ~src2_in[i];
        assign P_int[i]   = src1_in[i] | ~src2_in[i];
        assign c_int[i+1] = G_int[i] | (P_int[i] & c_int[i]);
        end
    endgenerate

    assign c_int[0] = 1'b1; 
    assign n_flag = src1_in[DATA_WIDTH-1] ^ ~src2_in[DATA_WIDTH-1] ^ c_int[DATA_WIDTH-1];
    assign z_flag = (src1_in == src2_in);
    assign c_flag = c_int[DATA_WIDTH];
    assign v_flag = c_int[DATA_WIDTH] ^ c_int[DATA_WIDTH-1];

    always_comb begin
        if (branch_jal_sel_in == BRANCH_INSTR) begin
            case (branch_cond_in)     
                COND_EQ:    branch_ok_out = z_flag;
                COND_NE:    branch_ok_out = ~z_flag;
                COND_LT:    branch_ok_out = n_flag ^ v_flag;
                COND_GE:    branch_ok_out = ~(n_flag ^ v_flag);
                COND_LTU:   branch_ok_out = ~c_flag;
                COND_GEU:   branch_ok_out = c_flag;
                default:    branch_ok_out = 0;
            endcase
        end else branch_ok_out = 0;
    end

endmodule