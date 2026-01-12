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

module friscv_core_complex (
    input  logic       i_clk,
    input  logic       i_rstn,
    output logic       o_end,

    output mem_width_t o_mem_size,
    output addr_t      o_mem_addr,
    output data_t      o_mem_wdata,
    input  data_t      i_mem_rdata,
    output rw_cmd_t    o_mem_rw,
    input  logic       i_mem_wait
);

logic       r_end_signal;

addr_t      w_inst_addr;
data_t      w_inst_data;
data_t      w_inst_muxout_data;
logic       w_inst_en;
logic       w_inst_muxout_en;
logic       w_inst_wait;
logic       w_inst_wait_stalled;
inst_t      w_zsbl_data;

addr_t      w_data_addr;
data_t      w_data_wdata;
data_t      w_data_rdata;
logic       w_data_en;
logic       w_data_wr;
mem_width_t w_data_size;
logic       w_data_wait;

// End signal detection on write to END_ADDRESS
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
        r_end_signal <= 1'b0;
    end else if (w_data_addr == END_ADDRESS && w_data_en && w_data_wr) begin
        r_end_signal <= 1'b1;
    end
end

assign o_end = r_end_signal;

// Stall instruction fetch when end signal is high
assign w_inst_wait_stalled = w_inst_wait || r_end_signal;

friscv_core cpu_0 (
    .i_clk          ( i_clk               ),
    .i_rstn         ( i_rstn              ),

    // Instruction Memory Interface
    .i_mem_addr_out ( w_inst_addr         ),
    .i_mem_data_in  ( w_inst_muxout_data  ),
    .i_mem_en_out   ( w_inst_en           ),
    .i_mem_wait_in  ( w_inst_wait_stalled ),

    // Data memory interface
    .d_mem_addr_out ( w_data_addr         ),
    .d_mem_data_out ( w_data_wdata        ),
    .d_mem_data_in  ( w_data_rdata        ),
    .d_mem_en_out   ( w_data_en           ),
    .d_mem_wr_out   ( w_data_wr           ),
    .d_mem_size_out ( w_data_size         ),
    .d_mem_wait_in  ( w_data_wait         )
);

// Contains the hart's fabric arbiter and L1I/L1D caches
friscv_l1_subsystem l1_subsystem (
    .i_clk        ( i_clk            ),
    .i_rstn       ( i_rstn           ),

    // Instruction Memory Interface
    .i_inst_addr  ( w_inst_addr      ),
    .o_inst_data  ( w_inst_data      ),
    .i_inst_en    ( w_inst_muxout_en ),
    .o_inst_wait  ( w_inst_wait      ),

    // Data Memory Interface
    .i_data_addr  ( w_data_addr      ),
    .i_data_size  ( w_data_size      ),
    .i_data_wdata ( w_data_wdata     ),
    .o_data_rdata ( w_data_rdata     ),
    .i_data_en    ( w_data_en        ),
    .i_data_wr    ( w_data_wr        ),
    .o_data_wait  ( w_data_wait      ),

    // L2 Interface
    .o_mem_size   ( o_mem_size       ),
    .o_mem_addr   ( o_mem_addr       ),
    .o_mem_wdata  ( o_mem_wdata      ),
    .i_mem_rdata  ( i_mem_rdata      ),
    .o_mem_rw     ( o_mem_rw         ),
    .i_mem_wait   ( i_mem_wait       )
);

// Zero-stage bootloader
friscv_zsbl_rom zsbl_rom (
    .i_addr ( w_inst_addr ),
    .o_data ( w_zsbl_data )
);

friscv_zsbl_mux zsbl_mux (
    .i_addr      ( w_inst_addr        ),
    .i_en        ( w_inst_en          ),
    .i_zsbl_data ( w_zsbl_data        ),
    .i_mem_data  ( w_inst_data        ),
    .o_data      ( w_inst_muxout_data ),
    .o_mem_en    ( w_inst_muxout_en   )
);

endmodule
