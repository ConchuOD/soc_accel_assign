`timescale 1ns / 1ps    
/*************************************************************************/
/* Author: Andrew Mannion 23/04/2019                                     */
/* Digital & Embedded Systems Assignment 3                               */
/*************************************************************************/

module SPIMasterControl(
    input              clk_i,
    input              rstn_i,
    input              enable_i,
    input       [31:0] write_data_i,
    input       [ 7:0] read_data_i,
    input       [ 2:0] write_data_bytes_valid_i,
    output wire        load_shift_reg_byte_o,
    output reg  [ 7:0] shift_reg_byte_o,
    output wire        load_shift_reg_bit_o,
    output reg         shift_reg_bit_o,
    output wire        load_clk_o,   
    output wire        spi_clk_o,
    output wire [31:0] read_data_o,
    output wire [ 2:0] read_data_bytes_valid_o,
    output wire        ready_o
    // FUTURE:
    // Need parameter to indicate SPI clock idle value
    // Need parameter to indicate SPI clock frequency
    // Need parameter to indicate SPI clock polarity
    // Need parameter to indicate SPI clock phase for writes/reads
);

    localparam IDLE = 1'b0, SHIFTING = 1'b1;
    localparam SPI_CLOCK_IDLE = 1'b0;

    // SPI clock generation
    reg[4:0] count_r;
    reg spi_clk_waiting_r;    
    
    reg[31:0] read_data_r, write_data_r;
    
    reg ctrl_state_r;
    reg loading_r, shifting_r;
    reg[2:0] bit_count_r;
    reg[2:0] bytes_to_write_r, byte_index_r;
    reg[2:0] read_fill_level_bytes_r, read_fill_level_bytes_out_r;
    reg new_byte_r; 
    wire[2:0] read_fill_index_c;
    
    assign load_shift_reg_byte_o   = loading_r;
    assign load_shift_reg_bit_o    = shifting_r;
    assign load_clk_o              = spi_clk_waiting_r;
    assign spi_clk_o               = shifting_r ? spi_clk_waiting_r : SPI_CLOCK_IDLE;
    
    assign read_data_bytes_valid_o = read_fill_level_bytes_out_r;
    assign read_data_o             = read_data_r;
    assign clear_shift_reg_o       = 1'b0;
    
    // Process to generate an oscillating signal at the desired frequency
    // which forms an input to the logic for generating the SPI clock output
    // Divides clk_i by some integer value
    always @(posedge clk_i) begin
        if(count_r == 5'd10) begin 
            count_r           <= 5'd0; 
            spi_clk_waiting_r <= ~spi_clk_waiting_r;
        end  
        else begin
            count_r           <= count_r + 5'd1;
        end
        
        if(~rstn_i) begin
            count_r           <= 5'd0;
            spi_clk_waiting_r <= 1'b0;
        end
    end
    
    // Signal that indicates whether a new transaction can be accepted
    assign ready_o = (ctrl_state_r == IDLE & read_fill_level_bytes_r == 3'd0);
    
    // Process which contains FSM to handle inputs to, and outputs from, the write and read shift
    // registers
    always @(negedge spi_clk_waiting_r) begin 
        new_byte_r <= 1'b0;  // Only allow high for one clock cycle
        
        case (ctrl_state_r)
        IDLE : begin
            read_fill_level_bytes_r <= 3'd0; // Keep valid for one cycle after being in shifting mode
            
            if(enable_i) begin
                ctrl_state_r                <= SHIFTING;
                write_data_r                <= write_data_i; // Capture the data to be written
                loading_r                   <= 1'b1;         // Indicate an entire byte is to be loaded into the write s.r.
                shift_reg_byte_o            <= write_data_i[8*(write_data_bytes_valid_i-3'd1) +: 8];
                bytes_to_write_r            <= write_data_bytes_valid_i; // Capture amount of bytes to be transmitted
                // Set up the next byte to be txd - if only have one byte to tx, feed the first byte into the shift reg
                // just as dummy values (the dummy values will not be transmitted)
                byte_index_r                <= (write_data_bytes_valid_i > 3'd1)? write_data_bytes_valid_i - 3'd2 : 3'd0;
            end
        end
        
        SHIFTING : begin
            // Only ever load a byte for one cycle
            loading_r <= 1'b0;
            // Quit straight away if enable_i has gone low
            if(~enable_i) begin 
                ctrl_state_r             <= IDLE;
                bit_count_r              <= 3'd7;
                bytes_to_write_r         <= 3'd0;
                byte_index_r             <= 3'd0;
                read_fill_level_bytes_r  <= 3'd0;
                new_byte_r               <= 1'b0;
                shift_reg_byte_o         <= 8'd0;
                shifting_r               <= 1'b0;
            end
            else begin
                // Feed new bits into the write shift register, pull bits in from read shift register
                shifting_r  <= 1'b1;
                
                if(bytes_to_write_r > 3'd0) begin
                    // Continue transacting
                    // Index from MSB-down to LSB
                    shift_reg_bit_o <= write_data_r[8*(byte_index_r) + bit_count_r];                    
                    bit_count_r     <= bit_count_r - 4'd1;
                
                    // Complete byte has just been txd
                    if(bit_count_r == 3'd0) begin  
                        // Setup for next byte
                        bit_count_r             <= 3'd7; 
                        // Ensure next byte index is valid
                        byte_index_r            <= (byte_index_r > 3'd0)? byte_index_r - 3'd1 : 3'd0;
                        bytes_to_write_r        <= bytes_to_write_r - 3'd1;
                        // Indicate that there will be an entire new byte to take from the
                        // read shift register
                        new_byte_r              <= 1'b1;                        
                        read_fill_level_bytes_r <= read_fill_level_bytes_r + 3'b1;
                    end
                end
                else begin
                    // We have sent the desired number of bytes for this SPI transaction,
                    // so terminate
                    ctrl_state_r                <= IDLE;
                    bit_count_r                 <= 3'd7; // Set up for next transaction
                    bytes_to_write_r            <= 3'd0;
                    byte_index_r                <= 3'd0;
                    shift_reg_byte_o            <= 8'd0;
                    shifting_r                  <= 1'b0;
                end     
            end
        end 
        endcase
            
        if(~rstn_i) begin
            ctrl_state_r                <= IDLE;            
            bit_count_r                 <= 3'd7;
            bytes_to_write_r            <= 3'd0;
            byte_index_r                <= 3'd0;
            read_fill_level_bytes_r     <= 3'd0;
            new_byte_r                  <= 1'b0;
            loading_r                   <= 1'b0;
            shift_reg_byte_o            <= 8'd0;
            shifting_r                  <= 1'b0;
        end
    end
    
    assign read_fill_index_c = 3'd4 - read_fill_level_bytes_r;
    
    // Process to handle correct storage of data from the read shift register
    always @(negedge spi_clk_waiting_r) begin
        if(new_byte_r) begin
            // Assign MS byte down to LS byte, so use "inverse" of fill level
            read_data_r[8*read_fill_index_c +: 8] <= read_data_i;
            // Output value lags internal signal by 1 clock cycle as entire new read
            // byte is only valid on the subsequent negedge, so pick up on next posedge here 
            read_fill_level_bytes_out_r           <= read_fill_level_bytes_r;
        end 
        else if(ctrl_state_r == IDLE) begin
            read_fill_level_bytes_out_r <= 3'd0;
        end
        
        if(~rstn_i) begin
            read_data_r                 <= 32'b0;
            read_fill_level_bytes_out_r <= 3'd0;
        end
    end
endmodule