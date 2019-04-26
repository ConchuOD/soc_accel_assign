module SPIMasterControl(
    input              clk_i,
    input              rstn_i,
    input              enable_i,
    input       [31:0] write_data_i,
    input       [ 7:0] read_data_i,
    input       [ 2:0] write_data_bytes_valid_i,
    input              reset_fill_level_i,
    output wire        load_shift_reg_byte_o,
    output reg  [ 7:0] shift_reg_byte_o,
    output wire        load_shift_reg_bit_o,
    output reg         shift_reg_bit_o,
    output wire        load_clk_o,   
    output wire        spi_clk_o,
    output wire [31:0] read_data_o,
    output wire [ 2:0] read_data_bytes_valid_o,
    output wire        clear_shift_reg_o
    // Need parameter to indicate SPI clock idle value?
    // Need parameter to indicate SPI clock frequency?
);

    localparam IDLE = 1'b0, SHIFTING = 1'b1;
    localparam SPI_CLOCK_IDLE = 1'b1;

    reg[4:0] count_r;
    reg spi_clk_waiting_r;
    
    
    reg[31:0] read_data_r, write_data_r;
    
    reg ctrl_state_r;
    reg loading_r, shifting_r;
    reg[3:0] bit_count_r;
    reg[2:0] bytes_remaining_r;
    reg[2:0] read_fill_level_bytes_r, read_fill_level_bytes_out_r;
    reg new_byte_r; 
    reg reset_fill_level_r;
    wire[2:0] read_fill_index_c;
    wire reset_fill_level_spi_clk_x;
    reg clear_shift_reg_r;

    assign read_fill_index_c       = 3'd4 - read_fill_level_bytes_r;
    assign load_shift_reg_byte_o   = loading_r;
    assign load_shift_reg_bit_o    = shifting_r;
    assign load_clk_o              = spi_clk_waiting_r;
    assign spi_clk_o               = shifting_r ? spi_clk_waiting_r : SPI_CLOCK_IDLE;
    
    assign read_data_bytes_valid_o = read_fill_level_bytes_out_r;
    assign read_data_o             = read_data_r;
    assign clear_shift_reg_o       = 1'b0;
    
    // Need to generate SPI clk @ ~2.5 MHz when reading for 7 cycles,
    // currently much faster than that for ease of simulation
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
    
    always @(negedge spi_clk_waiting_r) begin 
        new_byte_r <= 1'b0;  // Only allow high for one clock cycle
        case (ctrl_state_r)
        IDLE : begin
            if(enable_i) begin
                ctrl_state_r                <= SHIFTING;
                write_data_r                <= write_data_i;
                loading_r                   <= 1'b1;
                read_fill_level_bytes_r     <= 3'd0;
                shift_reg_byte_o            <= write_data_i[8*(write_data_bytes_valid_i-3'd1) +: 8];
                bytes_remaining_r           <= write_data_bytes_valid_i;// - 3'd1;
                bit_count_r                 <= 4'd7;
            end
        end
        
        SHIFTING : begin
            // Quit straight away if enable_i has gone low
            if(~enable_i) begin 
                ctrl_state_r                <= IDLE;
                bit_count_r                 <= 4'd0;
                bytes_remaining_r           <= 3'd0;
                read_fill_level_bytes_r     <= 3'd0;
                new_byte_r                  <= 1'b0;
                loading_r                   <= 1'b0;
                shifting_r                  <= 1'b0;
            end
            else begin            
                loading_r   <= 1'b0;
                shifting_r  <= 1'b1;
                
                if(bytes_remaining_r > 3'd0) begin
                    // Continue transacting
                    shift_reg_bit_o <= write_data_r[8*(bytes_remaining_r-3'd1) + bit_count_r];                    
                    bit_count_r     <= bit_count_r - 4'd1;
                
                    if(bit_count_r == 4'd0) begin 
                        bit_count_r             <= 4'd7;                
                        bytes_remaining_r       <= bytes_remaining_r - 3'd1;
                        new_byte_r              <= 1'b1;                        
                        read_fill_level_bytes_r <= read_fill_level_bytes_r + 3'b1;
                    end
                end
                else begin
                    // We have sent the desired number of bytes for this SPI transaction,
                    // so terminate
                    ctrl_state_r                <= IDLE;
                    bit_count_r                 <= 4'd0;
                    bytes_remaining_r           <= 3'd0;
                    loading_r                   <= 1'b0;
                    shifting_r                  <= 1'b0;
                end     
            end
        end 
        endcase
            
        if(~rstn_i) begin
            ctrl_state_r                <= IDLE;            
            bit_count_r                 <= 4'd7;
            bytes_remaining_r           <= 3'd0;
            read_fill_level_bytes_r     <= 3'd0;
            reset_fill_level_r          <= 1'b0;
            new_byte_r                  <= 1'b0;
            loading_r                   <= 1'b0;
            shifting_r                  <= 1'b0;
        end
    end
    
    always @(negedge spi_clk_waiting_r) begin
        if(new_byte_r) begin
            read_data_r[8*read_fill_index_c +: 8] <= read_data_i;
            read_fill_level_bytes_out_r           <= read_fill_level_bytes_r;
        end 
        
        if(~rstn_i) begin
            read_data_r                 <= 32'b0;
            read_fill_level_bytes_out_r <= 3'd0;
        end
    end
endmodule