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

module friscv_clock_divider #(
    // Divisor value WILL BE MULTIPLIED by 4 !!
    // Divisor value MUST BE >0 and fit in 30 bits
    // Example:  DIVISOR=1, clk_cpu_out= clk_extern_in/4, clk_mem_out=clk_extern_in/2 
//        parameter DIVISOR = 32'd5000
        parameter DIVISOR = 32'd1
)
(
    input logic clk_extern_in,
    output logic clk_cpu_out,
    output logic clk_mem_out,
    input logic cpu_clock_stop_in,
    output logic cpu_clock_stopped_out 
    );
    
    logic [31:0] counter = 0;
    logic clock_stop = 0;
        
    always_ff @(posedge clk_extern_in)
    begin
        counter <= counter + 1;
        if(counter >=  (((DIVISOR & 32'h3FFFFFFF)<<2) - 1)) 
            counter <= 0;           
        if (counter < (DIVISOR & 32'h3FFFFFFF)) begin
            clk_cpu_out <= 1'b1 & ~clock_stop;
            clk_mem_out <= 1'b1 & ~clock_stop;
        end
        else if (counter < (DIVISOR & 32'h3FFFFFFF)<<1)  begin
            clk_mem_out <= 1'b0;
        end
        else if (counter < ((DIVISOR & 32'h3FFFFFFF) + ((DIVISOR & 32'h3FFFFFFF)<<1))) begin
            clk_cpu_out <= 1'b0;
            clk_mem_out <= 1'b1 & ~clock_stop;
        end
        else begin
            clk_mem_out <= 1'b0;
            clock_stop<=cpu_clock_stop_in;
        end
    end
    
    always_comb begin
        cpu_clock_stopped_out = clock_stop;
    end  
    
endmodule