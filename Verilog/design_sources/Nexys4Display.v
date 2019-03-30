module Nexys4Display (
    input   rst_low_i,
    input   clock_5meg_i,
    input   spi_sclk_i, //idle high, posedge active, < clock_5meg_i
    input   spi_ss_i,   //idle high
    input   spi_mosi_i, //idle high
    output  spi_miso_o, //idle high
    output  [7:0]  segment_o, 
    output  [15:0] digit_o
    );
    
    localparam BYTE_WIDTH = 8;
    localparam NUM_REGISTERS = 9; //reg0 is enable, 1-8 are digits
    localparam ENABLE_REG = 0;
      
    reg  [BYTE_WIDTH-1:0] register_digit_r      [NUM_REGISTERS-1:0];
    reg  [BYTE_WIDTH-1:0] register_digit_next_r [NUM_REGISTERS-1:0];

    reg  [BYTE_WIDTH-1:0] spi_rx_shiftreg_r;
    wire [BYTE_WIDTH-1:0] spi_rx_shiftreg_next_c;
    reg  [BYTE_WIDTH-1:0] spi_rx_u_byte_r;
    reg  [BYTE_WIDTH-1:0] spi_rx_l_byte_r;
    
    reg  [4:0]            spi_rx_bit_count_r;
    reg  [4:0]            spi_rx_bit_count_next_r;
    reg                   spi_rx_transfer_complete_r;
    wire                  spi_rx_transfer_complete_next_c;
    
    reg  [3:0]            rx_address_r;
    wire [3:0]            rxi_command_c;
    reg  [BYTE_WIDTH-1:0] rx_value_r;
    wire                  enable_c;
    /*************************************************/
    /* SPI Receiver                                  */
    /*************************************************/
    
    //spi receiver implemented by shift register
    always @ (posedge spi_sclk_i or negedge rst_low_i)
    begin
        if (~rst_low_i) spi_rx_shiftreg_r <= 8'd0;
        else            spi_rx_shiftreg_r <= spi_rx_shiftreg_next_c;
    end
    
    assign spi_rx_shiftreg_next_c = {spi_rx_shiftreg_r[BYTE_WIDTH-1-1:0] , spi_mosi_i};
    
    //count the number of bits received
    always @ (posedge spi_sclk_i or negedge rst_low_i)
    begin
        if (~rst_low_i) spi_rx_bit_count_r <= 5'd0;
        else             spi_rx_bit_count_r <= spi_rx_bit_count_next_r;
    end
    
    always @ (spi_ss_i, spi_rx_transfer_complete_r, spi_rx_bit_count_r)
    begin
        if (spi_rx_transfer_complete_r) spi_rx_bit_count_next_r = 5'd0;
        else if (~spi_ss_i)             spi_rx_bit_count_next_r = spi_rx_bit_count_r + 1'b1;
        else                            spi_rx_bit_count_next_r = spi_rx_bit_count_r;
    end
    
    //is a transfer completed? if so set complete flag -> 16 bit transfers, 2^4 = 16 for bit select
    always @ (posedge clock_5meg_i or negedge rst_low_i)
    begin
        if (~rst_low_i) spi_rx_transfer_complete_r <= 1'd0;
        else            spi_rx_transfer_complete_r <= spi_rx_transfer_complete_next_c;   
    end

    assign spi_rx_transfer_complete_next_c = spi_rx_bit_count_r[4];
    
    //is a byte completed? if so read it out -> 16 bit transfers therefore @ 8 & 16 
    always @ (posedge clock_5meg_i or negedge rst_low_i)
    begin
        if (~rst_low_i)
        begin
            spi_rx_u_byte_r <= 8'd0;
            spi_rx_l_byte_r <= 8'd0;
        end
        else if (spi_rx_bit_count_r == 8)
        begin
            spi_rx_u_byte_r <= spi_rx_shiftreg_r;
            spi_rx_l_byte_r <= spi_rx_l_byte_r;
        end
        else if (spi_rx_bit_count_r == 16)
        begin
            spi_rx_u_byte_r <= spi_rx_u_byte_r;
            spi_rx_l_byte_r <= spi_rx_shiftreg_r;
        end
        else
        begin
            spi_rx_u_byte_r <= spi_rx_u_byte_r;
            spi_rx_l_byte_r <= spi_rx_l_byte_r;
        end        
    end

    
    /*************************************************/
    /* Message Decoding                              */
    /*************************************************/
       
    assign rxi_command_c = spi_rx_u_byte_r[7:4];
    always @ (rxi_command_c,spi_rx_u_byte_r,spi_rx_l_byte_r)
    begin
        case(rxi_command_c)
            4'b0001: //write to register
            begin
                rx_address_r = spi_rx_u_byte_r[3:0];
                rx_value_r   = spi_rx_l_byte_r;
            end
            default: 
            begin
                rx_address_r = 4'b1111;
                rx_value_r   = 8'b0;
            end
        endcase
    end
        
    /*************************************************/
    /* Register Writing                              */
    /*************************************************/
    
    genvar inc;
    generate
        for (inc = 0;inc <= NUM_REGISTERS-1;inc = inc+1)
        begin: REGISTERS
            always @ (posedge clock_5meg_i or negedge rst_low_i)
            begin
                if (~rst_low_i)
                begin
                    register_digit_r[inc] <= 8'd0;               
                end
                else
                begin
                    register_digit_r[inc] <= register_digit_next_r[inc];               
                end     
            end
            always @ (rx_address_r, rx_value_r, register_digit_r) //TODO only if transfer complete
            begin
                if (spi_rx_transfer_complete_r && rx_address_r == inc[3:0]) register_digit_next_r[inc] = rx_value_r;
                else                                                        register_digit_next_r[inc] = register_digit_r[inc];
            end            
        end
    endgenerate        
    
    DisplayInterface displayInterface ( //TODO
        .clock 		(clock_5meg_i), // 5 MHz clock signal
        .reset 		(~rst_low_i),   // reset signal, active high
        .value 		(error_hex_x),  // input value to be displayed
        .point 		(4'b1111),    	// radix markers to be displayed
        .digit 		(digit_o),      // digit outputs
        .segment 	(segment_o)  	// segment outputs
    );
    
endmodule