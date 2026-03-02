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

module friscv_core (
    input  logic       i_clk,
    input  logic       i_rstn,
    
    input  logic       i_irq,
    
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
    output mem_width_e d_mem_size_out,
    input  logic       d_mem_wait_in,
    output amo_op_e    d_mem_amo_op_out
);

logic flush_if, flush_id;
logic stall_if, stall_id, stall_ex, stall_mem, flush_ex;

// Jump signals
logic  jump_ok, jal_ok, branch_ok;
addr_t jump_target, jal_target;  // ex_alu_data_out is branch_target

// IF stage signals
addr_t if_pc_out, if_pc_plus_4_out;
data_t if_ir_out;

// ID stage signals
reg_addr_t id_rs1_sel_out, id_rs2_sel_out, id_rd_sel_out;
addr_t     id_pc_out, id_pc_plus_4_out;
data_t     id_rs1_out, id_rs2_out, id_imm32_out;    
instr_ex_t id_instr_ex_out;
logic      id_illegal_inst;

// EX stage signals
addr_t          ex_pc_plus_4_out;
data_t          ex_alu_data_out, ex_store_data_out;
reg_addr_t      ex_rd_sel_out;
mem_instr_sel_e ex_mem_instr_sel_out;
mem_width_e     ex_load_store_width_out;
wb_data_sel_e   ex_wb_data_sel_out;
logic           ex_reserve_out;
logic           ex_conditional_out;
amo_op_e        ex_amo_op_out;

// MEM stage signals
data_t     mem_rd_data_out;
reg_addr_t mem_rd_sel_out;

// Interrupts
addr_t id_mtvec_out, id_mepc_out;
logic  id_interrupt_out, id_mret_out;
addr_t real_ex_pc;

friscv_pipeline_control control_unit (
    // Control signals
    .flush_if_out     ( flush_if        ),
    .flush_id_out     ( flush_id        ),
    .flush_ex_out     ( flush_ex        ),
    .stall_if_out     ( stall_if        ),
    .stall_id_out     ( stall_id        ),
    .stall_ex_out     ( stall_ex        ),
    .stall_mem_out    ( stall_mem       ),

    // IF stage
    .jump_ok_out      ( jump_ok         ),
    .jump_target_out  ( jump_target     ),

    // ID stage
    .id_rs1_sel_in    ( id_rs1_sel_out  ),
    .id_rs2_sel_in    ( id_rs2_sel_out  ),
    .jal_ok_in        ( jal_ok          ),
    .jal_target_in    ( jal_target      ),

    // EX stage
    .ex_rd_sel_in     ( ex_rd_sel_out   ),
    .branch_ok_in     ( branch_ok       ),
    .branch_target_in ( ex_alu_data_out ),

    // Memory wait signals
    .if_wait_in       ( i_mem_wait_in   ),
    .mem_wait_in      ( d_mem_wait_in   ),
    
    //Interrupts
    .interrupt_in     ( id_interrupt_out),
    .mret_in          ( id_mret_out     )
);

friscv_if_stage if_stage (
    .clk_in         ( i_clk            ),
    .rst_n_in       ( i_rstn           ),

    // Stage control signals
    .flush_in       ( flush_if         ),
    .stage_stall_in ( stall_if         ),
    .i_mem_wait_in  ( i_mem_wait_in    ),
    .jump_ok_in     ( jump_ok          ),
    .jump_target_in ( jump_target      ),

    // Outputs to ID stage
    .pc_out         ( if_pc_out        ),
    .pc_plus_4_out  ( if_pc_plus_4_out ),
    .ir_out         ( if_ir_out        ),

    // Instruction memory interface
    .i_mem_addr_out ( i_mem_addr_out   ),
    .i_mem_data_in  ( i_mem_data_in    ),
    .i_mem_en_out   ( i_mem_en_out     ),
    
    //Interrupts
    .interrupt_in   ( id_interrupt_out ),
    .mret_in        ( id_mret_out      ),
    .mtvec_in       ( id_mtvec_out     ),
    .mepc_in        ( id_mepc_out      )
);

