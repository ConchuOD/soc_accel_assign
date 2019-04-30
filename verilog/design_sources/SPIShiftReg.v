`timescale 1ns / 1ps    
/*************************************************************************/
/* Author: Andrew Mannion 14/04/2019                                     */
/* Digital & Embedded Systems Assignment 3                               */
/*************************************************************************/

module SPIShiftReg 
#(
    parameter RWn = 0
    // Other parameters based on writing/reading on posedge/negedge clk_i,
    // are required
    // This version only accounts for SPI slaves that 
    // - read on posedge SPI_clk
    // - write on negedge SPI_clk
    // - have an idle high SPI_clk
)
(   
    input             clk_i,
    input             rstn_i,
    input             data_bit_i,
    input       [7:0] data_byte_i,
    output wire [7:0] data_byte_o,
    input             load_byte_en_i,
    input             load_bit_en_i,
    output wire       shift_out_o
); 

reg[7:0] shift_reg_r;

assign shift_out_o = shift_reg_r[7]; 
assign data_byte_o = shift_reg_r;       

// Use a generate block as the portlist for read and write shift registers 
// is very similar. Defaults to instantiation of a write shift register
generate
    // Read shift register
    if(RWn == 1) begin : genReadShiftReg
        // Currently only support reading on posedge: this could
        // be extended relatively easily to switching between
        // posedge and negedge writes
        always @(posedge clk_i, negedge rstn_i) begin 
            if(load_bit_en_i) begin
                shift_reg_r <= {shift_reg_r[6:0], data_bit_i};
            end
            
            if(~rstn_i) begin
                shift_reg_r <= 8'd0;
            end            
        end
    end 
    // Write shift register
    else if(RWn == 0) begin : genWriteShiftReg
        // Currently only support writing on negedge: this could
        // be extended relatively easily to switching between
        // posedge and negedge writes
        always @(negedge clk_i, negedge rstn_i) begin
            if(load_byte_en_i) begin
                shift_reg_r <= data_byte_i; 
            end   
            else if(load_bit_en_i) begin   
                shift_reg_r <= {shift_reg_r[6:0], data_bit_i}; 
            end
            
            if(~rstn_i) begin
                shift_reg_r <= 8'd0;
            end
        end
    end
endgenerate

endmodule