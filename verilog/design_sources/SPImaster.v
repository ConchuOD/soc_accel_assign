module SPIMaster (
    input  wire       clk_i,
    input  wire       rstn_i,
    input  wire       rw_i,
    input  wire       ready_i,
    input  wire [7:0] spi_tx_data_i,
    output wire [7:0] spi_rx_data_o,
    input  wire       spi_miso_i,
    output wire       spi_mosi_o,
    output wire       spi_clk_o,
    output wire       spi_ss_o,
    output wire       ready_o
);

    wire load_clk_x, load_en_x;
    wire shift_enable_x; 
    
    SPIShiftReg #(
        .RWn(1)
    )
    spiReadShiftReg
    (
        .clk_i(load_clk_x),
        .rstn_i(rstn_i),
        .data_bit_i(spi_miso_i),
        .data_i(8'd0),
        .data_o(spi_rx_data_o);
        .load_data_en_i(load_en_x),
        .shift_en_i(shift_enable_x),
        .shift_out_o(spi_mosi_o)
    );
    
    SPIShiftReg #(
        .RWn(0)    
    )
    spiWriteShiftReg (
        .clk_i(load_clk_x),
        .rstn_i(rstn_i),
        .data_bit_i(1'b0),
        .data_i(spi_tx_data_i),
        .data_o(),
        .load_data_en_i(load_en_x),
        .shift_en_i(shift_enable_x),
        .shift_out_o(spi_mosi_o)
    );
    
    // Tells shift register whether reading or writing
    SPIMasterControl spiMasterControl(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .rw_i(rw_i),                       // Indicate type of transaction
        .ready_i(ready_i),                 // Request a transaction 
        .load_data_en_o(load_en_x),        // Tell write shift reg to capture 8 bits of data to be sent
        .shift_enable_o(shift_enable_x),
        .load_clk_o(load_clk_x),
        .spi_clk_o(spi_clk_o),              
        .ready_o(ready_o)                  // Indicate if SPI master is ready to accept a transaction
    );

endmodule