friscv_id_stage id_stage (
    .clk_in         ( i_clk            ), 
    .rst_n_in       ( i_rstn           ),
    
    .irq_in         ( i_irq            ),
    .branch_ok_in   ( branch_ok        ),

    // Stage control signals
    .flush_in       ( flush_id         ),
    .stage_stall_in ( stall_id         ),

    // Outputs to control logic
    .rs1_sel_out    ( id_rs1_sel_out   ),
    .rs2_sel_out    ( id_rs2_sel_out   ),
    .rd_sel_out     ( id_rd_sel_out    ),
    .jal_ok_out     ( jal_ok           ),
    .jal_target_out ( jal_target       ),
    .illegal_inst   ( id_illegal_inst  ),

    // Inputs from IF stage
    .pc_in          ( if_pc_out        ),
    .pc_plus_4_in   ( if_pc_plus_4_out ),
    .ir_in          ( if_ir_out        ),

    // Outputs to EX stage
    .pc_out         ( id_pc_out        ),
    .pc_plus_4_out  ( id_pc_plus_4_out ),
    .rs1_out        ( id_rs1_out       ),
    .rs2_out        ( id_rs2_out       ),
    .imm32_out      ( id_imm32_out     ),
    .instr_ex_out   ( id_instr_ex_out  ),

    // Inputs from WB stage
    .rd_sel_in      ( mem_rd_sel_out   ),
    .rd_data_in     ( mem_rd_data_out  ),
    
    //Interrupts
    .mtvec_out      ( id_mtvec_out      ), 
    .mepc_out       ( id_mepc_out       ),
    .interrupt_out  ( id_interrupt_out  ),
    .mret_id_out    ( id_mret_out       ),
    .pc_ex_in       ( real_ex_pc        )
);

friscv_ex_stage ex_stage (
    .clk_in               ( i_clk                   ),
    .rst_n_in             ( i_rstn                  ),

    // Stage control signals
    .stage_stall_in       ( stall_ex                ),
    .stage_flush_in       ( flush_ex                ),

    // Inputs from ID stage
    .pc_in                ( id_pc_out               ),
    .pc_plus_4_in         ( id_pc_plus_4_out        ),
    .rs1_in               ( id_rs1_out              ),
    .rs2_in               ( id_rs2_out              ),
    .imm32_in             ( id_imm32_out            ),
    .rd_sel_in            ( id_rd_sel_out           ),
    .instr_ex_in          ( id_instr_ex_out         ),

    // Outputs to MEM stage
    .pc_plus_4_out        ( ex_pc_plus_4_out        ),
    .alu_data_out         ( ex_alu_data_out         ),
    .rd_sel_out           ( ex_rd_sel_out           ),
    .store_data_out       ( ex_store_data_out       ),
    .mem_instr_sel_out    ( ex_mem_instr_sel_out    ),
    .load_store_width_out ( ex_load_store_width_out ),
    .wb_data_sel_out      ( ex_wb_data_sel_out      ),
    .reserve_out          ( ex_reserve_out          ),
    .conditional_out      ( ex_conditional_out      ),
    .amo_op_out           ( ex_amo_op_out           ),

    // Outputs to control logic
    .branch_ok_out        ( branch_ok               ),
    
    // Interrupts
    .pc_out               ( real_ex_pc              )
);

friscv_mem_stage mem_stage (
    .clk_in              ( i_clk                   ),
    .rst_n_in            ( i_rstn                  ),

    // Stage control signals
    .stage_stall_in      ( stall_mem               ),

    // Inputs from EX stage
    .pc_plus_4_in        ( ex_pc_plus_4_out        ),
    .alu_data_in         ( ex_alu_data_out         ),
    .rd_sel_in           ( ex_rd_sel_out           ),
    .store_data_in       ( ex_store_data_out       ),
    .mem_instr_sel_in    ( ex_mem_instr_sel_out    ),
    .load_store_width_in ( ex_load_store_width_out ),
    .wb_data_sel_in      ( ex_wb_data_sel_out      ),

    // AMO control
    .reserve_in          ( ex_reserve_out          ),
    .conditional_in      ( ex_conditional_out      ),
    .clear_reserve_in    ( id_interrupt_out        ),
    .amo_op_in           ( ex_amo_op_out           ),

    // Outputs to WB stage
    .rd_data_out         ( mem_rd_data_out         ),
    .rd_sel_out          ( mem_rd_sel_out          ),

    // Data memory interface
    .d_mem_addr_out      ( d_mem_addr_out          ),
    .d_mem_data_out      ( d_mem_data_out          ),
    .d_mem_data_in       ( d_mem_data_in           ),
    .d_mem_en_out        ( d_mem_en_out            ),
    .d_mem_wr_out        ( d_mem_wr_out            ),
    .d_mem_size_out      ( d_mem_size_out          ),
    .d_mem_wait_in       ( d_mem_wait_in           ),
    .d_mem_amo_op_out    ( d_mem_amo_op_out        )
);

endmodule
