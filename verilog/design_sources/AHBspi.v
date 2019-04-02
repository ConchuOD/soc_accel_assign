`timescale 1ns / 1ps

module AHBspi (
    input wire HCLK,
    //input wire SPICLK,
    input wire HRESETn,
    input wire HSEL,
    input wire HREADY,          // Indicates previous AHB transaction completing
    input wire [31:0] HADDR,
    input wire HWRITE,
    input wire [31:0] HWDATA,
    output wire [31:0] HRDATA,
    output wire HREADYOUT
)

    reg h_write_r;

    // Capture next command for pipelining
    always @ (posedge HCLK) begin
        h_write_r <= HWRITE;
    
        if ~HRESETn begin
            h_write_r <= 1'b0;
        end    
    end
    
    

endmodule