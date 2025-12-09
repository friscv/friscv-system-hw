`include "friscv_pkg.sv"

module friscv_l1_subsystem(
    input  logic i_clk,
    input  logic i_rstn,

    // Instruction Memory Interface
    input  logic [ADDR_WIDTH-1:0] i_inst_addr,
    output logic [DATA_WIDTH-1:0] o_inst_data,
    input  logic                  i_inst_en,
    output logic                  o_inst_wait,

    // Data Memory Interface
    input  logic [ADDR_WIDTH-1:0] i_data_addr,
    input  logic [DATA_WIDTH-1:0] i_data_wdata,
    output logic [DATA_WIDTH-1:0] o_data_rdata,
    input  logic                  i_data_en,
    input  logic                  i_data_wr,
    output logic                  o_data_wait,

    // External Interface
    output logic [2:0]            o_mem_size,
    output logic [ADDR_WIDTH-1:0] o_mem_addr,
    output logic [DATA_WIDTH-1:0] o_mem_wdata,
    input  logic [DATA_WIDTH-1:0] i_mem_rdata,
    output logic [1:0]            o_mem_rw,
    input  logic                  i_mem_wait
);

// Grant signals from arbiter
logic w_data_grant;
logic w_inst_grant;

// Pending request tracking
logic r_inst_pending;
logic r_data_pending;

// Combinatorial pending signals for same-cycle grant detection
logic w_inst_pending;
logic w_data_pending;

// Track which master is currently being served
logic r_inst_granted;
logic r_data_granted;

// Requests for arbiter - include both new requests and pending requests
logic w_inst_req;
logic w_data_req;

assign w_inst_req = i_inst_en || r_inst_pending;
assign w_data_req = i_data_en || r_data_pending;

round_robin_arbiter #(.PORTS(2)) l2_arbiter (
    .i_clk       (i_clk),
    .i_rstn      (i_rstn),
    .i_req_vec   ({w_data_req, w_inst_req}),
    .o_grant_vec ({w_data_grant, w_inst_grant})
);

// Pending request state machine
// A request becomes pending when en goes high
// A request is cleared when it's granted AND the transfer completes (i_mem_wait goes low)
always_ff @(posedge i_clk) begin
    if (!i_rstn) begin
        r_inst_pending  <= 1'b0;
        r_data_pending  <= 1'b0;
        r_inst_granted  <= 1'b0;
        r_data_granted  <= 1'b0;
    end else begin
        // Instruction pending logic
        if (i_inst_en && !w_inst_grant) begin
            // New request but not granted - set pending
            r_inst_pending <= 1'b1;
        end else if (i_inst_en && w_inst_grant && i_mem_wait) begin
            // Granted but transfer not complete - set pending
            r_inst_pending <= 1'b1;
        end else if (r_inst_pending && w_inst_grant && !i_mem_wait) begin
            // Pending request granted and transfer complete - clear pending
            r_inst_pending <= 1'b0;
        end else if (i_inst_en && w_inst_grant && !i_mem_wait) begin
            // New request granted and completes same cycle - no pending
            r_inst_pending <= 1'b0;
        end

        // Data pending logic
        if (i_data_en && !w_data_grant) begin
            // New request but not granted - set pending
            r_data_pending <= 1'b1;
        end else if (i_data_en && w_data_grant && i_mem_wait) begin
            // Granted but transfer not complete - set pending
            r_data_pending <= 1'b1;
        end else if (r_data_pending && w_data_grant && !i_mem_wait) begin
            // Pending request granted and transfer complete - clear pending
            r_data_pending <= 1'b0;
        end else if (i_data_en && w_data_grant && !i_mem_wait) begin
            // New request granted and completes same cycle - no pending
            r_data_pending <= 1'b0;
        end

        r_inst_granted <= w_inst_grant;
        r_data_granted <= w_data_grant;
    end
end

// Wait signal generation
// Wait is high when:
// 1. There's a new request (en high) that isn't completing this cycle, OR
// 2. There's a pending request that hasn't completed yet
always_comb begin
    // Instruction wait: high if request pending or new request not completing
    w_inst_pending = r_inst_pending || (i_inst_en && (!w_inst_grant || i_mem_wait));
    o_inst_wait = w_inst_pending;

    // Data wait: high if request pending or new request not completing  
    w_data_pending = r_data_pending || (i_data_en && (!w_data_grant || i_mem_wait));
    o_data_wait = w_data_pending;
end

// Forward granted master to bus
always_comb begin
    o_mem_size = AXI_SIZE_WORD;
    
    // Both masters can passively read data
    o_inst_data  = i_mem_rdata;
    o_data_rdata = i_mem_rdata;

    // Use address of the granted master
    o_mem_addr = (w_data_grant) ? i_data_addr  : (w_inst_grant) ? i_inst_addr : '0;
    
    // Set write data if write-enabled master is granted
    o_mem_wdata = (w_data_grant) ? i_data_wdata : '0;
    
    // Set operation based on grant and memory stage request
    o_mem_rw = (w_data_grant &&  i_data_wr) ? RW_WRITE :
               (w_data_grant && !i_data_wr) ? RW_READ  :
               (w_inst_grant)               ? RW_READ  : RW_IDLE;
end

endmodule
