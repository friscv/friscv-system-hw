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
    input  logic           rst_n_in,

    // Stage control signals
    input  logic           stage_stall_in,

    // Inputs from EX stage
    input  addr_t          pc_plus_4_in,
    input  data_t          alu_data_in,
    input  reg_addr_t      rd_sel_in,
    input  data_t          store_data_in,
    input  mem_instr_sel_e mem_instr_sel_in,
	input  mem_width_e     load_store_width_in,
	input  wb_data_sel_e   wb_data_sel_in,
    input  csr_addr_e      csr_sel_in,
    input  data_t          csr_readback_in,
    input  logic           csr_en_in,
    input  logic           instr_valid_in,

    // AMO control
    input  logic           reserve_in,
    input  logic           conditional_in,
    input  logic           clear_reserve_in,
    input  amo_op_e        amo_op_in,

    // Outputs to WB stage
    output data_t          rd_data_out,
    output reg_addr_t      rd_sel_out,
    output csr_addr_e      csr_sel_out,
    output data_t          csr_data_out,
    output logic           csr_en_out,
    output logic           inst_ret_out,

    // Data memory interface
    output addr_t          d_mem_addr_out,
    output data_t          d_mem_data_out,
    input  data_t          d_mem_data_in,
    output logic           d_mem_en_out,
    output logic           d_mem_wr_out,
    output mem_width_e     d_mem_size_out,
    input  logic           d_mem_wait_in,
    output amo_op_e        d_mem_amo_op_out
);

// Input registers
addr_t          pc_plus_4_buff;
addr_t          alu_data_buff;
data_t          store_data_buff;
reg_addr_t      rd_sel_buff;
mem_instr_sel_e mem_instr_sel_buff;
mem_width_e     load_store_width_buff;
wb_data_sel_e   wb_data_sel_buff;
logic           conditional_buff;
logic           clear_reserve_buff;
amo_op_e        amo_op_buff;
csr_addr_e      csr_sel_buff;
data_t          csr_readback_buff;
logic           csr_en_buff;
logic           instr_valid_buff;

assign csr_sel_out  = csr_sel_buff;
assign csr_data_out = alu_data_buff;
assign csr_en_out   = csr_en_buff;

data_t load_data;
data_t load_data_buff;  // Buffered load data

(* MAX_FANOUT = 8 *) logic r_mem_active;
logic r_load_data_valid;  // Flag indicating load data has been captured

logic w_is_mem_instr;
assign w_is_mem_instr = mem_instr_sel_in != MEM_INSTR_NONE;

// Detect retired instruction
assign inst_ret_out = instr_valid_buff && !stage_stall_in;

// Reservation register for AMO LR/SC
logic  reserve_valid;
addr_t reserve_addr;
logic  r_sc_res_valid;
logic  r_sc_res;

// Can execute memory instruction if either
//  1) It is a store conditional instruction with a valid reservation for the requested address or
//  2) It is not a store conditional instruction
logic cond_valid;
logic cond_valid_r;

assign cond_valid = (conditional_in) ? reserve_valid && (reserve_addr == alu_data_in) : 1'b1;

// ============================================================
// Input capture
// ============================================================

// MEM stage always accepts data from EX stage
// Bubbles are inserted by EX sending instructions with rd_sel=0
always_ff @(posedge clk_in or negedge rst_n_in) begin
    if (!rst_n_in) begin
        pc_plus_4_buff        <= 32'h0;
        alu_data_buff         <= 32'h0;
        store_data_buff       <= 32'h0;
        rd_sel_buff           <= 5'b0;
        mem_instr_sel_buff    <= MEM_INSTR_NONE;
        load_store_width_buff <= WIDTH_I32;
        wb_data_sel_buff      <= WB_DATA_SEL_ALU;
        r_mem_active          <= 1'b0;
        r_load_data_valid     <= 1'b0;
        load_data_buff        <= 32'b0;
        reserve_valid         <= 1'b0;
        reserve_addr          <= 32'b0;
        r_sc_res_valid        <= 1'b0;
        r_sc_res              <= 1'b0;
        conditional_buff      <= 1'b0;
        clear_reserve_buff    <= 1'b0;
        cond_valid_r          <= 1'b0;
        amo_op_buff           <= AMO_NONE;
        csr_sel_buff          <= CSR_ZERO;
        csr_readback_buff     <= 32'b0;
        csr_en_buff           <= 1'b0;
        instr_valid_buff      <= 1'b0;
    end

    else begin
        if (clear_reserve_in) begin
            reserve_valid <= 1'b0;
        end

        if (!stage_stall_in) begin
            pc_plus_4_buff        <= pc_plus_4_in;
            alu_data_buff         <= alu_data_in;
            store_data_buff       <= store_data_in;
            rd_sel_buff           <= rd_sel_in;
            mem_instr_sel_buff    <= mem_instr_sel_in;
            load_store_width_buff <= load_store_width_in;
            wb_data_sel_buff      <= wb_data_sel_in;
            r_mem_active          <= w_is_mem_instr && cond_valid;
            r_load_data_valid     <= 1'b0;  // Clear on new instruction
            r_sc_res_valid        <= 1'b0;
            conditional_buff      <= conditional_in;
            clear_reserve_buff    <= clear_reserve_in;
            amo_op_buff           <= amo_op_in;
            cond_valid_r          <= cond_valid;
            csr_sel_buff          <= csr_sel_in;
            csr_readback_buff     <= csr_readback_in;
            csr_en_buff           <= csr_en_in;
            instr_valid_buff      <= instr_valid_in;

            if (!clear_reserve_in) begin
                if (reserve_in) begin
                    reserve_valid <= 1'b1;
                    reserve_addr  <= alu_data_in;
                end else if (conditional_buff && r_mem_active) begin
                    // SC.W completed; clear reservation so a subsequent SC fails.
                    reserve_valid <= 1'b0;
                end
            end
        end

        else if (r_mem_active && !d_mem_wait_in) begin
            r_mem_active <= 1'b0;

            // Clear reservation after SC completes
            if (conditional_buff) begin
                reserve_valid <= 1'b0;
                r_sc_res <= !cond_valid;
                r_sc_res_valid <= 1'b1;
            end

            // Capture load data when load completes
            if (mem_instr_sel_buff == MEM_INSTR_LOAD) begin
                load_data_buff <= load_data;
                r_load_data_valid <= 1'b1;
            end
        end
    end
