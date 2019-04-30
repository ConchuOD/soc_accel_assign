`timescale 1ns / 1ps    
/*************************************************************************/
/* Author:      Andrew Mannion 23/04/2019                                */
/* Module:      Digital & Embedded Systems Assignment 3                  */
/* Description: Module which instantiates SPI modules su that SPI        */
/*              functionality can be encapsulated in one module for      */
/*              clarity.                                                  */
/*************************************************************************/

module SPIMaster (
    input              clk_i,
    input              rstn_i,
    input              enable_i,
    input       [31:0] spi_write_data_i,
    input       [ 2:0] spi_write_data_bytes_valid_i,
    input              spi_miso_i,
    output wire        spi_mosi_o,
    output wire        spi_clk_o,
    output wire [31:0] spi_read_data_o,
    output wire [ 2:0] spi_read_data_bytes_valid_o,
    output wire        ready_o
);

    wire[7:0] spi_rx_data_x, shift_reg_byte_x;
    wire load_shift_reg_byte_x, load_shift_reg_bit_x, shift_reg_bit_x;    
    
    SPIShiftReg #(
        .RWn(1)
    )
    spiReadShiftReg
    (
        .clk_i(load_clk_x),
        .rstn_i(rstn_i), 
        .data_bit_i(spi_miso_i),
        .data_byte_i(8'd0),         // Will never want to load an entire byte into the read shift reg
        .data_byte_o(spi_rx_data_x),
        .load_byte_en_i(1'b0),      // Will never want to load an entire byte into the read shift reg
        .load_bit_en_i(load_shift_reg_bit_x),
        .shift_out_o()
    );
    
    SPIShiftReg #(
        .RWn(0)    
    )
    spiWriteShiftReg (
        .clk_i(load_clk_x),
        .rstn_i(rstn_i),
        .data_bit_i(shift_reg_bit_x),
        .data_byte_i(shift_reg_byte_x),
        .data_byte_o(),
        .load_byte_en_i(load_shift_reg_byte_x),
        .load_bit_en_i(load_shift_reg_bit_x),
        .shift_out_o(spi_mosi_o)
    );
    
    SPIMasterControl spiMasterControl(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .enable_i(enable_i),               
        .write_data_i(spi_write_data_i),
        .read_data_i(spi_rx_data_x),
        .write_data_bytes_valid_i(spi_write_data_bytes_valid_i), 
        .load_shift_reg_byte_o(load_shift_reg_byte_x),
        .shift_reg_byte_o(shift_reg_byte_x),
        .load_shift_reg_bit_o(load_shift_reg_bit_x),
        .shift_reg_bit_o(shift_reg_bit_x),
        .load_clk_o(load_clk_x),
        .spi_clk_o(spi_clk_o),              
        .read_data_o(spi_read_data_o),
        .read_data_bytes_valid_o(spi_read_data_bytes_valid_o),
        .ready_o(ready_o)
    );

endmodule