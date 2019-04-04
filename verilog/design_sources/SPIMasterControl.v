module SPIMasterControl(
    input wire clk_i,
    input wire rstn_i,
    input wire ready_i,
    output wire load_data_en_o,
    output wire shift_enable_o,
    output wire load_clk_o,   
    output wire spi_clk_o,
    output wire ready_o
    // Need a signal to indicate the transaction bit length
    // Need parameter to indicate SPI clock idle value
);
    localparam SPI_CLK_IDLE = 1'b1;

    // Processor clock registers
    reg transaction_underway_r;  
    
    // SPI clock registers
    reg spi_clk_waiting_r, loading_r, shifting_r, transaction_completed_r;
    reg[4:0] count_r, next_count_r;
    reg[3:0] bit_count_r;
    
    assign ready_o = ~transaction_underway_r;
    
    assign shift_enable_o = shifting_r;
    assign load_data_en_o = loading_r;
    
    // Need to make sure that there are no extra negedges of spi_clk
    assign spi_clk_o = shifting_r ? spi_clk_waiting_r : SPI_CLK_IDLE;
    assign load_clk_o = spi_clk_waiting_r;
    
    always @(posedge clk_i) begin  
        if(tx_state_r == IDLE && ready_i) begin
            transaction_underway_r <= 1'b1;            
        end
        else if(transaction_completed_r) begin
            transaction_underway_r  <= 1'b0;
            transaction_completed_r <= 1'b0;            
        end
        
        if(~rstn_i) begin
            transaction_underway_r <= 1'b0;
        end
    end
    
    /// SPI clock generation ///

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
        if(transaction_underway_r && ~shifting_r) begin
            loading_r <= 1'b1; // Load in entire SPI word
        end
        
        if(loading_r) begin
            loading_r            <= 1'b0;
            shifting_r           <= 1'b1;
        end
        
        if(shifting_r) begin
            bit_count_r          <= bit_count_r + 4'd1;            
        end

        // This decimal 8 will change based on the transaction size
        if(bit_count_r == 4'd7) begin 
            bit_count_r             <= 4'd0; 
            shifting_r              <= 1'b0;            
            transaction_completed_r <= 1'b1;
        end
        
        if(~rstn_i) begin
            bit_count_r             <= 4'd0;
            loading_r               <= 1'b0;
            shifting_r              <= 1'b0;  
            transaction_completed_r <= 1'b0;
        end
    end
    
endmodule