end

assign d_mem_en_out = r_mem_active;
assign d_mem_wr_out = mem_instr_sel_buff == MEM_INSTR_STORE;

// ============================================================
// Address and width enum conversion alignment
// ============================================================

always_comb begin
    if (d_mem_en_out) begin
        case (load_store_width_buff)
            WIDTH_U8:  d_mem_size_out = WIDTH_I8;
            WIDTH_U16: d_mem_size_out = WIDTH_I16;
            default:   d_mem_size_out = load_store_width_buff;
        endcase
        case (load_store_width_buff)
            WIDTH_I8, WIDTH_U8:   d_mem_addr_out = alu_data_buff;
            WIDTH_I16, WIDTH_U16: d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:1], 1'b0};
            WIDTH_I32:            d_mem_addr_out = {alu_data_buff[ADDR_WIDTH-1:2], 2'b00};
            default:              d_mem_addr_out = alu_data_buff;
        endcase
    end else begin
        d_mem_size_out = WIDTH_I32;
        d_mem_addr_out = 32'h0;
    end
end

assign d_mem_data_out = store_data_buff;
assign rd_sel_out = rd_sel_buff;
assign d_mem_amo_op_out = amo_op_buff;

// ============================================================
// Load data expansion to 32b
// ============================================================

always_comb begin
    case (load_store_width_buff)
        WIDTH_I8: begin
            case (alu_data_buff[1:0])
                2'b00: load_data = {{24{d_mem_data_in[ 7]}}, d_mem_data_in[ 7: 0]};
                2'b01: load_data = {{24{d_mem_data_in[15]}}, d_mem_data_in[15: 8]};
                2'b10: load_data = {{24{d_mem_data_in[23]}}, d_mem_data_in[23:16]};
                2'b11: load_data = {{24{d_mem_data_in[31]}}, d_mem_data_in[31:24]};
            endcase
        end
        WIDTH_U8: begin
            case (alu_data_buff[1:0])
                2'b00: load_data = {24'h0, d_mem_data_in[ 7: 0]};
                2'b01: load_data = {24'h0, d_mem_data_in[15: 8]};
                2'b10: load_data = {24'h0, d_mem_data_in[23:16]};
                2'b11: load_data = {24'h0, d_mem_data_in[31:24]};
            endcase
        end
        WIDTH_I16: begin
            if (alu_data_buff[1])
                load_data = {{16{d_mem_data_in[31]}}, d_mem_data_in[31:16]};
            else
                load_data = {{16{d_mem_data_in[15]}}, d_mem_data_in[15:0]};
        end
        WIDTH_U16: begin
            if (alu_data_buff[1])
                load_data = {16'h0, d_mem_data_in[31:16]};
            else
                load_data = {16'h0, d_mem_data_in[15:0]};
        end
        default: begin
            load_data = d_mem_data_in;
        end
    endcase
end

// ============================================================
// Output selection
// ============================================================

always_comb begin
    case (wb_data_sel_buff)
        WB_DATA_SEL_PC_PLUS_4: rd_data_out = pc_plus_4_buff;
        WB_DATA_SEL_ALU:       rd_data_out = alu_data_buff;
        WB_DATA_SEL_MEM:       rd_data_out = r_load_data_valid ? load_data_buff : load_data;
        WB_DATA_SEL_SC_RES:    rd_data_out = {31'h0, (r_sc_res_valid) ? r_sc_res : !cond_valid_r};
        WB_DATA_SEL_CSR:       rd_data_out = csr_readback_buff;
        default:               rd_data_out = 32'b0;
    endcase
end

endmodule
