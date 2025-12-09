`include "friscv_pkg.sv"

module single_beat_axi_master(
    input  logic                    i_clk,
    input  logic                    i_rstn,

    input  logic [2:0]              i_size,
    input  logic [31:0]             i_addr,
    input  logic [DATA_WIDTH-1:0]   i_wdata,
    output logic [DATA_WIDTH-1:0]   o_rdata,
    input  logic [1:0]              i_rw,
    output logic                    o_wait,
    input  logic                    i_clear,
    output logic                    o_done,
    output logic                    o_error,
    output logic                    o_invalid,

    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [31:0]             m_axi_awaddr,
    output logic [2:0]              m_axi_awsize,
    output logic [3:0]              m_axi_awcache,
    output logic [2:0]              m_axi_awprot,
    output logic [1:0]              m_axi_awburst,
    output logic [7:0]              m_axi_awlen,
    output logic                    m_axi_awlock,
    output logic [3:0]              m_axi_awqos,

    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic                    m_axi_wlast,
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,

    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    input  logic [1:0]              m_axi_bresp,

    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    output logic [31:0]             m_axi_araddr,
    output logic [2:0]              m_axi_arsize,
    output logic [3:0]              m_axi_arcache,
    output logic [2:0]              m_axi_arprot,
    output logic [1:0]              m_axi_arburst,
    output logic [7:0]              m_axi_arlen,
    output logic                    m_axi_arlock,
    output logic [3:0]              m_axi_arqos,

    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic                    m_axi_rlast,
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp
);

typedef enum logic [3:0] {
    S_IDLE        = 4'b0000,
    S_DONE        = 4'b0001,
    S_ERROR       = 4'b0010,
    S_INVALID     = 4'b0011,
    S_W_SET_ADDR  = 4'b0100,
    S_W_ADDR_WAIT = 4'b0101,
    S_W_DATA_LAST = 4'b0110,
    S_W_RET       = 4'b0111,
    S_R_SET_ADDR  = 4'b1000,
    S_R_ADDR_WAIT = 4'b1001,
    S_R_DATA_LAST = 4'b1010
} state_e;

state_e r_state;
state_e w_next_state;

logic [2:0] r_size;
logic [1:0] r_rw;

logic [31:0] r_addr;
logic [DATA_WIDTH-1:0] r_wdata;
logic [DATA_WIDTH-1:0] r_rdata;

logic [DATA_WIDTH-1:0] size_mask;
logic [DATA_WIDTH/8-1:0] base_strb;
logic [$clog2(DATA_WIDTH/8)-1:0] byte_offset;
assign byte_offset = r_addr[$clog2(DATA_WIDTH/8)-1:0];
assign m_axi_wstrb = base_strb << byte_offset;

generate
    if (DATA_WIDTH == 64) begin
        always_comb begin
            case (r_size)
                AXI_SIZE_BYTE: size_mask = 64'h00000000_000000FF;
                AXI_SIZE_HALF: size_mask = 64'h00000000_0000FFFF;
                AXI_SIZE_WORD: size_mask = 64'h00000000_FFFFFFFF;
                default:       size_mask = 64'hFFFFFFFF_FFFFFFFF;
            endcase

            case (r_size)
                AXI_SIZE_BYTE: base_strb = 8'b0000_0001;
                AXI_SIZE_HALF: base_strb = 8'b0000_0011;
                AXI_SIZE_WORD: base_strb = 8'b0000_1111;
                default:       base_strb = 8'b1111_1111;
            endcase
        end
        
    end else begin
        always_comb begin
            case (r_size)
                AXI_SIZE_BYTE: size_mask = 32'h000000FF;
                AXI_SIZE_HALF: size_mask = 32'h0000FFFF;
                default:       size_mask = 32'hFFFFFFFF;
            endcase

            case (r_size)
                AXI_SIZE_BYTE: base_strb = 4'b0001;
                AXI_SIZE_HALF: base_strb = 4'b0011;
                default:       base_strb = 4'b1111;
            endcase
        end
    end
endgenerate

logic misaligned_request;
assign misaligned_request = (i_rw != RW_IDLE) && (
    ((i_size == AXI_SIZE_HALF) && (i_addr[0] != 1'b0)) ||
    ((i_size == AXI_SIZE_WORD) && (i_addr[1:0] != 2'b00)) ||
    ((i_size == AXI_SIZE_DWORD) && (i_addr[2:0] != 3'b000))
);

assign o_rdata       = (m_axi_rvalid && m_axi_rready) ? (m_axi_rdata >> (byte_offset * 8)) & size_mask : r_rdata;
assign m_axi_awaddr  = r_addr;
assign m_axi_awsize  = r_size;
assign m_axi_awvalid = r_state == S_W_SET_ADDR || r_state == S_W_ADDR_WAIT;
assign m_axi_awcache = 4'b0010;
assign m_axi_awprot  = 3'b000;
assign m_axi_awburst = 2'b01; 
assign m_axi_awlen   = 8'h00;
assign m_axi_awlock  = 1'b0;
assign m_axi_awqos   = 4'h0;

assign m_axi_wdata   = r_wdata << (byte_offset * 8);
assign m_axi_araddr  = r_addr;
assign m_axi_arsize  = r_size;
assign m_axi_arvalid = r_state == S_R_SET_ADDR || r_state == S_R_ADDR_WAIT;
assign m_axi_arcache = 4'b0010;
assign m_axi_arprot  = 3'b000;
assign m_axi_arburst = 2'b01;
assign m_axi_arlen   = 8'h00;
assign m_axi_arlock  = 1'b0;
assign m_axi_arqos   = 4'h0;

always_ff @(posedge i_clk) begin
    if (!i_rstn) begin
        r_state <= S_IDLE;
        r_addr  <= '0;
        r_wdata <= '0;
        r_rdata <= '0;
        r_size  <= '0;
        r_rw    <= '0;
    end else begin
        r_state <= w_next_state;
        if (r_state < 4 && i_rw != RW_IDLE) begin
            r_addr  <= i_addr;
            r_wdata <= i_wdata;
            r_size  <= i_size;
            r_rw    <= i_rw;
        end
        if (m_axi_rready && m_axi_rvalid) begin
            r_rdata <= (m_axi_rdata >> (byte_offset * 8)) & size_mask;
        end
    end
end

always_comb begin
    w_next_state  = r_state;
    o_wait        = (r_state >= 4);
    m_axi_wvalid  = '0;
    m_axi_wlast   = '0;
    m_axi_bready  = '0;
    m_axi_rready  = '0;
    o_done        = '0;
    o_error       = '0;
    o_invalid     = '0;

    unique case (r_state)

    // Idle states
    S_IDLE, S_DONE, S_ERROR, S_INVALID: begin
        if (i_rw == RW_WRITE || i_rw == RW_READ) begin
            if (misaligned_request) begin
                w_next_state = S_INVALID;
                o_done = 1'b1;
                o_error = 1'b1;
                o_invalid = 1'b1;
            end else begin
                w_next_state = (i_rw == RW_WRITE) ? S_W_SET_ADDR : S_R_SET_ADDR;
                o_wait = 1'b1;
            end
        end else begin
            w_next_state = (i_clear) ? S_IDLE : r_state;
            o_done = (i_clear) ? 1'b0 : (r_state != S_IDLE);
            o_error = (i_clear) ? 1'b0 : (r_state == S_ERROR || r_state == S_INVALID);
            o_invalid = (i_clear) ? 1'b0 : (r_state == S_INVALID);
        end
    end

    // Write path
    S_W_SET_ADDR: begin
        w_next_state  = (m_axi_awready) ? S_W_DATA_LAST : S_W_ADDR_WAIT;
    end

    S_W_ADDR_WAIT: begin
        w_next_state = (m_axi_awready) ? S_W_DATA_LAST : S_W_ADDR_WAIT;
    end

    S_W_DATA_LAST: begin
        m_axi_wvalid = 1'b1;
        if (m_axi_wready) begin
            w_next_state = S_W_RET;
            m_axi_wlast  = 1'b1;
        end
    end

    S_W_RET: begin
        m_axi_bready = 1'b1;
        if (m_axi_bvalid) begin
            o_wait = 1'b0;
            o_done = 1'b1;
            o_error = (m_axi_bresp != AXI_RESP_OKAY);
            o_invalid = (m_axi_bresp == AXI_RESP_DECERR);
            w_next_state = (i_clear)                        ? S_IDLE    :
                           (m_axi_bresp == AXI_RESP_DECERR) ? S_INVALID :
                           (m_axi_bresp != AXI_RESP_OKAY)   ? S_ERROR   : S_DONE;
        end
    end

    // Read path
    S_R_SET_ADDR: begin
        w_next_state  = (m_axi_arready) ? S_R_DATA_LAST :  S_R_ADDR_WAIT;
    end

    S_R_ADDR_WAIT: begin
        w_next_state = (m_axi_arready) ? S_R_DATA_LAST : S_R_ADDR_WAIT;
    end

    S_R_DATA_LAST: begin
        m_axi_rready = 1'b1;
        if (m_axi_rvalid) begin
            o_wait = 1'b0;
            o_done = 1'b1;
            o_error = (m_axi_rresp != AXI_RESP_OKAY);
            o_invalid = (m_axi_rresp == AXI_RESP_DECERR);
            w_next_state = (i_clear)                        ? S_IDLE    :
                           (m_axi_rresp == AXI_RESP_DECERR) ? S_INVALID :
                           (m_axi_rresp != AXI_RESP_OKAY)   ? S_ERROR   : S_DONE;
        end
    end
    endcase
end

endmodule
