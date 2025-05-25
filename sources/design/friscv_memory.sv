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

module friscv_memory #(
    parameter   ADDR_BEGIN = 0,
    parameter   MEM_SIZE = 1024  // IN WORDS
)
(
    input  logic                    clk_cpu_in,
    input  logic                    clk_mem_in,
    input  logic                    clk_debug_in,
    input  logic                    debug_mode_in,    
 
    input  logic [ADDR_WIDTH-1:0]   i_mem_addr_in,
    output logic [DATA_WIDTH-1:0]   i_mem_data_out,
    input  logic                    i_mem_en_in,
    
    input  logic [ADDR_WIDTH-1:0]   d_mem_addr_in,
    input  logic [DATA_WIDTH-1:0]   d_mem_data_in,
    output logic [DATA_WIDTH-1:0]   d_mem_data_out,
    input  logic                    d_mem_en_in,
    input  logic                    d_mem_wr_in,
    input  logic [1:0]              d_mem_size_in,
        
    input  logic [ADDR_WIDTH-1:0]   debug_mem_addr_in,
    input  logic [DATA_WIDTH-1:0]   debug_mem_data_in,
    output logic [DATA_WIDTH-1:0]   debug_mem_data_out,
    input  logic                    debug_mem_wr_in
    
    );

logic [7:0] mem0 [MEM_SIZE] = '{MEM_SIZE{0}};
logic [7:0] mem1 [MEM_SIZE] = '{MEM_SIZE{0}};
logic [7:0] mem2 [MEM_SIZE] = '{MEM_SIZE{0}};
logic [7:0] mem3 [MEM_SIZE] = '{MEM_SIZE{0}};

logic [DATA_WIDTH-1:0] i_buff = 0, d_buff = 0;

logic [ADDR_WIDTH-3:0]i_mem_addr_in_words, d_mem_addr_in_words, debug_mem_addr_in_words;

assign i_mem_addr_in_words = i_mem_addr_in >> 2;
assign d_mem_addr_in_words = d_mem_addr_in >> 2;
assign debug_mem_addr_in_words = debug_mem_addr_in >> 2;

logic clk = 0;
always_comb begin
    if (debug_mode_in)
    begin
        clk <= clk_debug_in;
    end
    else begin
        clk <= ~clk_mem_in;
    end    
end

assign i_mem_data_out = i_buff;
assign d_mem_data_out = d_buff;
always_ff @(posedge clk) begin
    
    if (~debug_mode_in) begin
        if (clk_cpu_in && i_mem_en_in) begin
            if ((i_mem_addr_in_words >= ADDR_BEGIN) && (i_mem_addr_in_words < ADDR_BEGIN+MEM_SIZE)) begin                 
                    i_buff <= {
                        mem3[i_mem_addr_in_words],
                        mem2[i_mem_addr_in_words],
                        mem1[i_mem_addr_in_words],
                        mem0[i_mem_addr_in_words]
                    };
            end
            else i_buff <= 0;
        end
        else if (~clk_cpu_in && d_mem_en_in) begin
            if ((d_mem_addr_in_words >= ADDR_BEGIN) && (d_mem_addr_in_words < ADDR_BEGIN+MEM_SIZE)) begin                 
                if (~d_mem_wr_in) begin
                    d_buff <= {
                        mem3[d_mem_addr_in_words],
                        mem2[d_mem_addr_in_words],
                        mem1[d_mem_addr_in_words],
                        mem0[d_mem_addr_in_words]
                    };
                end 
                else begin
                    case (d_mem_size_in)
                    2'b00:  // size = B
                    begin
                        case (d_mem_addr_in[1:0])
                            2'b00:  mem0[d_mem_addr_in_words] <= d_mem_data_in[7:0];
                            2'b01:  mem1[d_mem_addr_in_words] <= d_mem_data_in[15:8];
                            2'b10:  mem2[d_mem_addr_in_words] <= d_mem_data_in[23:16];
                            2'b11:  mem3[d_mem_addr_in_words] <= d_mem_data_in[31:24];
                        endcase
                    end
                    2'b01:  // size = H
                    begin
                        case (d_mem_addr_in[1])
                            1'b0:  begin
                                mem0[d_mem_addr_in_words] <= d_mem_data_in[7:0];
                                mem1[d_mem_addr_in_words] <= d_mem_data_in[15:8];
                            end
                            1'b1:  begin
                                mem2[d_mem_addr_in_words] <= d_mem_data_in[23:16];
                                mem3[d_mem_addr_in_words] <= d_mem_data_in[31:24];
                            end
                        endcase
                    end
                    2'b10:  // size = W
                    begin
                        mem0[d_mem_addr_in_words] <= d_mem_data_in[7:0];
                        mem1[d_mem_addr_in_words] <= d_mem_data_in[15:8];
                        mem2[d_mem_addr_in_words] <= d_mem_data_in[23:16];
                        mem3[d_mem_addr_in_words] <= d_mem_data_in[31:24];
                    end
                    endcase
                end
            end
        end
    end
    else begin
        if ((debug_mem_addr_in_words >= ADDR_BEGIN) && (debug_mem_addr_in_words < ADDR_BEGIN+MEM_SIZE)) begin                 
            if (debug_mem_wr_in) begin
                mem0[debug_mem_addr_in_words] <= debug_mem_data_in[7:0];
                mem1[debug_mem_addr_in_words] <= debug_mem_data_in[15:8];
                mem2[debug_mem_addr_in_words] <= debug_mem_data_in[23:16];
                mem3[debug_mem_addr_in_words] <= debug_mem_data_in[31:24];
            end 
            else begin
                debug_mem_data_out[7:0]   <= mem0[debug_mem_addr_in_words];
                debug_mem_data_out[15:8]  <= mem1[debug_mem_addr_in_words];
                debug_mem_data_out[23:16] <= mem2[debug_mem_addr_in_words];
                debug_mem_data_out[31:24] <= mem3[debug_mem_addr_in_words];
            end
        end
    end
end


endmodule