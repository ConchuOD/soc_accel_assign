`timescale 1ns / 1ps

module TB_SPImaster();
    reg HCLK;
    reg HRESETn;
    reg spi_rw;
    reg spi_ready_in;
    reg[7:0] spi_tx_data;
    
    wire load_data_en;
    wire write_shift_enable;
    wire read_shift_enable;
    wire spi_clk;
    wire spi_ready_out;
    
    SPIMaster dut(
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .rw_i(spi_rw),
        .ready_i(spi_ready_in),
        .spi_tx_data_i(spi_tx_data),
        .spi_miso_i(1'b1),
        .spi_mosi_o(),
        .spi_clk_o(),
        .spi_ss_o(),
        .ready_o()
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
        spi_tx_data = 8'b0110_1001;
        spi_rw = 1'b0;
        spi_ready_in = 1'b1;
        
        #900 spi_ready_in = 1'b0;
    end

endmodule