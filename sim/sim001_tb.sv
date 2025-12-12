`timescale 1ns / 1ps

module sim001_tb;

    // Testbench parameters
    parameter CLK_PERIOD = 20;  // 20ns clock period (50MHz)
    parameter MAX_CYCLES = 100000;  // Maximum simulation cycles
    parameter PROG_FILE = "../../../../../software/asm/prog.bin";  // Program binary file
    
    // Memory configuration
    parameter MEM_SIZE = 2 * 1024 * 1024;  // 2 MiB
    parameter MEM_BASE = 32'h80000000;      // Memory base address
    parameter GPIO_ADDR = 32'h40000000;     // GPIO address
    parameter RESULT_ADDR = 32'h80100000;   // Result address (MEM_BASE + 1M)
    
    // Memory delay configuration
    // Set to 0 for zero latency, or a positive number for fixed delay cycles
    // Set to -1 for random delays between 0 and MAX_RANDOM_DELAY
    parameter int MEM_DELAY_CYCLES = 0;
    parameter int MAX_RANDOM_DELAY = 5;
    
    // Clock and reset
    logic clk;
    logic rstn;
    logic end_signal;
    
    // Unified memory interface (from system_top)
    logic [2:0]  mem_size;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic [1:0]  mem_rw;
    logic        mem_wait;
    
    // Memory storage
    logic [7:0] memory [MEM_SIZE];
    logic [31:0] gpio_reg;
    
    // Memory delay counter
    int mem_delay_counter;
    
    // Statistics
    int cycle_count;
    int mem_read_count;
    int mem_write_count;
    
    // DUT instantiation
    friscv_core_complex dut (
        .i_clk(clk),
        .i_rstn(rstn),
        .o_end(end_signal),
        
        // Unified Memory Interface
        .o_mem_size(mem_size),
        .o_mem_addr(mem_addr),
        .o_mem_wdata(mem_wdata),
        .i_mem_rdata(mem_rdata),
        .o_mem_rw(mem_rw),
        .i_mem_wait(mem_wait)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Delay counter and transaction tracking
    logic mem_transaction_active;
    int mem_transaction_delay;
    
    // Unified memory model with configurable delay
    always_comb begin
        mem_wait = 0;
        mem_rdata = 32'h0;
        
        if (mem_rw != 2'b00) begin
            // Determine required delay cycles
            int delay_cycles;
            if (MEM_DELAY_CYCLES < 0) begin
                delay_cycles = mem_transaction_delay;  // Use pre-calculated random delay
            end else begin
                delay_cycles = MEM_DELAY_CYCLES;
            end
            
            // Assert wait if we haven't satisfied the delay requirement
            if (mem_delay_counter < delay_cycles) begin
                mem_wait = 1;
            end else begin
                // Delay satisfied, provide data for reads
                mem_wait = 0;
                
                // Handle memory/GPIO read operations
                if (mem_addr == GPIO_ADDR && mem_rw == 2'b10) begin
                    // GPIO register read (RW_READ = 2'b10)
                    mem_rdata = gpio_reg;
                end else if (mem_addr >= MEM_BASE && mem_addr < (MEM_BASE + MEM_SIZE) && mem_rw == 2'b10) begin
                    // Main memory read
                    logic [31:0] offset;
                    offset = mem_addr - MEM_BASE;
                    
                    case (mem_size[1:0])
                        2'b00: begin  // Byte
                            if (offset < MEM_SIZE) begin
                                mem_rdata = {24'h0, memory[offset]};
                            end else begin
                                mem_rdata = 32'h0;
                            end
                        end
                        2'b01: begin  // Half-word
                            if (offset < MEM_SIZE - 1) begin
                                mem_rdata = {16'h0, memory[offset+1], memory[offset]};
                            end else begin
                                mem_rdata = 32'h0;
                            end
                        end
                        2'b10: begin  // Word
                            if (offset < MEM_SIZE - 3) begin
                                mem_rdata = {memory[offset+3], memory[offset+2], memory[offset+1], memory[offset]};
                            end else begin
                                mem_rdata = 32'h0;
                            end
                        end
                        default: mem_rdata = 32'h0;
                    endcase
                end else if (mem_rw == 2'b10) begin
                    // Invalid address read (RW_READ = 2'b10)
                    mem_rdata = 32'hDEADC0DE;
                end
            end
        end
    end
    
    // Sequential logic for delay counter, writes, and statistics
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            mem_delay_counter <= 0;
            mem_transaction_active <= 0;
            mem_transaction_delay <= 0;
            gpio_reg <= 32'h0;
            mem_read_count <= 0;
            mem_write_count <= 0;
        end else begin
            // Check if there's an active memory request
            if (mem_rw != 2'b00) begin
                // New transaction starting
                if (!mem_transaction_active) begin
                    mem_transaction_active <= 1;
                    mem_delay_counter <= 0;
                    
                    // Calculate random delay if needed
                    if (MEM_DELAY_CYCLES < 0) begin
                        mem_transaction_delay <= $urandom_range(0, MAX_RANDOM_DELAY);
                    end
                end else begin
                    // Ongoing transaction
                    int delay_cycles;
                    if (MEM_DELAY_CYCLES < 0) begin
                        delay_cycles = mem_transaction_delay;
                    end else begin
                        delay_cycles = MEM_DELAY_CYCLES;
                    end
                    
                    if (mem_delay_counter < delay_cycles) begin
                        // Still waiting
                        mem_delay_counter <= mem_delay_counter + 1;
                    end else begin
                        // Transaction completes this cycle
                        mem_transaction_active <= 0;
                        mem_delay_counter <= 0;
                        
                        // Handle write operations
                        if (mem_addr == GPIO_ADDR && mem_rw == 2'b01) begin
                            // GPIO register write (RW_WRITE = 2'b01)
                            gpio_reg <= mem_wdata;
                            $display("[%0t] GPIO write: 0x%08h", $time, mem_wdata);
                            mem_write_count <= mem_write_count + 1;
                        end else if (mem_addr >= MEM_BASE && mem_addr < (MEM_BASE + MEM_SIZE)) begin
                            logic [31:0] offset;
                            offset = mem_addr - MEM_BASE;
                            
                            if (mem_rw == 2'b01) begin  // Write (RW_WRITE = 2'b01)
                                case (mem_size[1:0])
                                    2'b00: begin  // Byte
                                        if (offset < MEM_SIZE) begin
                                            memory[offset] <= mem_wdata[7:0];
                                        end
                                    end
                                    2'b01: begin  // Half-word
                                        if (offset < MEM_SIZE - 1) begin
                                            memory[offset] <= mem_wdata[7:0];
                                            memory[offset+1] <= mem_wdata[15:8];
                                        end
                                    end
                                    2'b10: begin  // Word
                                        if (offset < MEM_SIZE - 3) begin
                                            memory[offset] <= mem_wdata[7:0];
                                            memory[offset+1] <= mem_wdata[15:8];
                                            memory[offset+2] <= mem_wdata[23:16];
                                            memory[offset+3] <= mem_wdata[31:24];
                                        end
                                    end
                                endcase
                                mem_write_count <= mem_write_count + 1;
                            end else if (mem_rw == 2'b10) begin  // Read (RW_READ = 2'b10)
                                mem_read_count <= mem_read_count + 1;
                            end
                        end else if (mem_rw != 2'b00) begin
                            $display("WARNING: Memory access to invalid address: 0x%08h (rw=%b)", mem_addr, mem_rw);
                        end
                    end
                end
            end else begin
                // No active request
                mem_transaction_active <= 0;
                mem_delay_counter <= 0;
            end
        end
    end
    
    // Cycle counter
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end
    
    // Main test sequence
    initial begin
        int fd;
        int bytes_read;
        int file_size;
        logic [7:0] byte_data;
        
        $display("==============================================");
        $display("FRISCV System Top Testbench");
        $display("==============================================");
        $display("Memory configuration:");
        $display("  Base address:   0x%08h", MEM_BASE);
        $display("  Size:           %0d MiB", MEM_SIZE / (1024*1024));
        $display("  GPIO address:   0x%08h", GPIO_ADDR);
        $display("  Result address: 0x%08h", RESULT_ADDR);
        $display("Delay configuration:");
        $display("  Memory delay:   %0d cycles", MEM_DELAY_CYCLES);
        $display("Features tested:");
        $display("  - Instruction Pipeline");
        $display("  - ZSBL ROM (boot loader)");
        $display("  - L1 Cache Subsystem");
        $display("  - Memory Arbitration");
        $display("==============================================");
        
        // Initialize signals
        rstn = 0;  // Keep in reset
        
        // Initialize memory to zero
        for (int i = 0; i < MEM_SIZE; i++) begin
            memory[i] = 8'h0;
        end
        
        // Load program binary
        $display("Loading program from: %s", PROG_FILE);
        fd = $fopen(PROG_FILE, "rb");
        if (fd == 0) begin
            $display("ERROR: Cannot open file: %s", PROG_FILE);
            $display("Continuing with empty memory...");
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
            $display("Loaded %0d bytes into memory", bytes_read);
            $display("First 16 bytes: %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                     memory[0], memory[1], memory[2], memory[3], memory[4], memory[5], memory[6], memory[7],
                     memory[8], memory[9], memory[10], memory[11], memory[12], memory[13], memory[14], memory[15]);
        end
        
        // Wait a few cycles
        repeat(2) @(posedge clk);
        
        // Release reset
        $display("Releasing reset at time %0t", $time);
        rstn = 1;
        
        // Run simulation
        $display("Starting execution...");
        $display("ZSBL will execute first, then jump to 0x%08h", MEM_BASE);
        
        // Wait for end signal or max cycles
        for (int i = 0; i < MAX_CYCLES; i++) begin
            @(posedge clk);
            if (end_signal) begin
                $display("End signal detected at cycle %0d", cycle_count);
                break;
            end
        end
        
        // Print results
        $display("==============================================");
        $display("Simulation completed after %0d cycles", cycle_count);
        $display("Statistics:");
        $display("  Memory reads:   %0d", mem_read_count);
        $display("  Memory writes:  %0d", mem_write_count);
        $display("  End signal:     %0d", end_signal);
        $display("==============================================");
        $display("Results:");
        $display("  GPIO (0x%08h):   0x%08h", GPIO_ADDR, gpio_reg);
        
        // Read result from memory
        begin
            automatic logic [31:0] result_offset = RESULT_ADDR - MEM_BASE;
            automatic logic [31:0] result_value = {memory[result_offset+3], memory[result_offset+2], 
                                          memory[result_offset+1], memory[result_offset]};
            $display("  Result (0x%08h): 0x%08h", RESULT_ADDR, result_value);
        end
        $display("==============================================");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * MAX_CYCLES * 2);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
