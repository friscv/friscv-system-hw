//////////////////////////////////////////////////////////////////////////////////
// Company: FER
// Engineer: Petra Kelkovic
// 
// Create Date: 01.06.2024 22:44:12
// Design Name: 
// Module Name: friscv_gpio
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module friscv_gpio#(
    parameter   GPIO_ADDRESS = 32'H10000
)
(
    input  logic          clk,    
    input  logic          d_mem_wr_in,
    input  logic [31:0]   d_mem_addr_in,
    input  logic [31:0]   d_mem_data_in,
    
    output logic [7:0]    data_reg_out
    );
logic [7:0] data_reg_buff;
logic [7:0] OLED_buffer;
always_ff @(posedge clk) begin
    if (d_mem_addr_in == GPIO_ADDRESS) begin                 
        if (d_mem_wr_in) begin
            data_reg_buff <= d_mem_data_in;
        end
    end
    else if(d_mem_addr_in == 32'H10008) begin
        if(d_mem_wr_in) begin
            if(d_mem_data_in == 32'HAAAAAAAA) begin
                OLED_buffer <= 8'b00000000;
            end
            else if(d_mem_data_in == 32'HBBBBBBBB) begin
                OLED_buffer <= 8'b00000001;
            end
            else begin
                OLED_buffer <= 8'b00100100 | ((d_mem_data_in & 32'b10)) | ((d_mem_data_in & 32'b1));
            end
        end
    end
    else if(d_mem_addr_in == 32'H10004) begin
        if(d_mem_wr_in) begin
            OLED_buffer <= 8'b00110100 | ((d_mem_data_in & 32'b10)) | ((d_mem_data_in & 32'b1));
        end
    end
end
always_comb begin
    if (d_mem_addr_in == GPIO_ADDRESS) begin
        data_reg_out = data_reg_buff;
    end 
    else begin
        data_reg_out = OLED_buffer;
    end
end
endmodule


