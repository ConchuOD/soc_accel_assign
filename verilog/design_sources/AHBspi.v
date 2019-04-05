`timescale 1ns / 1ps

module AHBspi (
        input  wire        HCLK,
        input  wire        HRESETn,
        input  wire        HSEL,
        input  wire        HREADY,          // Indicates previous AHB transaction completing
        input  wire [31:0] HADDR,
        input  wire        HWRITE,
        input  wire [2:0]  HSIZE,
        input  wire [31:0] HWDATA,
        output wire [31:0] HRDATA,
        output wire        HREADYOUT,
        // SPI
        input  wire        SPI_MISO_i,
        output wire        SPI_MOSI_o,
        output reg  [31:0] SPI_SS_o,
        output wire        SPI_CLK_o
    );
    
    localparam [2:0] CONTROL_STATUS_ADDR=3'b000, SPI_SLAVE_SELECT_ADDR=3'b001, SPI_WDATA_ADDR=3'b010; 
    localparam [7:0] CONTROL_STATUS_REG_BITMASK = 0xF0; 
    localparam CS_RDATA_VALID_INDEX = 0, CS_WDATA_FINISHED_INDEX = 1;
    
    localparam IDLE = 1'b0, TRANSACT = 1'b1;

    reg [31:0] HADDR_r;
    reg [3:0] HSIZE_r;
    reg write_r, read_r; 
    
    reg[7:0] ctrl_status_r, 
    reg[31:0] spi_ss_r, write_only_r, read_only_r;

    reg[2:0] spi_data_byte_writes_required_r, spi_transactions_required_fixed_r, spi_transactions_completed_r;
    reg[2:0] read_fill_level_bytes_r;
    reg spi_state_r, init_transaction_r;

    reg[7:0] spi_tx_data_r
    
    wire spi_clk_en_c;
    wire[7:0] spi_rx_data_x;
    
    always @(posedge HCLK) begin
        // Address phase
        if(HREADY) begin
            // Capture HADDR, HWRITE
            HADDR_r <= HADDR;
            HSIZE_r <= HSIZE;
            write_r <= HWRITE & HSEL;
            read_r  <= ~HWRITE & HSEL;
        end 

         if(~HRESETn) begin
            HADDR_r <= 1'b0;
            HSIZE_r <= 1'b0;
            write_r <= 1'b0;
            read_r  <= 1'b0;
         end
    end
    
    assign spi_clk_en_c = ~&spi_ss_r;
    
    //                      CONTROL/STATUS
    // | CPOL | CPHA | SPI_BITRATE | NOT USED | WDATA_FINISHED | RDATA_VALID |
    // |  7   |  6   |     5,4     |   3,2    |       1        |      0      |
    
    always @(posedge HCLK) begin
        // Data phase        
        // AHB write transaction
        if(HWRITE_r) begin
            case (HADDR_r[2:0])
            (CONTROL_STATUS_ADDR):   ctrl_status_r <= HWDATA[7:0] & CONTROL_STATUS_REG_BITMASK;                                         
            (SPI_SLAVE_SELECT_ADDR): spi_ss_r      <= HWDATA;
            (SPI_WDATA_ADDR):
                write_only_r <= HWDATA;   
                case (HSIZE_r)
                (3'b000): spi_data_byte_writes_required_r <= 3'd1;
                (3'b001): spi_data_byte_writes_required_r <= 3'd2;
                (3'b010): spi_data_byte_writes_required_r <= 3'd4;
                endcase  
        // AHB read transaction             
        else begin
            HRDATA                              <= read_only_r;
            ctrl_status_r[CS_RDATA_VALID_INDEX] <= 1'b0;            // Read out data has been sent
        end
    
        if(~HRESETn) begin
            HADDR_r                     <= 32'd0;
            HWRITE_r                    <= 1'b0;
            ctrl_status_r               <= 8'd0;
            spi_ss_r                    <= 32'd0;
            write_only_r                <= 32'd0;
            spi_data_byte_writes_required_r <= 1'b0;
        end
    end
    
    always @(posedge HCLK) begin
        case (spi_state_r)
        IDLE : begin
            if(spi_data_byte_writes_required_r > 3'd0 && spi_clk_en_c) begin
                // Write all the bytes, then continue to write with meaningless
                // values until slave select goes low
                spi_state_r              <= TRANSACT;
                spi_tx_data_r            <= write_only_r;
                spi_tx_bytes_valid_r     <= spi_data_byte_writes_required_r;
                spi_init_transactions_r  <= 1'b1;  
                //spi_tx_byte_r                          <= write_only_r[8*(spi_transactions_completed_r + 1) - 1:8*(spi_transactions_completed_r)];
                /*
                spi_state_r                            <= TRANSACT;
                spi_init_transactions_r                     <= 1'b1;  

                // Load 32 bits of data into SPI master, and indicate how many are valid
                spi_tx_bytes_valid_r                   <= spi_data_byte_writes_required_r;
                spi_tx_byte_r                          <= write_only_r[8*(spi_transactions_completed_r + 1) - 1:8*(spi_transactions_completed_r)];
                
                //spi_transactions_completed_r           <= spi_transactions_completed_r + 3'd1;
                
                // Copy the value of transactions required
                //spi_transactions_required_fixed_r      <= spi_data_byte_writes_required_r;                
                
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b0; // The data requested to be written has not been written yet
                */
            end
        end        
        TRANSACT : begin
            // Need to check if 
            // - 4 bytes have been written (data or meaningless), so we can get them into a register
            //   readable by AHB reads
            // - what the fill level of the read buffer is? No
            
            // spi master pushes its buffer contents out into ahb spi register when it has filled up, 
            // or spi slave select goes high
            
            
            
            /*
            init_transaction_r <= 1'b0;
            
            if(spi_ready_x && ~init_transaction_r) begin
                spi_tx_data_r <= write_only_r[8*(spi_transactions_completed_r + 1) - 1:8*(spi_transactions_completed_r)];
            
                // Capture the data read in from SPI
                read_only_r[8*(read_fill_level_bytes_r + 1) - 1:8*read_fill_level_bytes_r] <= spi_rx_data_x;
                // Update offset
                read_fill_level_bytes_r <= (read_fill_level_bytes_r % 3'd4) + 3'd1;
                
                // Go straight into another SPI transaction
                if(spi_transactions_completed_r ~= spi_transactions_required_fixed_r) begin
                    init_transaction_r             <= 1'b1;     
                    spi_transactions_completed_r   <= spi_transactions_completed_r + 3'd1;
                end
                else
                    spi_state_r                            <= IDLE;
                    spi_transactions_completed_r           <= 3'd0;
                    ctrl_status_r[CS_RDATA_VALID_INDEX]    <= 1'b1; // Have valid data stored and available
                    ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b1; // The data requested to be written has been written
                end
            end
            */
        end
        endcase
        if(~HRESETn) begin
            spi_state_r                       <= IDLE;
            spi_transactions_required_fixed_r <= 3'd0;
            spi_transactions_completed_r      <= 3'd0;
            read_fill_level_bytes_r           <= 3'd0;
        end
    end
    
    SPIMaster spiMaster (
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .ready_i(init_transaction_r),
        .spi_tx_bytes_valid_i(spi_tx_bytes_valid_r),
        .spi_tx_data_i(spi_tx_data_r),
        .spi_rx_data_o(spi_rx_data_x),
        .spi_miso_i(SPI_MISO_i),
        .spi_mosi_o(SPI_MOSI_o),
        .spi_clk_en_i(spi_clk_en_c),
        .spi_clk_o(SPI_CLK_o),
        .spi_ss_o(SPI_SS_o),
        .ready_o(spi_ready_x)
    );

    // Never delayed
    assign HREADYOUT = 1'b1; 

endmodule