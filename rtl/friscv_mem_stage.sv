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

module friscv_mem_stage (
    input  logic           clk_in,
    input  logic           stage_stall_in,
    input  logic           rst_n_in,

    // Inputs from EX stage
    input  addr_t          pc_plus_4_in,
    input  data_t          alu_data_in,
    input  reg_addr_t      rd_sel_in,
    input  data_t          store_data_in,
    input  mem_instr_sel_t mem_instr_sel_in,
	input  mem_width_t     load_store_width_in,
	input  wb_data_sel_t   wb_data_sel_in,

    // Outputs to WB stage
    output data_t          rd_data_out,
    output reg_addr_t      rd_sel_out,

    // Data memory interface
    output addr_t          d_mem_addr_out,
    output data_t          d_mem_data_out,
    input  data_t          d_mem_data_in,
    output logic           d_mem_en_out,
    output logic           d_mem_wr_out,
    output mem_width_t     d_mem_size_out,
    input  logic           d_mem_wait_in
);

// input registers, clk_in driven
addr_t          pc_plus_4_buff;
addr_t          alu_data_buff;
data_t          store_data_buff;
data_t          rd_sel_buff;
mem_instr_sel_t mem_instr_sel_buff;
mem_width_t     load_store_width_buff;
wb_data_sel_t   wb_data_sel_buff;

data_t load_data;
data_t load_data_buff;  // Buffered load data

logic r_mem_active;
logic r_load_data_valid;  // Flag indicating load data has been captured

logic w_is_mem_instr;
assign w_is_mem_instr = mem_instr_sel_in != MEM_INSTR_NONE;

// Stage inputs buffering
// MEM stage always accepts data from EX stage
// Bubbles are inserted by EX sending instructions with rd_sel=0
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (~rst_n_in) begin
        pc_plus_4_buff        <= '0;
        alu_data_buff         <= '0;
        store_data_buff       <= '0;
        rd_sel_buff           <= '0;
        mem_instr_sel_buff    <= MEM_INSTR_NONE;
        load_store_width_buff <= WIDTH_I32;
        wb_data_sel_buff      <= WB_DATA_SEL_ALU;
        r_mem_active          <= 1'b0;
        r_load_data_valid     <= 1'b0;
        load_data_buff        <= '0;
    end
    else begin
        if (~stage_stall_in) begin
            pc_plus_4_buff        <= pc_plus_4_in;
            alu_data_buff         <= alu_data_in;
            store_data_buff       <= store_data_in;
            rd_sel_buff           <= rd_sel_in;
            mem_instr_sel_buff    <= mem_instr_sel_in;
            load_store_width_buff <= load_store_width_in;
            wb_data_sel_buff      <= wb_data_sel_in;
            r_mem_active          <= w_is_mem_instr;
            r_load_data_valid     <= 1'b0;  // Clear on new instruction
        end
        else if (r_mem_active && ~d_mem_wait_in) begin
            r_mem_active <= 1'b0;
            // Capture load data when load completes
            if (mem_instr_sel_buff == MEM_INSTR_LOAD) begin
                load_data_buff <= load_data;
                r_load_data_valid <= 1'b1;
            end
        end
    end
end

assign d_mem_en_out = r_mem_active;
assign d_mem_wr_out = (mem_instr_sel_buff == MEM_INSTR_STORE);

// Address and width enum conversion alignment
always_comb begin
    if (d_mem_en_out) begin
        unique case (load_store_width_buff)
            WIDTH_U8:  d_mem_size_out = WIDTH_I8;
            WIDTH_U16: d_mem_size_out = WIDTH_I16;
            default:   d_mem_addr_out = load_store_width_buff;
        endcase
        unique case (load_store_width_buff) 
            WIDTH_I8, WIDTH_U8:   d_mem_addr_out = alu_data_buff;              
            WIDTH_I16, WIDTH_U16: d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:1], 1'b0};
            WIDTH_I32:            d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:2], 2'b00};
            default:              d_mem_addr_out = alu_data_buff;
        endcase
    end else begin
        d_mem_size_out = WIDTH_I32;
        d_mem_addr_out = '0;
    end
end

assign d_mem_data_out = store_data_buff;
assign rd_sel_out = rd_sel_buff;

// Load data expansion to 32b
always_comb begin
    unique case (load_store_width_buff)
        WIDTH_I8: begin
            case (alu_data_buff[1:0]) 
                2'b00:  load_data = {{24{d_mem_data_in[7]}},  d_mem_data_in[7:0]};
                2'b01:  load_data = {{24{d_mem_data_in[15]}}, d_mem_data_in[15:8]};
                2'b10:  load_data = {{24{d_mem_data_in[23]}}, d_mem_data_in[23:16]};
                2'b11:  load_data = {{24{d_mem_data_in[31]}}, d_mem_data_in[31:24]};
            endcase
        end
        WIDTH_U8: begin
            case (alu_data_buff[1:0]) 
                2'b00:  load_data = {{24'h000000}, d_mem_data_in[7:0]};
                2'b01:  load_data = {{24'h000000}, d_mem_data_in[15:8]};
                2'b10:  load_data = {{24'h000000}, d_mem_data_in[23:16]};
                2'b11:  load_data = {{24'h000000}, d_mem_data_in[31:24]};
            endcase
        end
        WIDTH_I16: begin
            if (alu_data_buff[1]) begin
                load_data = {{16{d_mem_data_in[31]}}, d_mem_data_in[31:16]};
            end else begin
                load_data = {{16{d_mem_data_in[15]}}, d_mem_data_in[15:0]};
            end
        end
        WIDTH_U16: begin
            if (alu_data_buff[1]) begin
                load_data = {{16'h0000}, d_mem_data_in[31:16]};
            end else begin
                load_data = {{16'h0000}, d_mem_data_in[15:0]};
            end
        end
        WIDTH_I16: begin 
            load_data = d_mem_data_in;
        end
        default: begin
            load_data = d_mem_data_in;
        end
    endcase
end

// output selection
always_comb begin
    case (wb_data_sel_buff)
        WB_DATA_SEL_PC_PLUS_4: rd_data_out = pc_plus_4_buff;
        WB_DATA_SEL_ALU:       rd_data_out = alu_data_buff;
        WB_DATA_SEL_MEM:       rd_data_out = r_load_data_valid ? load_data_buff : load_data;
        default:               rd_data_out = 0;
    endcase
end

endmodule
