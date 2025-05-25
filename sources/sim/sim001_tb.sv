`timescale 1ns / 1ps

module sim001_tb;


//parameter PERIOD = 10;

    logic clk_extern_in;
    logic rst_n_extern_in;
    logic rst_pushbutton_in;

// Arm debug memory interface
    logic clk_debug_extern_in;
    logic debug_mode_in;
    logic [ADDR_WIDTH-1:0] debug_mem_addr_in;
    logic [DATA_WIDTH-1:0] debug_mem_data_in;
    logic [DATA_WIDTH-1:0] debug_mem_data_out;
    logic debug_mem_wr_in;
    logic [1:0] debug_signals_out;

    //GPIO interface
    logic [7:0] gpio1_data_out;
    logic [7:0] gpio2_data_out;    
    
    logic      end_signal_out;

friscv_system_top uut(
    .clk_extern_in(clk_extern_in),
    .rst_n_extern_in(rst_n_extern_in),
    .rst_pushbutton_in(rst_pushbutton_in),

// Arm debug memory interface
    .clk_debug_extern_in(clk_debug_extern_in),
    .debug_mode_in(debug_mode_in),
    .debug_mem_addr_in(debug_mem_addr_in),
    .debug_mem_data_in(debug_mem_data_in),
    .debug_mem_data_out(debug_mem_data_out),
    .debug_mem_wr_in(debug_mem_wr_in),
    .debug_signals_out(debug_signals_out),

    //GPIO interface
    .gpio1_data_out(gpio1_data_out),
    .gpio2_data_out(gpio2_data_out),    
    
    .end_signal_out(end_signal_out)
    
);


//promjeniti velicinu polja ovisno o velicini programa
logic [31:0] debug_memory [200];
//logic [31:0] debug_memory_after_program [] = {};

int fd;
int number_read;
int counterReadLine = 0;
int firstByte = 0;
int secondByte = 0;
int thirdByte = 0;
int fourthByte = 0;

integer counter;

initial begin
    $display("Pocetak");
       
    //pocetak debuga/punjenje memorije
    rst_n_extern_in <= 0;  // reset CPU active
    rst_pushbutton_in <= 0;
    debug_mode_in <= 1;
    clk_extern_in <= 0;
    
    
    //Citanje podataka iz .b datoteke
    fd = $fopen("..\\..\\..\\..\\..\\..\\RISC-V\\binaries\\tb1.b", "rb");
    if (fd != 0) begin
        while (!$feof(fd)) begin
              firstByte = $fgetc(fd);
              secondByte = $fgetc(fd);
              thirdByte = $fgetc(fd);
              fourthByte = $fgetc(fd);  
//              number_read = (firstByte << 24) + (secondByte << 16) + (thirdByte << 8) + fourthByte;
              number_read = (fourthByte << 24) + (thirdByte << 16) + (secondByte << 8) + firstByte;
              debug_memory[counterReadLine] = number_read;
              $display("%h",number_read);
              counterReadLine = counterReadLine + 1; 
        end
    end
    else $fatal("Ne mogu ucitati .b file!");
      
    //?ekanje da se procesor zaustavi
    for (counter = 3; counter >= 0; counter=counter-1) begin
       clk_extern_in <= 0;
       #5;
       clk_extern_in <= 1;
       #5;
    end
    assert (debug_signals_out[0])
    else $fatal("Procesor nije zaustavljen!");
    
    debug_mem_wr_in <= 1;
    debug_mem_addr_in <= 32'h00;
    clk_extern_in <= 0;
    #5
    clk_extern_in <= 1;
    #5
    clk_extern_in <= 0;
    #5
    
    //u memoriju zapisujemo elemente polja 
    foreach (debug_memory[i]) begin
        clk_debug_extern_in <= 0;
        debug_mem_data_in <= debug_memory[i];
        #5;
        clk_debug_extern_in <= 1;
        #5;
        debug_mem_addr_in <= debug_mem_addr_in + 4;
    end
    
    //kraj debuga/punjanja memorije
    debug_mode_in <= 0;
    debug_mem_wr_in <= 0;
    
    //resetiranje procesora
    for (counter = 20; counter >= 0; counter=counter-1) begin
       clk_extern_in <= 0;
       #5;
       clk_extern_in <= 1;
       #5;
    end
    rst_n_extern_in <= 1;
    
    //procesor izvr?ava naredbe
    for (counter = 0; counter <= 200; counter=counter+1) begin
       clk_extern_in <= 0;
       #5;
       clk_extern_in <= 1;
       #5;
    end

    $display("Gotovo");
    $finish;
    
end

endmodule