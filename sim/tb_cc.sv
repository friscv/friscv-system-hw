`timescale 1ns / 1ps

module tb_cc;

parameter CLK_PERIOD = 10;  // 10ns clock period (100MHz)
parameter MAX_CYCLES = 100000;  // Maximum simulation cycles
parameter PROG_FILE = "../../../../../test/prog.bin";  // Program binary file

parameter MEM_SIZE = 2 * 1024;          // 2 KiB
parameter MEM_BASE = 32'h80000000;      // Memory base address
parameter GPIO_ADDR = 32'h40000000;     // GPIO address
parameter UART_ADDR = 32'h40600000;     // UART address
parameter RESULT_ADDR = 32'h80000500;   // Result address (MEM_BASE + 1.25K)

parameter int MEM_DELAY_CYCLES = 0;

logic clk;
logic rstn;
logic end_signal;

logic [2:0]  mem_size;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;
logic [1:0]  mem_rw;
logic        mem_wait;

logic [7:0]  memory [MEM_SIZE];
logic [31:0] gpio_reg;

int mem_delay_counter;

int cycle_count;
int mem_read_count;
int mem_write_count;

friscv_core_complex dut (
    .i_clk       ( clk        ),
    .i_rstn      ( rstn       ),
    .o_end       ( end_signal ),
    .o_mem_size  ( mem_size   ),
    .o_mem_addr  ( mem_addr   ),
    .o_mem_wdata ( mem_wdata  ),
    .i_mem_rdata ( mem_rdata  ),
    .o_mem_rw    ( mem_rw     ),
    .i_mem_wait  ( mem_wait   )
);

initial begin
    clk = 1;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

always_comb begin
    mem_wait = 0;
    mem_rdata = 32'h0;
    
    if (mem_rw != 2'b00) begin
        // Assert wait if delay not satisfied
        if (mem_delay_counter < MEM_DELAY_CYCLES) begin
            mem_wait = 1;
        end else begin
            // Delay satisfied, provide data for reads
            if (mem_rw == 2'b10) begin  // RW_READ
                if (mem_addr >= GPIO_ADDR && mem_addr < (GPIO_ADDR + 32'h20)) begin
                    mem_rdata = 32'h0;  // Boot mode 0: DRAM direct jump
                end else if (mem_addr >= UART_ADDR && mem_addr < (UART_ADDR + 32'h20)) begin
                    // STATUS (offset 0x8): TX_EMPTY=1 so uart_putc/uart_puts don't spin
                    mem_rdata = (mem_addr == (UART_ADDR + 32'h8)) ? 32'h4 : 32'h0;
                end else if (mem_addr >= MEM_BASE && mem_addr < (MEM_BASE + MEM_SIZE)) begin
                    logic [31:0] aligned_offset;
                    aligned_offset = (mem_addr - MEM_BASE) & 32'hFFFFFFFC;
                    mem_rdata = {memory[aligned_offset+3], memory[aligned_offset+2], memory[aligned_offset+1], memory[aligned_offset]};
                end else begin
                    mem_rdata = 32'hDEADC0DE;
                end
            end
        end
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        mem_delay_counter <= 0;
        gpio_reg <= 32'h0;
        mem_read_count <= 0;
        mem_write_count <= 0;
    end else begin
        if (mem_rw != 2'b00) begin
            if (mem_delay_counter < MEM_DELAY_CYCLES) begin
                mem_delay_counter <= mem_delay_counter + 1;
            end else begin
                mem_delay_counter <= 0;
                if (mem_rw == 2'b01) begin
                    if (mem_addr == GPIO_ADDR) begin
                        gpio_reg <= mem_wdata;
                        $display("[%0t] GPIO write: 0x%08h", $time, mem_wdata);
                    end else if (mem_addr == (UART_ADDR + 32'h4)) begin
                        $write("%c", mem_wdata[7:0]);
                    end else if (mem_addr >= MEM_BASE && mem_addr < (MEM_BASE + MEM_SIZE)) begin
                        logic [31:0] offset;
                        offset = mem_addr - MEM_BASE;
                        case (mem_size[1:0])
                            2'b00: memory[offset] <= mem_wdata[7:0];
                            2'b01: begin
                                memory[offset] <= mem_wdata[7:0];
                                memory[offset+1] <= mem_wdata[15:8];
                            end
                            2'b10: begin
                                memory[offset] <= mem_wdata[7:0];
                                memory[offset+1] <= mem_wdata[15:8];
                                memory[offset+2] <= mem_wdata[23:16];
                                memory[offset+3] <= mem_wdata[31:24];
                            end
                        endcase
                    end
                    mem_write_count <= mem_write_count + 1;
                end else begin
                    mem_read_count <= mem_read_count + 1;
                end
            end
        end else begin
            mem_delay_counter <= 0;
        end
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn)
        cycle_count <= 0;
    else
        cycle_count <= cycle_count + 1;
end

initial begin
    int fd;
    int bytes_read;
    
    $display("==============================================");
    $display("FRISCV System Testbench");
    $display("==============================================");
    $display("Memory: 0x%08h, %0d MiB", MEM_BASE, MEM_SIZE / (1024*1024));
    $display("GPIO:   0x%08h", GPIO_ADDR);
    $display("Delay:  %0d cycles", MEM_DELAY_CYCLES);
    $display("==============================================");
    
    rstn = 0;
    
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
    
    repeat(2) @(posedge clk);
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
        automatic logic [31:0] offset = RESULT_ADDR - MEM_BASE;
        automatic logic [31:0] result = {memory[offset+3], memory[offset+2], memory[offset+1], memory[offset]};
        $display("Result (0x%08h): 0x%08h", RESULT_ADDR, result);
    end
    $display("==============================================");
    
    $finish;
end

initial begin
    #(CLK_PERIOD * MAX_CYCLES * 2);
    $display("ERROR: Timeout!");
    $finish;
end

endmodule
