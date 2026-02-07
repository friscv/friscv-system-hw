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

module friscv_axi_master (
    input  logic                    i_clk,
    input  logic                    i_rstn,

    input  mem_width_t              i_size,
    input  logic [31:0]             i_addr,
    input  data_t                   i_wdata,
    output data_t                   o_rdata,
    input  rw_cmd_t                 i_rw,
    output logic                    o_wait,

    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [31:0]             m_axi_awaddr,
    output mem_width_t              m_axi_awsize,
    output logic [3:0]              m_axi_awcache,
    output logic [2:0]              m_axi_awprot,
    output logic [1:0]              m_axi_awburst,
    output logic [7:0]              m_axi_awlen,
    output logic                    m_axi_awlock,
    output logic [3:0]              m_axi_awqos,

    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic                    m_axi_wlast,
    output data_t                   m_axi_wdata,
    output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,

    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    input  logic [1:0]              m_axi_bresp,

    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    output logic [31:0]             m_axi_araddr,
    output mem_width_t              m_axi_arsize,
    output logic [3:0]              m_axi_arcache,
    output logic [2:0]              m_axi_arprot,
    output logic [1:0]              m_axi_arburst,
    output logic [7:0]              m_axi_arlen,
    output logic                    m_axi_arlock,
    output logic [3:0]              m_axi_arqos,

    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic                    m_axi_rlast,
    input  data_t                   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp
);

typedef enum logic [2:0] {
    S_IDLE,
    S_W_ADDR,
    S_W_DATA,
    S_W_RET,
    S_R_ADDR,
    S_R_DATA
} state_e;

// Internal signals
state_e r_state, w_next_state;

mem_width_t r_size;
rw_cmd_t r_rw;

logic [31:0] r_addr;
data_t r_wdata, r_rdata;

// Data width and alignment
logic [DATA_WIDTH/8-1:0] base_strb;
logic [$clog2(DATA_WIDTH/8)-1:0] byte_offset;
assign byte_offset = r_addr[$clog2(DATA_WIDTH/8)-1:0];
assign m_axi_wstrb = base_strb << byte_offset;

always_comb begin
    case (r_size)
        WIDTH_I8, WIDTH_U8:   base_strb = 4'b0001;
        WIDTH_I16, WIDTH_U16: base_strb = 4'b0011;
        default:              base_strb = 4'b1111;
    endcase
end

// Constant assignments
assign o_rdata       = (m_axi_rvalid && m_axi_rready) ? m_axi_rdata : r_rdata;
assign m_axi_awaddr  = r_addr;
assign m_axi_awsize  = r_size;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot  = 3'b000;
assign m_axi_awburst = 2'b01; 
assign m_axi_awlen   = 8'h00;
assign m_axi_awlock  = 1'b0;
assign m_axi_awqos   = 4'h0;

assign m_axi_wdata   = r_wdata;
assign m_axi_araddr  = r_addr;
assign m_axi_arsize  = r_size;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot  = 3'b000;
assign m_axi_arburst = 2'b01;
assign m_axi_arlen   = 8'h00;
assign m_axi_arlock  = 1'b0;
assign m_axi_arqos   = 4'h0;

//assign o_wait = r_state != S_IDLE || (i_rw != RW_IDLE);
assign o_wait = w_next_state != S_IDLE;

// Clocked logic
always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
        r_rw <= RW_IDLE;
        r_state <= S_IDLE;
        {r_addr, r_wdata, r_rdata, r_size} <= '0;
    end else begin
        r_state <= w_next_state;
        if (r_state == S_IDLE && i_rw != RW_IDLE) begin
            r_rw    <= i_rw;
            r_addr  <= i_addr;
            r_wdata <= i_wdata;
            r_size  <= i_size;
        end
        if (m_axi_rready && m_axi_rvalid) begin
            r_rdata <= m_axi_rdata;
        end
    end
end

// State transition logic
always_comb begin
    w_next_state  = r_state;
    m_axi_awvalid = 1'b0;
    m_axi_wvalid  = 1'b0;
    m_axi_wlast   = 1'b0;
    m_axi_bready  = 1'b0;
    m_axi_arvalid = 1'b0;
    m_axi_rready  = 1'b0;

    unique case (r_state)
        S_IDLE: begin
            if (i_rw == RW_WRITE || i_rw == RW_READ) begin
                w_next_state = (i_rw == RW_WRITE) ? S_W_ADDR : S_R_ADDR;
            end
        end
        S_W_ADDR: begin
            m_axi_awvalid = 1'b1;
            w_next_state  = (m_axi_awready) ? S_W_DATA : S_W_ADDR;
        end
        S_W_DATA: begin
            m_axi_wvalid = 1'b1;
            m_axi_wlast  = 1'b1;
            if (m_axi_wready) begin
                w_next_state = S_W_RET;
            end
        end
        S_W_RET: begin
            m_axi_bready = 1'b1;
            if (m_axi_bvalid) begin
                w_next_state = S_IDLE;
            end
        end
        S_R_ADDR: begin
            m_axi_arvalid = 1'b1;
            w_next_state  = (m_axi_arready) ? S_R_DATA :  S_R_ADDR;
        end
        S_R_DATA: begin
            m_axi_rready = 1'b1;
            if (m_axi_rvalid) begin
                w_next_state = S_IDLE;
            end
        end
    endcase
end

endmodule
