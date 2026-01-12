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

module priority_encoder #(
    parameter WIDTH = 4,
    parameter LSB = 0
) (
    input  logic [WIDTH-1:0]         i_vec,
    output logic [$clog2(WIDTH)-1:0] o_idx,
    output logic                     o_valid
);

always_comb begin
    o_idx   = '0;
    o_valid = 0;

    for (int i = 0; i < WIDTH; i++) begin
        if (i_vec[i]) begin
            o_idx   = $clog2(WIDTH)'(i);
            o_valid = 1;
            // Stop on lowest set bit if LSB has priority
            if (LSB) break;
        end
    end
end

endmodule
