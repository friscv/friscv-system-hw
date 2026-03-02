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

module friscv_timer (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_in CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET rstn_in" *)
    input  wire        clk_in,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn_in RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        rstn_in,
    
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

    output wire        timer_irq
);

reg [63:0] counter = 0;
reg [63:0] target = 64'hFFFFFFFFFFFFFFFF;

reg [31:0] waddr = 32'b0;
reg [31:0] wdata = 32'b0;
reg awcomplete = 0;
reg wcomplete = 0;

always @(posedge clk_in) begin
    if(!rstn_in) begin
        counter <= 64'b0;
        target <= 64'hFFFFFFFFFFFFFFFF;
        waddr <= 32'b0;
        wdata <= 32'b0;
        s_axi_awready <= 1'b0;
        s_axi_wready <= 1'b0;
        s_axi_bvalid <= 1'b0;
        awcomplete <= 1'b0;
        wcomplete <= 1'b0;     
    end
    else begin
        counter <= counter + 1;
        if( !awcomplete && !s_axi_awready && s_axi_awvalid) begin
            s_axi_awready <= 1'b1;
        end        
        else if(s_axi_awvalid && s_axi_awready) begin
            waddr <= s_axi_awaddr;
            s_axi_awready <= 1'b0;
            awcomplete <= 1'b1;
        end    
        if( !wcomplete && !s_axi_wready && s_axi_wvalid) begin
            s_axi_wready <= 1'b1;
        end 
        else if(s_axi_wvalid && s_axi_wready) begin
            wdata <= s_axi_wdata;
            s_axi_wready <= 1'b0;
            wcomplete <= 1'b1;
        end 
        if(wcomplete && awcomplete && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            case(waddr[3:2])
                2'b00: target[31:0] <= wdata;
                2'b01: target[63:32] <= wdata;
                2'b10: counter[31:0] <= wdata;
                2'b11: counter[63:32] <= wdata; 
            endcase
        end
        else if(s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
            wcomplete <= 1'b0;
            awcomplete <= 1'b0; 
        end
    end
end


always @(posedge clk_in) begin
    if(!rstn_in) begin
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rdata   <= 32'b0;
    end
    else begin
        if(!s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
        end
        else if(s_axi_arvalid && s_axi_arready) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b1;
            case(s_axi_araddr[3:2])
                2'b00: s_axi_rdata <= target[31:0];
                2'b01: s_axi_rdata <= target[63:32];
                2'b10: s_axi_rdata <= counter[31:0];
                2'b11: s_axi_rdata <= counter[63:32];
            endcase
        end 
        else if(s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end



assign s_axi_bresp = 2'b00;
assign s_axi_rresp = 2'b00; 
assign timer_irq   = (counter >= target);
    
endmodule 
