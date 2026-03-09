`timescale 1ns / 1ps
`define SIMULATION_MODE

module tb_integration;

parameter CLK_PERIOD = 20;      // 20ns clock period (50MHz)
parameter MAX_CYCLES = 100000;  // Maximum simulation cycles
// PROG_FILE is set at runtime via +PROG_FILE=<path> (xsim plusarg)
// Default: ../../../../../test/prog.bin
string PROG_FILE;

parameter MEM_SIZE = 2 * 1024;          // 2 KiB
parameter CPU_MEM_BASE = 32'h80000000;  // Memory base address (CPU view)
parameter DRAM_BASE    = 32'h00100000;  // Memory base address (Memory view)
parameter GPIO_ADDR    = 32'h40000000;  // GPIO address
parameter UART_ADDR    = 32'h40600000;  // UART address
parameter TIMER_ADDR   = 32'h40100000;  // Timer base address
parameter RESULT_ADDR  = 32'h80000500;  // Result address (CPU view)

logic clk;
logic rstn;
logic end_signal;

logic w_mtip;
logic w_msip;

// AXI Signals
logic        m_axi_awvalid;
logic        m_axi_awready;
logic [31:0] m_axi_awaddr;
logic [2:0]  m_axi_awsize;
logic [3:0]  m_axi_awcache;
logic [2:0]  m_axi_awprot;
logic [1:0]  m_axi_awburst;
logic [7:0]  m_axi_awlen;
logic        m_axi_awlock;
logic [3:0]  m_axi_awqos;

logic        m_axi_wvalid;
logic        m_axi_wready;
logic        m_axi_wlast;
logic [31:0] m_axi_wdata;
logic [3:0]  m_axi_wstrb;

logic        m_axi_bvalid;
logic        m_axi_bready;
logic [1:0]  m_axi_bresp;

logic        m_axi_arvalid;
logic        m_axi_arready;
logic [31:0] m_axi_araddr;
logic [2:0]  m_axi_arsize;
logic [3:0]  m_axi_arcache;
logic [2:0]  m_axi_arprot;
logic [1:0]  m_axi_arburst;
logic [7:0]  m_axi_arlen;
logic        m_axi_arlock;
logic [3:0]  m_axi_arqos;

logic        m_axi_rvalid;
logic        m_axi_rready;
logic        m_axi_rlast;
logic [31:0] m_axi_rdata;
logic [1:0]  m_axi_rresp;

// Memory Model and GPIO
logic [7:0]  memory [MEM_SIZE];
logic [31:0] gpio_reg;
int cycle_count;
int mem_read_count;
int mem_write_count;

