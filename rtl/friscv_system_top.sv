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

module friscv_system_top(
    input  logic                   i_clk,
    input  logic                   i_extern_rstn,
    input  logic                   i_push_rst,
    output logic                   o_end,

    // Memory Interface
    output logic [2:0]             o_mem_size,
    output logic [ADDR_WIDTH-1:0]  o_mem_addr,
    output logic [DATA_WIDTH-1:0]  o_mem_wdata,
    input  logic [DATA_WIDTH-1:0]  i_mem_rdata,
    output logic [1:0]             o_mem_rw,
    input  logic                   i_mem_wait
);

logic                  r_rstn;
logic                  r_end_signal;

logic [ADDR_WIDTH-1:0] w_inst_addr;
logic [31:0]           w_inst_data;
logic [31:0]           w_inst_muxout_data;
logic                  w_inst_en;
logic                  w_inst_muxout_en;
logic                  w_inst_wait;
logic                  w_inst_wait_stalled;
logic [31:0]           w_zsbl_data;

logic [ADDR_WIDTH-1:0] w_data_addr;
logic [DATA_WIDTH-1:0] w_data_wdata;
logic [DATA_WIDTH-1:0] w_data_rdata;
logic                  w_data_en;
logic                  w_data_wr;
logic [1:0]            w_data_size;
logic                  w_data_wait;

always_ff @(negedge i_clk) begin
    r_rstn <= i_extern_rstn && !i_push_rst;
end

// End signal detection
always_ff @(posedge i_clk or negedge r_rstn) begin
    if (!r_rstn) begin
        r_end_signal <= 1'b0;
    end else if (w_data_addr == END_ADDRESS && w_data_en && w_data_wr) begin
        r_end_signal <= 1'b1;
    end
end

assign o_end = r_end_signal;

// Stall instruction fetch when end signal is high
assign w_inst_wait_stalled = w_inst_wait || r_end_signal;

friscv_cpu cpu0(
    .i_clk          (i_clk),
    .i_rstn         (r_rstn),

    // Instruction Memory Interface
    .i_mem_addr_out (w_inst_addr),
    .i_mem_data_in  (w_inst_muxout_data),
    .i_mem_en_out   (w_inst_en),
    .i_mem_wait_in  (w_inst_wait_stalled),

    // Data memory interface
    .d_mem_addr_out (w_data_addr),
    .d_mem_data_out (w_data_wdata),
    .d_mem_data_in  (w_data_rdata),
    .d_mem_en_out   (w_data_en),
    .d_mem_wr_out   (w_data_wr),
    .d_mem_size_out (w_data_size),
    .d_mem_wait_in  (w_data_wait)
);

friscv_l1_subsystem l1_subsystem(
    .i_clk        (i_clk),
    .i_rstn       (r_rstn),

    // Instruction Memory Interface
    .i_inst_addr  (w_inst_addr),
    .o_inst_data  (w_inst_data),
    .i_inst_en    (w_inst_muxout_en),
    .o_inst_wait  (w_inst_wait),

    // Data Memory Interface
    .i_data_addr  (w_data_addr),
    .i_data_wdata (w_data_wdata),
    .o_data_rdata (w_data_rdata),
    .i_data_en    (w_data_en),
    .i_data_wr    (w_data_wr),
    .o_data_wait  (w_data_wait),

    // External Interface
    .o_mem_size   (o_mem_size),
    .o_mem_addr   (o_mem_addr),
    .o_mem_wdata  (o_mem_wdata),
    .i_mem_rdata  (i_mem_rdata),
    .o_mem_rw     (o_mem_rw),
    .i_mem_wait   (i_mem_wait)
);

friscv_zsbl_rom zsbl_rom(
    .i_addr (w_inst_addr[15:0]),
    .o_data (w_zsbl_data)
);

friscv_zsbl_mux zsbl_mux(
    .i_addr      (w_inst_addr),
    .i_en        (w_inst_en),
    .i_zsbl_data (w_zsbl_data),
    .i_mem_data  (w_inst_data),
    .o_data      (w_inst_muxout_data),
    .o_mem_en    (w_inst_muxout_en)
);

endmodule
