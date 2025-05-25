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

module friscv_mem_stage(
// global inputs  
    input logic                     clk_in,

// stage control inputs
    input logic                     rst_n_in,

// inputs from EX stage
    input logic [ADDR_WIDTH-1:0]   pc_plus_4_in,
    input logic [DATA_WIDTH-1:0]   alu_data_in,
    input logic [REG_SEL_WIDTH-1:0]    rd_sel_in,
    input logic [DATA_WIDTH-1:0]   store_data_in,
    input mem_instr_sel_t          mem_instr_sel_in,
	input load_store_width_t       load_store_width_in,
	input wb_data_sel_t            wb_data_sel_in,

 // outputs to WB stage
    output logic [DATA_WIDTH-1:0]    rd_data_out,
    output logic [REG_SEL_WIDTH-1:0] rd_sel_out,

//  data memory interface
    output logic [ADDR_WIDTH-1:0]   d_mem_addr_out,
    output logic [DATA_WIDTH-1:0]   d_mem_data_out,
    input  logic [DATA_WIDTH-1:0]   d_mem_data_in,
    output logic                    d_mem_en_out,
    output logic                    d_mem_wr_out,
    output logic [1:0]              d_mem_size_out
);

// input registers, clk_in driven
logic [ADDR_WIDTH-1:0]  pc_plus_4_buff;
logic [ADDR_WIDTH-1:0]  alu_data_buff;
logic [DATA_WIDTH-1:0]  store_data_buff;
logic [DATA_WIDTH-1:0]  rd_sel_buff;
mem_instr_sel_t         mem_instr_sel_buff;
load_store_width_t      load_store_width_buff;
wb_data_sel_t           wb_data_sel_buff;


// internal logic
logic [DATA_WIDTH-1:0] load_data = 0;

// stage inputs buffering
always_ff @(posedge clk_in) begin
    if (~rst_n_in) begin
        pc_plus_4_buff <= 0;
        alu_data_buff <= 0;
        store_data_buff <= 0;
        rd_sel_buff <= 0;
        mem_instr_sel_buff <= MEM_INSTR_NONE;
        wb_data_sel_buff <= WB_DATA_SEL_ALU;
    end else begin
        pc_plus_4_buff <= pc_plus_4_in;
        alu_data_buff <= alu_data_in;
        store_data_buff <= store_data_in;
        rd_sel_buff <= rd_sel_in;
        mem_instr_sel_buff <= mem_instr_sel_in;
        load_store_width_buff <= load_store_width_in;
        wb_data_sel_buff <= wb_data_sel_in;
end
end

assign d_mem_en_out = ((mem_instr_sel_buff == MEM_INSTR_LOAD) || (mem_instr_sel_buff == MEM_INSTR_STORE));
assign d_mem_wr_out = (mem_instr_sel_buff == MEM_INSTR_STORE);

// load_store address alignment
always_comb begin
    if (d_mem_en_out) begin
        d_mem_size_out = load_store_width_buff[1:0];
        case (load_store_width_buff) 
            3'b000,3'b100: d_mem_addr_out = alu_data_buff;                          // B, BU                    
            3'b001,3'b101: d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:1], 1'b0};  // H, HU  
            3'b010: d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:2], 2'b00};        // W
        endcase
    end else begin
        d_mem_addr_out = 0;
        d_mem_size_out = 0;
    end        
end

assign d_mem_data_out = store_data_buff;
assign rd_sel_out = rd_sel_buff ;

// load data expansion to 32b
always_comb begin
    case (load_store_width_buff)
        3'b000: begin
            case (alu_data_buff[1:0]) 
                2'b00:  load_data = {{24{d_mem_data_in[7]}}, d_mem_data_in[7:0]};
                2'b01:  load_data = {{24{d_mem_data_in[15]}}, d_mem_data_in[15:8]};
                2'b10:  load_data = {{24{d_mem_data_in[23]}}, d_mem_data_in[23:16]};
                2'b11:  load_data = {{24{d_mem_data_in[31]}}, d_mem_data_in[31:24]};
            endcase
        end
        3'b100: begin
            case (alu_data_buff[1:0]) 
                2'b00:  load_data = {{24'h000000}, d_mem_data_in[7:0]};
                2'b01:  load_data = {{24'h000000}, d_mem_data_in[15:8]};
                2'b10:  load_data = {{24'h000000}, d_mem_data_in[23:16]};
                2'b11:  load_data = {{24'h000000}, d_mem_data_in[31:24]};
            endcase
        end
        3'b001: begin
            if (alu_data_buff[1])   load_data = {{16{d_mem_data_in[31]}}, d_mem_data_in[31:16]};
            else                    load_data = {{16{d_mem_data_in[15]}}, d_mem_data_in[15:0]};
        end
        3'b101: begin
            if (alu_data_buff[1])   load_data = {{16'h0000}, d_mem_data_in[31:16]};
            else                    load_data = {{16'h0000}, d_mem_data_in[15:0]};
        end
        3'b010: begin 
            load_data = d_mem_data_in;
        end        
    endcase
end

// output selection
always_comb begin
    case (wb_data_sel_buff)
        WB_DATA_SEL_PC_PLUS_4:  rd_data_out = pc_plus_4_buff;
        WB_DATA_SEL_ALU:        rd_data_out = alu_data_buff;
        WB_DATA_SEL_MEM:        rd_data_out = load_data;
        default:                rd_data_out = 0;
    endcase
end

endmodule
