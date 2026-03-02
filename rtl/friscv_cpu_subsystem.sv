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

module friscv_cpu_subsystem (
    input  logic        i_clk,
    input  logic        i_rstn,
    output logic        o_end,
    
    input  logic        i_timer_irq,
 
    // AXI4 Master Write Address Channel
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    output logic [31:0] m_axi_awaddr,
    output logic [2:0]  m_axi_awsize,
    output logic [3:0]  m_axi_awcache,
    output logic [2:0]  m_axi_awprot,
    output logic [1:0]  m_axi_awburst,
    output logic [7:0]  m_axi_awlen,
    output logic        m_axi_awlock,
    output logic [3:0]  m_axi_awqos,

    // AXI4 Master Write Data Channel
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,
    output logic        m_axi_wlast,
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,

    // AXI4 Master Write Response Channel
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,
    input  logic [1:0]  m_axi_bresp,

    // AXI4 Master Read Address Channel
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    output logic [31:0] m_axi_araddr,
    output logic [2:0]  m_axi_arsize,
    output logic [3:0]  m_axi_arcache,
    output logic [2:0]  m_axi_arprot,
    output logic [1:0]  m_axi_arburst,
    output logic [7:0]  m_axi_arlen,
    output logic        m_axi_arlock,
    output logic [3:0]  m_axi_arqos,

    // AXI4 Master Read Data Channel
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready,
    input  logic        m_axi_rlast,
    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp
);

mem_width_e  w_size;
logic [31:0] w_phy_addr;
logic [31:0] w_dram_addr;
logic [31:0] w_wdata;
logic [31:0] w_rdata;
rw_cmd_e     w_rw;
logic        w_wait;

if (DRAM_BASE == 32'h8000_0000) begin
    assign w_dram_addr = w_phy_addr[31] ? {1'b0, w_phy_addr[30:0]} + DRAM_START_AT : w_phy_addr;
end else if (DRAM_BASE == 32'h0) begin
    assign w_dram_addr = w_phy_addr + DRAM_START_AT;
end else begin
    assign w_dram_addr = (w_phy_addr < DRAM_BASE) ? w_phy_addr : (w_phy_addr - DRAM_BASE) + DRAM_START_AT;
end

// Metastability protection for reset
logic [1:0]  r_rstn_sync = 2'b00;

always_ff @(posedge i_clk) begin
    r_rstn_sync <= {r_rstn_sync[0], i_rstn};
end

// Reset debouncer
logic        r_rstn_debounced = 1'b0;
logic [20:0] r_debounce_cnt = 21'd0;

always_ff @(posedge i_clk) begin
    if (r_rstn_sync[1] == r_rstn_debounced) begin
        // Signal is stable, reset counter
        r_debounce_cnt <= '0;
    end else begin
        // Signal changed, increment counter
        if (r_debounce_cnt < RST_DEBOUNCE_CYCLES) begin
            r_debounce_cnt <= r_debounce_cnt + 1'b1;
        end else begin
            // Signal has been stable for debounce period, update output
            r_rstn_debounced <= r_rstn_sync[1];
        end
    end
end

logic w_core_rstn;
assign w_core_rstn = r_rstn_debounced;

friscv_core_complex cc_0 (
    .i_clk       ( i_clk       ),
    .i_rstn      ( w_core_rstn ),
    .o_end       ( o_end       ),
    .i_timer_irq ( i_timer_irq ),
    .o_mem_size  ( w_size      ),
    .o_mem_addr  ( w_phy_addr  ),
    .o_mem_wdata ( w_wdata     ),
    .i_mem_rdata ( w_rdata     ),
    .o_mem_rw    ( w_rw        ),
    .i_mem_wait  ( w_wait      )
);

// AXI master reset sequencer
// Wait for transactions to complete before resetting
logic r_axi_reset_req;
logic r_axi_in_reset = 1'b1;  // Start in reset

always_ff @(posedge i_clk or negedge r_rstn_debounced) begin
    if (!r_rstn_debounced) begin
        r_axi_reset_req <= 1'b1;  // Request reset when button pressed
    end else begin
        r_axi_reset_req <= 1'b0;  // Clear request when button released
    end
end

always_ff @(posedge i_clk) begin
    if (r_axi_reset_req && !w_wait) begin
        // Once transaction completes and reset is requested, assert reset
        r_axi_in_reset <= 1'b1;
    end else if (!r_axi_reset_req) begin
        // Only release reset when external reset is released
        r_axi_in_reset <= 1'b0;
    end
end

logic w_axi_rstn;
assign w_axi_rstn = !r_axi_in_reset;

friscv_axi_master m_axi (
    .i_clk          ( i_clk         ),
    .i_rstn         ( w_axi_rstn    ),
    .i_size         ( w_size        ),
    .i_addr         ( w_dram_addr   ),
    .i_wdata        ( w_wdata       ),
    .o_rdata        ( w_rdata       ),
    .i_rw           ( w_rw          ),
    .o_wait         ( w_wait        ),
    .m_axi_awvalid  ( m_axi_awvalid ),
    .m_axi_awready  ( m_axi_awready ),
    .m_axi_awaddr   ( m_axi_awaddr  ),
    .m_axi_awsize   ( m_axi_awsize  ),
    .m_axi_awcache  ( m_axi_awcache ),
    .m_axi_awprot   ( m_axi_awprot  ),
    .m_axi_awburst  ( m_axi_awburst ),
    .m_axi_awlen    ( m_axi_awlen   ),
    .m_axi_awlock   ( m_axi_awlock  ),
    .m_axi_awqos    ( m_axi_awqos   ),
    .m_axi_wvalid   ( m_axi_wvalid  ),
    .m_axi_wready   ( m_axi_wready  ),
    .m_axi_wlast    ( m_axi_wlast   ),
    .m_axi_wdata    ( m_axi_wdata   ),
    .m_axi_wstrb    ( m_axi_wstrb   ),
    .m_axi_bvalid   ( m_axi_bvalid  ),
    .m_axi_bready   ( m_axi_bready  ),
    .m_axi_bresp    ( m_axi_bresp   ),
    .m_axi_arvalid  ( m_axi_arvalid ),
    .m_axi_arready  ( m_axi_arready ),
    .m_axi_araddr   ( m_axi_araddr  ),
    .m_axi_arsize   ( m_axi_arsize  ),
    .m_axi_arcache  ( m_axi_arcache ),
    .m_axi_arprot   ( m_axi_arprot  ),
    .m_axi_arburst  ( m_axi_arburst ),
    .m_axi_arlen    ( m_axi_arlen   ),
    .m_axi_arlock   ( m_axi_arlock  ),
    .m_axi_arqos    ( m_axi_arqos   ),
    .m_axi_rvalid   ( m_axi_rvalid  ),
    .m_axi_rready   ( m_axi_rready  ),
    .m_axi_rlast    ( m_axi_rlast   ),
    .m_axi_rdata    ( m_axi_rdata   ),
    .m_axi_rresp    ( m_axi_rresp   )
);

endmodule
