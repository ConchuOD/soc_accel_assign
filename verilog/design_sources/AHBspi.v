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

    wire spi_ready_x;
    reg h_write_r;
    
    reg[31:0] ctrl_status_r, spi_ss_r, write_only_r, read_only_r;
    
    
    // If HSEL = 1, HWRITE = 1, and HREADY = 1, then allow write into control/ status 
    // registers as the previous transaction is about to complete
    always @(posedge HCLK) begin
        if(HSEL && HREADY) begin
            // Capture HADDR, HWRITE
            HADDR_r  <= HADDR;
            HWRITE_r <= HWRITE;
        end    
    
        if(~HRESETn) begin
            HADDR_r  <= 32'b0;
            HWRITE_r <= 1'b0;
        end
    end

    // Capture next command for pipelining
    always @ (posedge HCLK) begin
        h_write_r <= HWRITE;
    
        if ~HRESETn begin
            h_write_r <= 1'b0;
        end    
    end
    
    // Control/status register
    //                      CONTROL
    // | CPOL | CPHA | SPI_TRANSACTION_SIZE? |  -  | -  | -  |
    // |  31  |  30  |      29,28,27,26      |  25 | 24 | 23 |
    //
    //                  STATUS
    // | WRITE_REG_STATUS | READ_REG_STATUS | 
    // |      22,21,20    |     19,18,17     | 16 | 15 |
    // 
    always @() begin
    
    
    end
    
    // Address phase
    
    
    SPIMaster spiMaster (
    .clk_i(HCLK),
    .rstn_i(HRESETn),
    .ready_i(),
    .spi_tx_data_i(),
    .spi_miso_i(),
    .spi_mosi_o(),
    .spi_clk_o(),
    .spi_ss_o(),
    .ready_o(spi_ready_x)
);

endmodule