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
    output reg         clear_shift_reg_o
    // Need a signal to indicate the transaction bit length?
    // Need parameter to indicate SPI clock idle value
);

    localparam IDLE = 1'b0, SHIFTING = 1'b1;
    localparam SPI_CLOCK_IDLE = 1'b1;

    reg[4:0] count_r, next_count_r;
    reg[31:0] read_data_r, write_data_r;
    reg spi_clk_waiting_r;
    reg ctrl_state_r;
    reg loading_r, shifting_r;
    reg[3:0] bit_count_r;
    reg[2:0] byte_count_r;
    reg[2:0] read_fill_level_bytes_r, read_fill_level_bytes_out_r;
    reg new_byte_r;    

    assign load_shift_reg_byte_o   = loading_r;
    assign load_shift_reg_bit_o    = shifting_r;
    assign load_clk_o              = spi_clk_waiting_r;
    assign spi_clk_o               = shifting_r ? spi_clk_waiting_r : SPI_CLOCK_IDLE;
    assign read_data_bytes_valid_o = read_fill_level_bytes_out_r;
    assign read_data_o             = read_data_r;
    
    always @(posedge clk_i) begin
        count_r <= next_count_r;
    end
    
    // Need to generate SPI clk @ ~2.5 MHz when reading for 7 cycles,
    // currently much faster than that for ease of simulation
    always @(count_r, rstn_i) begin
        next_count_r          <= count_r + 5'd1;
        
        if(count_r == 5'd4) begin 
            next_count_r      <= 5'd0; 
            spi_clk_waiting_r <= ~spi_clk_waiting_r;
        end        
        
        if(~rstn_i) begin
            next_count_r      <= 5'd0;
            spi_clk_waiting_r <= 1'b0;
        end
    end
    
    always @(negedge spi_clk_waiting_r) begin 
        clear_shift_reg_o   <= 1'b0;    // Only ever hold the clear signal high for 1 clock cycle
        case (ctrl_state_r)
        IDLE : begin
            if(enable_i) begin
                ctrl_state_r          <= SHIFTING;
                // Load in word                
                write_data_r          <= write_data_i;
                loading_r             <= 1'b1;
                shift_reg_byte_o      <= write_data_i[7:0];
                byte_count_r          <= 3'd1;
            end
        end
        
        SHIFTING : begin
            loading_r   <= 1'b0;
            shifting_r  <= 1'b1;  

            if(byte_count_r < write_data_bytes_valid_i) begin
                shift_reg_bit_o <= write_data_r[8*(byte_count_r) + bit_count_r];
            end
            else begin
                shift_reg_bit_o <= 1'b1;
            end
            
            bit_count_r <= bit_count_r + 4'd1;
            
            // Quit straight away if we would over
            if(~enable_i && read_fill_level_bytes_r == 3'd4) begin
                ctrl_state_r                <= IDLE;
                read_data_r                 <= 32'b0;
                bit_count_r                 <= 4'd0;
                byte_count_r                <= 3'd0;
                read_fill_level_bytes_r     <= 3'd0;
                read_fill_level_bytes_out_r <= 3'd0;
                clear_shift_reg_o           <= 1'b1;
                new_byte_r                  <= 1'b0;
                loading_r                   <= 1'b0;
                shifting_r                  <= 1'b0;
            end
            
            if(bit_count_r == 4'd7) begin 
                bit_count_r             <= 4'd0;
                read_fill_level_bytes_r <= (read_fill_level_bytes_r % 3'd4) + 3'd1;
                byte_count_r            <= (byte_count_r < write_data_bytes_valid_i) ? byte_count_r + 3'd1 : byte_count_r;
                new_byte_r              <= 1'b1;
                
                // Only terminate on a byte boundary
                if(~enable_i) begin
                    ctrl_state_r                <= IDLE;
                    read_data_r                 <= 32'b0;
                    bit_count_r                 <= 4'd0;
                    byte_count_r                <= 3'd0;
                    read_fill_level_bytes_r     <= 3'd0;
                    read_fill_level_bytes_out_r <= 3'd0;
                    clear_shift_reg_o           <= 1'b1;
                    new_byte_r                  <= 1'b0;
                    loading_r                   <= 1'b0;
                    shifting_r                  <= 1'b0;
                end
            end
            
            // Capture the read bytes from the read shift register
            // on the negedge clock AFTER the 8th bit has been written
            if(new_byte_r) begin
                read_data_r[8*(read_fill_level_bytes_r - 3'd1) +: 8] <= read_data_i;
                read_fill_level_bytes_out_r <= read_fill_level_bytes_r;
                new_byte_r <= 1'b0;
            end
        end 
        endcase
            
        if(~rstn_i) begin
            ctrl_state_r                <= IDLE;
            read_data_r                 <= 32'b0;
            bit_count_r                 <= 4'd0;
            byte_count_r                <= 3'd0;
            read_fill_level_bytes_r     <= 3'd0;
            read_fill_level_bytes_out_r <= 3'd0;
            clear_shift_reg_o           <= 1'b0;
            new_byte_r                  <= 1'b0;
            loading_r                   <= 1'b0;
            shifting_r                  <= 1'b0;
        end
    end

endmodule