// =========================================================================
// Address-based AXI routing: timer vs memory/GPIO/UART slave
// =========================================================================
logic wr_to_timer, rd_to_timer;
assign wr_to_timer = (m_axi_awaddr >= TIMER_ADDR) && (m_axi_awaddr < (TIMER_ADDR + 32'hC000));
assign rd_to_timer = (m_axi_araddr >= TIMER_ADDR) && (m_axi_araddr < (TIMER_ADDR + 32'hC000));

// Timer AXI slave signals
logic        tmr_awready, tmr_wready, tmr_bvalid;
logic [1:0]  tmr_bresp;
logic        tmr_arready, tmr_rvalid;
logic [31:0] tmr_rdata;
logic [1:0]  tmr_rresp;

// Memory/GPIO/UART slave AXI signals
logic        mem_awready, mem_wready, mem_bvalid;
logic [1:0]  mem_bresp;
logic        mem_arready, mem_rvalid, mem_rlast;
logic [31:0] mem_rdata;
logic [1:0]  mem_rresp;

// Mux slave responses back to master
assign m_axi_awready = wr_to_timer ? tmr_awready : mem_awready;
assign m_axi_wready  = wr_to_timer ? tmr_wready  : mem_wready;
assign m_axi_bvalid  = wr_to_timer ? tmr_bvalid  : mem_bvalid;
assign m_axi_bresp   = wr_to_timer ? tmr_bresp   : mem_bresp;
assign m_axi_arready = rd_to_timer ? tmr_arready : mem_arready;
assign m_axi_rvalid  = rd_to_timer ? tmr_rvalid  : mem_rvalid;
assign m_axi_rdata   = rd_to_timer ? tmr_rdata   : mem_rdata;
assign m_axi_rresp   = rd_to_timer ? tmr_rresp   : mem_rresp;
assign m_axi_rlast   = rd_to_timer ? tmr_rvalid  : mem_rlast;

// Timer hardware
friscv_clint clint_inst (
    .clk_in         ( clk                         ),
    .rstn_in        ( rstn                        ),
    .s_axi_awaddr   ( m_axi_awaddr                ),
    .s_axi_awvalid  ( m_axi_awvalid & wr_to_timer ),
    .s_axi_awready  ( tmr_awready                 ),
    .s_axi_wdata    ( m_axi_wdata                 ),
    .s_axi_wvalid   ( m_axi_wvalid & wr_to_timer  ),
    .s_axi_wready   ( tmr_wready                  ),
    .s_axi_bresp    ( tmr_bresp                   ),
    .s_axi_bvalid   ( tmr_bvalid                  ),
    .s_axi_bready   ( m_axi_bready & wr_to_timer  ),
    .s_axi_araddr   ( m_axi_araddr                ),
    .s_axi_arvalid  ( m_axi_arvalid & rd_to_timer ),
    .s_axi_arready  ( tmr_arready                 ),
    .s_axi_rdata    ( tmr_rdata                   ),
    .s_axi_rresp    ( tmr_rresp                   ),
    .s_axi_rvalid   ( tmr_rvalid                  ),
    .s_axi_rready   ( m_axi_rready & rd_to_timer  ),
    .msip_out       ( w_msip                      ),
    .mtip_out       ( w_mtip                      )
);

// DUT Instantiation
friscv_cpu_subsystem dut (
    .i_clk         ( clk           ),
    .i_rstn        ( rstn          ),
    .o_end         ( end_signal    ),
    
    .i_msip        ( w_msip        ),
    .i_mtip        ( w_mtip        ),
    .i_meip        ( 1'b0          ),

    // AXI4 Master Write Address Channel
    .m_axi_awvalid ( m_axi_awvalid ),
    .m_axi_awready ( m_axi_awready ),
    .m_axi_awaddr  ( m_axi_awaddr  ),
    .m_axi_awsize  ( m_axi_awsize  ),
    .m_axi_awcache ( m_axi_awcache ),
    .m_axi_awprot  ( m_axi_awprot  ),
    .m_axi_awburst ( m_axi_awburst ),
    .m_axi_awlen   ( m_axi_awlen   ),
    .m_axi_awlock  ( m_axi_awlock  ),
    .m_axi_awqos   ( m_axi_awqos   ),

    // AXI4 Master Write Data Channel
    .m_axi_wvalid  ( m_axi_wvalid  ),
    .m_axi_wready  ( m_axi_wready  ),
    .m_axi_wlast   ( m_axi_wlast   ),
    .m_axi_wdata   ( m_axi_wdata   ),
    .m_axi_wstrb   ( m_axi_wstrb   ),

    // AXI4 Master Write Response Channel
    .m_axi_bvalid  ( m_axi_bvalid  ),
    .m_axi_bready  ( m_axi_bready  ),
    .m_axi_bresp   ( m_axi_bresp   ),

    // AXI4 Master Read Address Channel
    .m_axi_arvalid ( m_axi_arvalid ),
    .m_axi_arready ( m_axi_arready ),
    .m_axi_araddr  ( m_axi_araddr  ),
    .m_axi_arsize  ( m_axi_arsize  ),
    .m_axi_arcache ( m_axi_arcache ),
    .m_axi_arprot  ( m_axi_arprot  ),
    .m_axi_arburst ( m_axi_arburst ),
    .m_axi_arlen   ( m_axi_arlen   ),
    .m_axi_arlock  ( m_axi_arlock  ),
    .m_axi_arqos   ( m_axi_arqos   ),

    // AXI4 Master Read Data Channel
    .m_axi_rvalid  ( m_axi_rvalid  ),
    .m_axi_rready  ( m_axi_rready  ),
    .m_axi_rlast   ( m_axi_rlast   ),
    .m_axi_rdata   ( m_axi_rdata   ),
    .m_axi_rresp   ( m_axi_rresp   )
);

// Clock Generation
initial begin
    clk = 1;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// Cycle Counter
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn)
        cycle_count <= 0;
    else
        cycle_count <= cycle_count + 1;
end

// =========================================================================
// AXI Slave: Memory + GPIO + UART
// =========================================================================

logic [31:0] write_addr;
logic [31:0] read_addr;
logic        write_addr_received;
logic        read_addr_received;

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        mem_awready <= 0;
        mem_wready  <= 0;
        mem_bvalid  <= 0;
        mem_bresp   <= 0;
        mem_arready <= 0;
        mem_rvalid  <= 0;
        mem_rdata   <= 0;
        mem_rresp   <= 0;
        mem_rlast   <= 0;

        write_addr_received <= 0;
        read_addr_received  <= 0;
        write_addr <= 0;
        read_addr  <= 0;

        gpio_reg <= 0;
        mem_read_count  <= 0;
        mem_write_count <= 0;
    end else begin
        // -----------------------
        // Write Channel
        // -----------------------

        // Write Address (ignore timer-addressed transactions)
        if (m_axi_awvalid && !wr_to_timer && !mem_awready && !write_addr_received) begin
            mem_awready <= 1;
            write_addr <= m_axi_awaddr;
            write_addr_received <= 1;
        end else begin
            mem_awready <= 0;
        end

        // Write Data
        if (m_axi_wvalid && !wr_to_timer && !mem_wready && write_addr_received) begin
            mem_wready <= 1;
            if (write_addr == GPIO_ADDR) begin
                if (m_axi_wstrb[0]) gpio_reg[7:0]   <= m_axi_wdata[7:0];
                if (m_axi_wstrb[1]) gpio_reg[15:8]  <= m_axi_wdata[15:8];
                if (m_axi_wstrb[2]) gpio_reg[23:16] <= m_axi_wdata[23:16];
                if (m_axi_wstrb[3]) gpio_reg[31:24] <= m_axi_wdata[31:24];
                $display("[%0t] GPIO write: 0x%08h", $time, m_axi_wdata);
            end else if (write_addr == (UART_ADDR + 32'h4)) begin
                $write("%c", m_axi_wdata[7:0]);
            end else if (write_addr >= DRAM_BASE && write_addr < DRAM_BASE + MEM_SIZE) begin
                automatic logic [31:0] idx = write_addr - DRAM_BASE;
                if (m_axi_wstrb[0]) memory[idx+0] <= m_axi_wdata[7:0];
                if (m_axi_wstrb[1]) memory[idx+1] <= m_axi_wdata[15:8];
                if (m_axi_wstrb[2]) memory[idx+2] <= m_axi_wdata[23:16];
                if (m_axi_wstrb[3]) memory[idx+3] <= m_axi_wdata[31:24];
            end
            mem_write_count <= mem_write_count + 1;
        end else begin
            mem_wready <= 0;
        end

        // Write Response
        if (write_addr_received && m_axi_wvalid && !wr_to_timer && mem_wready) begin
            mem_bvalid <= 1;
            mem_bresp  <= 2'b00;
            write_addr_received <= 0;
        end else if (mem_bvalid && m_axi_bready) begin
            mem_bvalid <= 0;
        end

        // -----------------------
        // Read Channel
        // -----------------------

        // Read Address
        if (m_axi_arvalid && !rd_to_timer && !mem_arready && !mem_rvalid) begin
            mem_arready <= 1;
            read_addr <= m_axi_araddr;
            read_addr_received <= 1;
        end else begin
            mem_arready <= 0;
        end

        // Read Data
        if (read_addr_received && !mem_rvalid) begin
            mem_rvalid <= 1;
            mem_rlast  <= 1;
            mem_rresp  <= 2'b00;

            if (read_addr >= GPIO_ADDR && read_addr < (GPIO_ADDR + 32'h20)) begin
                mem_rdata <= 32'h0;  // Boot mode 0: DRAM direct jump
            end else if (read_addr >= UART_ADDR && read_addr < (UART_ADDR + 32'h20)) begin
                // STATUS (offset 0x8): TX_EMPTY=1 so uart_putc/uart_puts don't spin
                mem_rdata <= (read_addr == (UART_ADDR + 32'h8)) ? 32'h4 : 32'h0;
            end else if (read_addr >= DRAM_BASE && read_addr < DRAM_BASE + MEM_SIZE) begin
                automatic logic [31:0] idx = (read_addr - DRAM_BASE) & 32'hFFFFFFFC;
                mem_rdata <= {memory[idx+3], memory[idx+2], memory[idx+1], memory[idx]};
            end else begin
                mem_rdata <= 32'hDEADC0DE;
            end
            mem_read_count <= mem_read_count + 1;
            read_addr_received <= 0;
        end else if (mem_rvalid && m_axi_rready) begin
            mem_rvalid <= 0;
            mem_rlast  <= 0;
        end
    end
end

// =========================================================================
// Main Test Procedure
// =========================================================================
initial begin
    int fd;
    int bytes_read;
    
    $display("==============================================");
    $display("FRISCV Integration Testbench");
    $display("==============================================");
    $display("CPU Memory Base: 0x%08h", CPU_MEM_BASE);
    $display("AXI RAM Base:    0x%08h", DRAM_BASE);
    $display("GPIO:            0x%08h", GPIO_ADDR);
    $display("==============================================");
    
    rstn = 0;

    // Resolve program file: +PROG_FILE=<path> overrides the default
    if (!$value$plusargs("PROG_FILE=%s", PROG_FILE))
        PROG_FILE = "../../../../../test/prog.bin";

    // Initialize memory
    for (int i = 0; i < MEM_SIZE; i++) memory[i] = 8'h0;
    
    // Load program
    $display("Loading: %s", PROG_FILE);
    fd = $fopen(PROG_FILE, "rb");
    if (fd == 0) begin
        $display("ERROR: Cannot open file");
    end else begin
        bytes_read = 0;
        while (!$feof(fd) && bytes_read < MEM_SIZE) begin
            automatic int result = $fgetc(fd);
            if (result != -1) begin
                memory[bytes_read] = result[7:0];
                bytes_read++;
            end
        end
        $fclose(fd);
        $display("Loaded %0d bytes", bytes_read);
    end
    
    repeat(10) @(posedge clk);
    rstn = 1;
    $display("Starting execution...");
    
    // Wait for end signal or timeout
    for (int i = 0; i < MAX_CYCLES; i++) begin
        @(posedge clk);
        if (end_signal) begin
            $display("End signal at cycle %0d", cycle_count);
            break;
        end
    end
    
    // Print results
    $display("==============================================");
    $display("Completed after %0d cycles", cycle_count);
    $display("Reads: %0d, Writes: %0d", mem_read_count, mem_write_count);
    $display("==============================================");
    $display("GPIO (0x%08h):   0x%08h", GPIO_ADDR, gpio_reg);
    begin
        // Calculate offset in memory array
        // RESULT_ADDR is CPU view (e.g. 0x80000400). RAM Base is 0x0.
        // So we need to subtract CPU_MEM_BASE to get AXI address/index
        automatic logic [31:0] offset = RESULT_ADDR - CPU_MEM_BASE;
        automatic logic [31:0] result = {memory[offset+3], memory[offset+2], memory[offset+1], memory[offset]};
        $display("Result (0x%08h): 0x%08h", RESULT_ADDR, result);
    end
    $display("==============================================");
    
    if (gpio_reg == 32'hAABBCCDD)
        $display("[RESULT] PASS");
    else
        $display("[RESULT] FAIL (GPIO = 0x%08h)", gpio_reg);
    
    $finish;
end

initial begin
    #(CLK_PERIOD * MAX_CYCLES * 2);
    $display("ERROR: Timeout!");
    $display("[RESULT] FAIL (timeout)");
    $finish;
end

endmodule
