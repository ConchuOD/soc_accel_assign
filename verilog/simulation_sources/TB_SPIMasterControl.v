`timescale 1ns / 1ps

module TB_SPImaster_control();
    reg HCLK;
    reg HRESETn;
    reg spi_rw;
    reg spi_ready_in;
    reg[7:0] spi_data;
    
    wire load_data_en;
    wire shift_enable;
    wire spi_clk;
    wire spi_ready_out;
    
    SPIMasterControl dut (
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .rw_i(spi_rw),
        .ready_i(spi_ready_in),
        .spi_data_i(spi_data),
        .load_data_en_o(load_data_en),
        .shift_enable_o(shift_enable),
        .spi_clk_o(spi_clk),
        .ready_o(spi_ready_out)
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
        #50 HRESETn = 1'b1;
          
        #10 spi_data = 8'b0000_1111;
        spi_rw = 1'b0;
        spi_ready_in = 1'b1;
        
        #900 spi_ready_in = 1'b0;
    end

endmodule