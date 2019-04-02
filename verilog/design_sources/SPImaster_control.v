module SPImaster_control(
    input wire clk_i,
    input wire rstn_i,
    input wire rw_i,
    input wire ready_i,
    inout wire[7:0] spi_data_io,
    output wire load_data_en_o,
    output wire write_shift_enable_o,
    output wire read_shift_enable_o,
    output wire spi_clk_o,
    output wire ready_o
    // Need a signal to indicate the transaction bit length
)

    localparam[2:0] IDLE=2'b00, WRITING=2'b01, READING=2'b10; 
    localparam SPI_WRITE=1'b0, SPI_READ=1'b1;
    localparam SPI_CLK_IDLE = 1'b1;

    reg ready_r, load_data_en_r;    
    
    assign ready_o = ready_r;
    
    assign shift_enable_o = tx_state_r;
    assign load_data_en_o = load_data_en_r;
    assign spi_clk_o = (tx_state_r == IDLE) ? SPI_CLK_IDLE : spi_clk_waiting_r;
    
    // Next state logic
    always @(posedge clk_i) begin  
        //load_data_en_r <= 1'b0;             // Shift register load will only ever be high for 1 cycle
    
        if(tx_state_r == IDLE && ready_i) begin  
            ready_r            <= 1'b0;            
            case(rw_i)
            (SPI_WRITE):
                tx_state_r          <= WRITING;
                //load_data_en_r <= 1'b1;     // Push data into shift register             
            (SPI_READ):
                tx_state_r          <= READING;
                read_shift_enable_r <= 1'b1;
            endcase
        else 
            // Need to know when we have pushed out/pulled in 8 bytes
            
            
            // Should go straight to reading/writing again if there is a pending transaction
            
            // Otherwise, should idle again
        end
        
        if(~rstn_i) begin
            tx_state_r     <= IDLE;
            ready_r        <= 1'b1;
            load_data_en_r <= 1'b1; // Clear the shift register            
        end
    end 

    always @(posedge clk_i) begin
        count_r <= next_count_r;
    end

    // Need to generate SPI clk @ ~2.5 MHz when reading for 7 cycles
    always @(count_r, rstn_i) begin
        next_count_r <= count_r + 5'd1;
        
        if(count_r == 5'd19) begin
            next_count_r <= 5'd0; 
            spi_clk_waiting_r <= ~spi_clk_waiting_r;
        end        
        
        if(~rstn_i) begin
            next_count_r <= 5'd0;
            spi_clk_waiting_r <= 1'b0;
        end
    end
    
    // Count negedges since last transition to 
    // As soon as we see a new transaction, set a bit, don't look at state anymore
    // (WRITING)
    always @(negedge ) begin
        
    end
    
    // Need to provide control signal to shift register; should the enable signal
    // be clocked on processor or spi clock?
    
    
    
endmodule