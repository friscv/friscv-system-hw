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

module friscv_core(
    input logic        i_clk,
    input logic        i_rstn,
    
    // Instruction Memory Interface
    output addr_t      i_mem_addr_out,
    input  data_t      i_mem_data_in,
    output logic       i_mem_en_out,
    input  logic       i_mem_wait_in,

    // Data memory interface 
    output addr_t      d_mem_addr_out,
    output data_t      d_mem_data_out,
    input  data_t      d_mem_data_in,
    output logic       d_mem_en_out,
    output logic       d_mem_wr_out,
    output mem_width_t d_mem_size_out,
    input  logic       d_mem_wait_in
);

logic rst_n_if, rst_n_id, rst_n_ex;
logic stall_if, stall_id, stall_ex, stall_mem, flush_ex;
logic rst_id_wb_ok;

// IF stage signals
addr_t if_pc_out, if_pc_plus_4_out;
logic  if_jump_branch_in; 
data_t if_ir_out;

// ID stage signals
reg_addr_t id_rs1_sel_out, id_rs2_sel_out, id_rd_sel_out;
addr_t     id_pc_out, id_pc_plus_4_out;
data_t     id_rs1_out, id_rs2_out, id_imm32_out;    
instr_ex_t id_instr_ex_out;

// EX stage signals
addr_t          ex_pc_plus_4_out;
data_t          ex_alu_data_out, ex_store_data_out;
reg_addr_t      ex_rd_sel_out;
mem_instr_sel_t ex_mem_instr_sel_out;
mem_width_t     ex_load_store_width_out;
wb_data_sel_t   ex_wb_data_sel_out;
logic           ex_branch_ok_out;

// MEM stage signals
data_t     mem_rd_data_out;
reg_addr_t mem_rd_sel_out;

// WB stage signals
data_t     wb_rd_data_out;
reg_addr_t wb_rd_sel_out;

friscv_pipeline_control control_unit (
    .clk_in           ( i_clk             ),
    .rst_n_cpu_in     ( i_rstn            ),
    .rst_n_if_out     ( rst_n_if          ),
    .rst_n_id_out     ( rst_n_id          ),
    .rst_n_ex_out     ( rst_n_ex          ),
    .rst_id_wb_ok_out ( rst_id_wb_ok      ),
    .stall_if_out     ( stall_if          ),
    .stall_id_out     ( stall_id          ),
    .stall_ex_out     ( stall_ex          ),
    .stall_mem_out    ( stall_mem         ),
    .flush_ex_out     ( flush_ex          ),
    .jump_branch_out  ( if_jump_branch_in ),
    .id_rs1_sel_in    ( id_rs1_sel_out    ),
    .id_rs2_sel_in    ( id_rs2_sel_out    ),
    .ex_rd_sel_in     ( ex_rd_sel_out     ),
    .branch_ok_in     ( ex_branch_ok_out  ),
    .mem_rd_sel_in    ( mem_rd_sel_out    ),
    .if_wait_in       ( i_mem_wait_in     ),
    .mem_wait_in      ( d_mem_wait_in     )
);

friscv_if_stage if_stage (
    .clk_in              ( i_clk             ),
    .rst_n_in            ( rst_n_if          ),
    .stage_stall_in      ( stall_if          ),
    .jump_branch_in      ( if_jump_branch_in ),
    .i_mem_wait_in       ( i_mem_wait_in     ),
    .jump_branch_addr_in ( ex_alu_data_out   ),
    .pc_out              ( if_pc_out         ),
    .pc_plus_4_out       ( if_pc_plus_4_out  ),
    .ir_out              ( if_ir_out         ),
    .i_mem_addr_out      ( i_mem_addr_out    ),
    .i_mem_data_in       ( i_mem_data_in     ),
    .i_mem_en_out        ( i_mem_en_out      )
);

friscv_id_stage id_stage (
    .clk_in          ( i_clk            ),
    .rst_n_in        ( rst_n_id         ),
    .stage_stall_in  ( stall_id         ),
    .rst_id_wb_ok_in ( rst_id_wb_ok     ),
    .rs1_sel_out     ( id_rs1_sel_out   ),
    .rs2_sel_out     ( id_rs2_sel_out   ),
    .rd_sel_out      ( id_rd_sel_out    ),
    .pc_in           ( if_pc_out        ),
    .pc_plus_4_in    ( if_pc_plus_4_out ),
    .ir_in           ( if_ir_out        ),
    .pc_out          ( id_pc_out        ),
    .pc_plus_4_out   ( id_pc_plus_4_out ),
    .rs1_out         ( id_rs1_out       ),
    .rs2_out         ( id_rs2_out       ),
    .imm32_out       ( id_imm32_out     ),
    .instr_ex_out    ( id_instr_ex_out  ),
    .rd_sel_in       ( wb_rd_sel_out    ),
    .rd_data_in      ( wb_rd_data_out   )
);

friscv_ex_stage ex_stage (
    .clk_in               ( i_clk                   ),
    .rst_n_in             ( i_rstn                  ),
    .stage_stall_in       ( stall_ex                ),
    .stage_flush_in       ( flush_ex                ),
    .pc_in                ( id_pc_out               ),
    .pc_plus_4_in         ( id_pc_plus_4_out        ),
    .rs1_in               ( id_rs1_out              ),
    .rs2_in               ( id_rs2_out              ),
    .imm32_in             ( id_imm32_out            ),
    .instr_ex_in          ( id_instr_ex_out         ),
    .rd_sel_in            ( id_rd_sel_out           ),
    .pc_plus_4_out        ( ex_pc_plus_4_out        ),
    .alu_data_out         ( ex_alu_data_out         ),
    .rd_sel_out           ( ex_rd_sel_out           ),
    .store_data_out       ( ex_store_data_out       ),
    .mem_instr_sel_out    ( ex_mem_instr_sel_out    ),
    .load_store_width_out ( ex_load_store_width_out ),
    .wb_data_sel_out      ( ex_wb_data_sel_out      ),
    .branch_ok_out        ( ex_branch_ok_out        )
);

friscv_mem_stage mem_stage (
    .clk_in              ( i_clk                   ),
    .stage_stall_in      ( stall_mem               ),
    .pc_plus_4_in        ( ex_pc_plus_4_out        ),
    .alu_data_in         ( ex_alu_data_out         ),
    .rd_sel_in           ( ex_rd_sel_out           ),
    .store_data_in       ( ex_store_data_out       ),
    .mem_instr_sel_in    ( ex_mem_instr_sel_out    ),
    .load_store_width_in ( ex_load_store_width_out ),
    .wb_data_sel_in      ( ex_wb_data_sel_out      ),
    .rd_data_out         ( mem_rd_data_out         ),
    .rd_sel_out          ( mem_rd_sel_out          ),
    .d_mem_addr_out      ( d_mem_addr_out          ),
    .d_mem_data_out      ( d_mem_data_out          ),
    .d_mem_data_in       ( d_mem_data_in           ),
    .d_mem_en_out        ( d_mem_en_out            ),
    .d_mem_wr_out        ( d_mem_wr_out            ),
    .d_mem_size_out      ( d_mem_size_out          ),
    .d_mem_wait_in       ( d_mem_wait_in           )
);

friscv_wb_stage wb_stage (
    .rd_data_in  ( mem_rd_data_out ),
    .rd_sel_in   ( mem_rd_sel_out  ),
    .rd_data_out ( wb_rd_data_out  ),
    .rd_sel_out  ( wb_rd_sel_out   )
);

endmodule
