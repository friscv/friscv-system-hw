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

// CLINT register map (offsets from base address):
//   0x0000        : msip[0]        (R/W, bit 0 only)
//   0x4000        : mtimecmp[31:0] (R/W)
//   0x4004        : mtimecmp[63:32](R/W)
//   0xBFF8        : mtime[31:0]    (R/W)
//   0xBFFC        : mtime[63:32]   (R/W)

module friscv_clint (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_in CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET rstn_in" *)
    input  wire        clk_in,

    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn_in RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rstn_in,
    
    output wire [63:0] time_out,

    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    output reg [31:0]  s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    output wire        msip_out,
    output wire        mtip_out
);

reg [63:0] mtime    = 0;
reg [63:0] mtimecmp = 64'hFFFFFFFFFFFFFFFF;
reg        msip     = 0;

reg [31:0] waddr = 32'b0;
reg [31:0] wdata = 32'b0;
reg awcomplete = 0;
reg wcomplete  = 0;

assign time_out = mtime;

// Write channel
always @(posedge clk_in) begin
    if (!rstn_in) begin
        mtime     <= 64'b0;
        mtimecmp  <= 64'hFFFFFFFFFFFFFFFF;
        msip      <= 1'b0;
        waddr     <= 32'b0;
        wdata     <= 32'b0;
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_bvalid  <= 1'b0;
        awcomplete    <= 1'b0;
        wcomplete     <= 1'b0;
    end else begin
        mtime <= mtime + 1;

        if (!awcomplete && !s_axi_awready && s_axi_awvalid) begin
            s_axi_awready <= 1'b1;
        end else if (s_axi_awvalid && s_axi_awready) begin
            waddr         <= s_axi_awaddr;
            s_axi_awready <= 1'b0;
            awcomplete    <= 1'b1;
        end

        if (!wcomplete && !s_axi_wready && s_axi_wvalid) begin
            s_axi_wready <= 1'b1;
        end else if (s_axi_wvalid && s_axi_wready) begin
            wdata        <= s_axi_wdata;
            s_axi_wready <= 1'b0;
            wcomplete    <= 1'b1;
        end

        if (wcomplete && awcomplete && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            case (waddr[15:0])
                16'h0000: msip           <= wdata[0];
                16'h4000: mtimecmp[31:0]  <= wdata;
                16'h4004: mtimecmp[63:32] <= wdata;
                16'hBFF8: mtime[31:0]     <= wdata;
                16'hBFFC: mtime[63:32]    <= wdata;
                default: ;
            endcase
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
            wcomplete    <= 1'b0;
            awcomplete   <= 1'b0;
        end
    end
end

// Read channel
always @(posedge clk_in) begin
    if (!rstn_in) begin
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rdata   <= 32'b0;
    end else begin
        if (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
        end else if (s_axi_arvalid && s_axi_arready) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b1;
            case (s_axi_araddr[15:0])
                16'h0000: s_axi_rdata <= {31'b0, msip};
                16'h4000: s_axi_rdata <= mtimecmp[31:0];
                16'h4004: s_axi_rdata <= mtimecmp[63:32];
                16'hBFF8: s_axi_rdata <= mtime[31:0];
                16'hBFFC: s_axi_rdata <= mtime[63:32];
                default:  s_axi_rdata <= 32'b0;
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

assign s_axi_bresp = 2'b00;
assign s_axi_rresp = 2'b00;
assign msip_out    = msip;
assign mtip_out    = (mtime >= mtimecmp);

endmodule
