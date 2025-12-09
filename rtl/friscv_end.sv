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

module friscv_end (
    input  logic                    clk_cpu_in,
    input  logic                    clk_mem_in,
    input  logic                    debug_mode_in,    

    input  logic [ADDR_WIDTH-1:0]   d_mem_addr_in,
    input  logic [DATA_WIDTH-1:0]   d_mem_data_in,
    input  logic                    d_mem_en_in,
    input  logic                    d_mem_wr_in,
    input logic                     rst_n_in,
    
    output logic                    end_signal_out
);

	
//new parameters:
int unsigned END_ADDRESS = 32'HFFC;
int unsigned ENDING = 32'H0017;
    
logic [ADDR_WIDTH-3:0] d_mem_addr_in_words;

logic end_sig = 0;

always_ff @(negedge clk_mem_in) begin
    if (~debug_mode_in) begin
        if (d_mem_addr_in == END_ADDRESS) begin                 
            if (~clk_cpu_in && d_mem_en_in) begin
                if (d_mem_wr_in) begin
                    if (d_mem_data_in == ENDING) begin
                        end_sig <= 1;
                    end
                end
            end
        end
    end
    
    if (~rst_n_in) begin
        end_sig <= 0;
    end
end

assign end_signal_out = end_sig;


endmodule