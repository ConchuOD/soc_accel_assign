`timescale 1ns / 1ps

module TB_SPImaster();
    reg HCLK;
    reg HRESETn;
    reg spi_enable;
    reg[31:0] spi_tx_data;
    
    wire load_data_en;
    wire write_shift_enable;
    wire read_shift_enable;
    wire spi_clk;
    wire spi_ready_out;
    
    SPIMaster dut(
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .enable_i(spi_enable),
        .spi_write_data_i(spi_tx_data),
        .spi_write_data_bytes_valid_i(3'd2),
        .spi_miso_i(1'b1),
        .spi_mosi_o(),
        .spi_clk_o(),
        .spi_ss_o(),
        .spi_read_data_o(),
        .spi_read_data_bytes_valid_o()        
    );
    
    // Generate 50 MHz clock
    initial begin
        HCLK = 1'b0;
        forever	// generate 50 MHz clock
        begin
          #10 HCLK = ~HCLK;
        end
    end
    
    initial begin
        HRESETn = 1'b1;
        
        #50 HRESETn = 1'b0;
        #200 HRESETn = 1'b1;
        spi_tx_data = 32'b0110_1001_0101_1010_0000_1111_1100_0011;
        spi_enable = 1'b1;
        
        #8000 spi_enable = 1'b0;
    end

endmodule