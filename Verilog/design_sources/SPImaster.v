module SPImaster (
    input wire clk_i,
    input wire rstn_i,
    input wire rw_i,
    input wire ready_i,
    inout wire[7:0] spi_data_io,
    input wire spi_miso_i,
    output wire spi_mosi_o,
    output wire spi_clk_o,
    output wire spi_ss_o,
    output wire ready_o
)

    wire spi_clk_x, load_en_x;
    wire[1:0] shift_enable_x;    

    SPIwrite_shift_reg spi_write_shift_reg(
        .spi_clk_i(spi_clk_x),
        .rstn_i(rstn_i),
        .data_i(spi_data_i),
        .load_data_en_i(load_en_x)
        .shift_out_o(spi_mosi_o)
    );
    
    SPIread_shift_reg spi_read_shift_reg(
        
    );
    
    
    
    // Tells shift register whether reading or writing
    SPImaster_control spi_master_control(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .rw_i(),                            // Indicate type of transaction
        .ready_i(enable_i),                 // Request a transaction 
        .spi_data_io(spi_data_io),          // Provide data for writing
        .load_data_en_o(load_en_x),         // Tell write shift reg to capture 8 bits of data to be sent
        .read_shift_enable_o(read_shift_enable_x),  
        .write_shift_enable_o(write_shift_enable_x),
        .spi_clk_o(spi_clk_x),              
        .ready_o(ready_o)                   // Indicate if SPI master is ready to accept a transaction
    );

endmodule