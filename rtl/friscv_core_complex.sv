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

module friscv_core_complex #(
    parameter int HART_ID = 0
) (
    input  logic       i_clk,
    input  logic       i_rstn,
    output logic       o_end,
    input  logic       i_timer_irq,

    output mem_width_e o_mem_size,
    output addr_t      o_mem_addr,
    output data_t      o_mem_wdata,
    input  data_t      i_mem_rdata,
    output rw_cmd_e    o_mem_rw,
    input  logic       i_mem_wait
);

// ============================================================
// Level 1 bus: instruction and data memory interfaces
// ============================================================

// Instruction L1 bus
addr_t      w_inst_addr;
data_t      w_inst_data;
logic       w_inst_en;
logic       w_inst_wait;
logic       w_stall_if;
inst_t      w_zsbl_data;

// Data L1 bus
addr_t      w_data_addr;
data_t      w_data_wdata;
data_t      w_data_rdata;
logic       w_data_en;
logic       w_data_wr;
mem_width_e w_data_size;
logic       w_data_wait;
amo_op_e    w_amo_op;

// ============================================================
// Level 2 bus and L1-L2 arbitration
// ============================================================

addr_t      w_l2_addr;
mem_width_e w_l2_size;
data_t      w_l2_wdata;
rw_cmd_e    w_l2_rw;
data_t      w_l2_rdata;
logic       w_l2_wait;
amo_op_e    w_l2_amo_op;

// AMO unit signals
rw_cmd_e    w_amo_rw;
data_t      w_amo_store_data;
data_t      w_amo_load_data;
logic       w_amo_core_wait;
logic       w_amo_active;

assign o_mem_size  = w_l2_size;
assign o_mem_addr  = w_l2_addr;
assign o_mem_wdata = w_amo_active ? w_amo_store_data : w_l2_wdata;

friscv_l1_arbiter l1_arbiter (
    .i_clk        ( i_clk       ),
    .i_rstn       ( i_rstn      ),

    // Instruction Memory Interface
    .i_inst_addr  ( w_inst_addr  ),
    .o_inst_data  ( w_inst_data  ),
    .i_inst_en    ( w_inst_en    ),
    .o_inst_wait  ( w_inst_wait  ),

    // Data Memory Interface
    .i_data_addr  ( w_data_addr  ),
    .i_data_size  ( w_data_size  ),
    .i_data_wdata ( w_data_wdata ),
    .o_data_rdata ( w_data_rdata ),
    .i_data_en    ( w_data_en    ),
    .i_data_wr    ( w_data_wr    ),
    .o_data_wait  ( w_data_wait  ),
    .i_amo_op     ( w_amo_op     ),

    // L2 Interface
    .o_mem_size   ( w_l2_size    ),
    .o_mem_addr   ( w_l2_addr    ),
    .o_mem_wdata  ( w_l2_wdata   ),
    .i_mem_rdata  ( w_l2_rdata   ),
    .o_mem_rw     ( w_l2_rw      ),
    .i_mem_wait   ( w_l2_wait    ),
    .o_amo_op     ( w_l2_amo_op  )
);

// ============================================================
// End signal detection on write to END_ADDRESS
// ============================================================

logic r_end_signal;

always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
        r_end_signal <= 1'b0;
    end else if (w_data_addr == END_ADDRESS && w_data_en && w_data_wr) begin
        r_end_signal <= 1'b1;
    end
end

assign o_end = r_end_signal;
assign w_stall_if = w_inst_wait || r_end_signal;

// ============================================================
// Core instance
// ============================================================

friscv_core #(
    .HART_ID(HART_ID)
) cpu_0 (
    .i_clk            ( i_clk        ),
    .i_rstn           ( i_rstn       ),
    .i_irq            ( i_timer_irq  ),

    // Instruction Memory Interface
    .i_mem_addr_out   ( w_inst_addr  ),
    .i_mem_data_in    ( w_inst_data  ),
    .i_mem_en_out     ( w_inst_en    ),
    .i_mem_wait_in    ( w_stall_if   ),

    // Data memory interface
    .d_mem_addr_out   ( w_data_addr  ),
    .d_mem_data_out   ( w_data_wdata ),
    .d_mem_data_in    ( w_data_rdata ),
    .d_mem_en_out     ( w_data_en    ),
    .d_mem_wr_out     ( w_data_wr    ),
    .d_mem_size_out   ( w_data_size  ),
    .d_mem_wait_in    ( w_data_wait  ),
    .d_mem_amo_op_out ( w_amo_op     )
);

// ============================================================
// Atomic memory operations
// ============================================================

if (ENABLE_EXTENSION_A) begin
    friscv_amo_unit amo_unit (
        .i_clk            ( i_clk            ),
        .i_rstn           ( i_rstn           ),
        .i_amo_op         ( w_l2_amo_op      ),
        .i_rs2_val        ( w_data_wdata     ),
        .o_core_load_data ( w_amo_load_data  ),
        .o_core_wait      ( w_amo_core_wait  ),
        .i_mem_wait       ( i_mem_wait       ),
        .o_mem_rw         ( w_amo_rw         ),
        .i_mem_load_data  ( i_mem_rdata      ),
        .o_mem_store_data ( w_amo_store_data )
    );
    assign w_amo_active = (w_l2_amo_op != AMO_NONE);
end else begin
    assign w_amo_active     = 1'b0;
    assign w_amo_rw         = RW_IDLE;
    assign w_amo_store_data = '0;
    assign w_amo_load_data  = '0;
    assign w_amo_core_wait  = 1'b0;
end

// ============================================================
// Zero-stage bootloader
// ============================================================

if (ZSBL_ROM_SIZE_BYTES > 0) begin
    friscv_zsbl_rom zsbl_rom (
        .i_clk  ( i_clk       ),
        .i_addr ( w_l2_addr   ),
        .o_data ( w_zsbl_data )
    );

    logic w_l2_is_rom;
    addr_t r_rom_addr_prev;
    
    // Intercept reads in the ROM address window before they reach AXI
    assign w_l2_is_rom = (w_l2_addr >= RESET_VEC) &&
                         (w_l2_addr < RESET_VEC + ZSBL_ROM_SIZE_BYTES) &&
                         (w_l2_rw == RW_READ);

    // ROM has 1 cycle latency
    // Only update when we detect a new address change
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            r_rom_addr_prev <= '0;
        end else if (w_l2_is_rom && (w_l2_addr != r_rom_addr_prev)) begin
            r_rom_addr_prev <= w_l2_addr;
        end else if (!w_l2_is_rom) begin
            r_rom_addr_prev <= '0;
        end
    end

    assign w_l2_rdata = w_l2_is_rom ? w_zsbl_data :
                        w_amo_active ? w_amo_load_data : i_mem_rdata;
    assign w_l2_wait  = w_l2_is_rom ? (w_l2_addr != r_rom_addr_prev) :
                        w_amo_active ? w_amo_core_wait : i_mem_wait;
    assign o_mem_rw   = w_l2_is_rom ? RW_IDLE :
                        w_amo_active ? w_amo_rw : w_l2_rw;

end else begin
    // No ROM, pass through all reads/writes to AXI (or AMO unit)
    assign w_l2_rdata = w_amo_active ? w_amo_load_data : i_mem_rdata;
    assign w_l2_wait  = w_amo_active ? w_amo_core_wait : i_mem_wait;
    assign o_mem_rw   = w_amo_active ? w_amo_rw        : w_l2_rw;
end

endmodule
