// (c) FER, HPC Architecture and Application Research Center, All rights reserved
// License and version info is listed in friscv_pkg.sv

/*
 * This module implements the top-level FRISC-V CPU subsystem implementation with an AXI4 external bus.
 * Use this module as a reference when using a different external bus.
 *
 * Note: only use fixed widths in the ports of this module, not the types defined in friscv_pkg.sv.
 */

`timescale 1ns / 1ps

import friscv_pkg::*;

module friscv_cpu_subsystem_axi (
    input  logic        i_clk,
    input  logic        i_rstn,
    output logic        o_end,
    
    input  logic        i_msip,
    input  logic        i_mtip,
    input  logic        i_meip,

    input  logic [63:0] i_mtime,
 
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

friscv_mem_if mem_if ();

friscv_cpu_subsystem_core core (
    .i_clk   ( i_clk   ),
    .i_rstn  ( i_rstn  ),
    .o_end   ( o_end   ),
    .i_msip  ( i_msip  ),
    .i_mtip  ( i_mtip  ),
    .i_meip  ( i_meip  ),
    .i_mtime ( i_mtime ),
    .mem_if  ( mem_if  )
);

friscv_axi4_full_adapter m_axi (
    .i_clk          ( i_clk         ),
    .mem_if         ( mem_if        ),
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
