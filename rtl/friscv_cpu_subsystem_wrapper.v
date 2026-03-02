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

// Pure Verilog wrapper for Vivado block design integration
// The actual implementation is in friscv_cpu_subsystem.sv
module friscv_cpu_subsystem_wrapper (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi, ASSOCIATED_RESET aresetn" *)
    input  wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire aresetn,

    output wire done,
    input  wire i_timer_irq,

    // AXI4 Master Write Address Channel
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awsize,
    output wire [3:0]  m_axi_awcache,
    output wire [2:0]  m_axi_awprot,
    output wire [1:0]  m_axi_awburst,
    output wire [7:0]  m_axi_awlen,
    output wire        m_axi_awlock,
    output wire [3:0]  m_axi_awqos,

    // AXI4 Master Write Data Channel
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire        m_axi_wlast,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,

    // AXI4 Master Write Response Channel
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    input  wire [1:0]  m_axi_bresp,

    // AXI4 Master Read Address Channel
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arsize,
    output wire [3:0]  m_axi_arcache,
    output wire [2:0]  m_axi_arprot,
    output wire [1:0]  m_axi_arburst,
    output wire [7:0]  m_axi_arlen,
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arqos,

    // AXI4 Master Read Data Channel
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire        m_axi_rlast,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp
);

friscv_cpu_subsystem cpu_subsystem (
    .i_clk          ( aclk          ),
    .i_rstn         ( aresetn       ),
    .o_end          ( done          ),
    .i_timer_irq    ( i_timer_irq   ),
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
