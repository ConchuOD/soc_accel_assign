`timescale 1ns / 1ps

module AHBspi (
        input              HCLK,
        input              HRESETn,
        input              HSEL,
        input              HREADY,          // Indicates previous AHB transaction completing
        input       [31:0] HADDR,
        input              HWRITE,
        input       [2:0]  HSIZE,
        input       [1:0]  HTRANS,
        input       [31:0] HWDATA,
        output reg  [31:0] HRDATA,
        output wire        HREADYOUT,
        // SPI
        input              SPI_MISO_i,
        output wire        SPI_MOSI_o,
        output wire [31:0] SPI_SS_o,
        output wire        SPI_CLK_o
    );
    
    localparam [3:0] CONTROL_STATUS_ADDR=4'b0000, SPI_SLAVE_SELECT_ADDR=4'b0100, SPI_WDATA_ADDR=4'b1000, SPI_RDATA_ADDR=4'b1100; 
    localparam [7:0] CONTROL_STATUS_REG_BITMASK = 8'hF0; 
    localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;
    localparam CS_RDATA_READY_INDEX = 0, CS_RDATA_BYTES_VALID_COUNT_INDEX = 1, CS_WDATA_FINISHED_INDEX = 4;
    
    localparam IDLE = 1'b0, TRANSACT = 1'b1;

    reg [31:0] HADDR_r;
    reg [ 3:0] HSIZE_r;
    reg HWRITE_r;
    reg write_r, read_r; 
    
    reg[7:0] ctrl_status_r; 
    reg[31:0] spi_ss_r, write_only_r, read_only_r;
    reg spi_state_r;   
    wire spi_ss_reduce_c;
    reg spi_enable_r;
    wire[31:0] spi_read_data_x;
    
    reg pending_spi_transaction_r;
    
    reg[2:0] spi_data_byte_writes_required_r;
    wire[2:0] spi_read_data_bytes_valid_x;
    
    assign SPI_SS_o = spi_ss_r;
    assign spi_ss_reduce_c = ~&spi_ss_r;
    
    always @(posedge HCLK) begin
        // Address phase
        if(HREADY) begin
            HADDR_r <= HADDR;
            HSIZE_r <= HSIZE;
            write_r <= HWRITE & HSEL & HTRANS[1];
            read_r  <= ~HWRITE & HSEL & HTRANS[1];
        end 

        if(~HRESETn) begin
            HADDR_r <= 1'b0;
            HSIZE_r <= 1'b0;
            write_r <= 1'b0;
            read_r  <= 1'b0;
        end
    end 
    
    //                              CONTROL/STATUS
    // | CPOL | CPHA | NOT USED | WDATA_FINISHED | RDATA_BYTES_VALID_COUNT | RDATA_READY |
    // |  7   |  6   |     5    |       4        |           3,2,1         |      0      |
    
    always @(posedge HCLK) begin
        // Data phase   
        pending_spi_transaction_r                         <= 1'b0; // Only goes high for 1 clock cycle
        if(write_r) begin
            case (HADDR_r[3:0])
            (CONTROL_STATUS_ADDR):   ctrl_status_r        <= HWDATA[7:0] & CONTROL_STATUS_REG_BITMASK;                                         
            (SPI_SLAVE_SELECT_ADDR): spi_ss_r             <= HWDATA;
            (SPI_WDATA_ADDR): begin
                write_only_r                              <= HWDATA;
                pending_spi_transaction_r                 <= 1'b1;
                case (HSIZE_r)
                (BYTE): spi_data_byte_writes_required_r <= 3'd1;
                (HALF): spi_data_byte_writes_required_r <= 3'd2;
                (WORD): spi_data_byte_writes_required_r <= 3'd4;                
                endcase
            end
            endcase
        end
        else if (read_r) begin
            case (HADDR_r[3:0])            
            (CONTROL_STATUS_ADDR):   HRDATA              <= ctrl_status_r;
            (SPI_SLAVE_SELECT_ADDR): HRDATA              <= spi_ss_r;
            (SPI_WDATA_ADDR):        HRDATA              <= write_only_r;
            (SPI_RDATA_ADDR): begin
                                     HRDATA              <= read_only_r;
                ctrl_status_r[CS_RDATA_BYTES_VALID_COUNT_INDEX +: 3] <= 3'd0;       // Read out data has been sent, so it is now stale
                ctrl_status_r[CS_RDATA_READY_INDEX]      <= 1'b0;       
            end
            endcase  
        end
    
        if(~HRESETn) begin
            HADDR_r                         <= 32'd0;
            HWRITE_r                        <= 1'b0;
            HRDATA                          <= 32'b0;
            ctrl_status_r                   <= 8'd0;
            spi_ss_r                        <= 32'hFF_FF_FF_FF;
            write_only_r                    <= 32'd0;
            spi_data_byte_writes_required_r <= 1'b0;
            pending_spi_transaction_r       <= 1'b0;
        end
    end
    
    always @(posedge HCLK) begin
        case (spi_state_r)
        IDLE : begin
            if(pending_spi_transaction_r && spi_ss_reduce_c) begin
                // Write all the bytes, then continue to write with meaningless
                // values until slave select goes low
                spi_state_r                            <= TRANSACT;
                //spi_tx_bytes_valid_r                   <= spi_data_byte_writes_required_r;
                spi_enable_r                           <= 1'b1; 
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b0; // The data requested to be written has not been written yet                
            end
        end        
        TRANSACT : begin
            if(spi_read_data_bytes_valid_x == spi_data_byte_writes_required_r) begin
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b1; // Have written down the number of bytes requested to be written
            end
            
            if(spi_read_data_bytes_valid_x == 3'd4) begin
                ctrl_status_r[CS_RDATA_READY_INDEX] <= 1'd1;
            end
            
            // Update the amount of valid bytes in the read_only register
            ctrl_status_r[CS_RDATA_BYTES_VALID_COUNT_INDEX +: 3] <= spi_read_data_bytes_valid_x;
            read_only_r                                          <= spi_read_data_x;
            
            if(~spi_ss_reduce_c) begin
                spi_state_r                         <= IDLE;
                spi_enable_r                        <= 1'b0;
                ctrl_status_r[CS_RDATA_READY_INDEX] <= 1'd1;
            end
        end        
        endcase
        
        if(~HRESETn) begin
            spi_state_r  <= IDLE;
            read_only_r  <= 32'd0;
            spi_enable_r <= 1'b0;
        end
    end
    
    SPIMaster spiMaster (
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .enable_i(spi_enable_r),
        .spi_write_data_i(write_only_r),
        .spi_write_data_bytes_valid_i(spi_data_byte_writes_required_r), // How many bytes did he want to write down?
        .spi_miso_i(SPI_MISO_i),
        .spi_mosi_o(SPI_MOSI_o),
        .spi_clk_o(SPI_CLK_o),
        .spi_read_data_o(spi_read_data_x),
        .spi_read_data_bytes_valid_o(spi_read_data_bytes_valid_x)
    );

    // Never delayed
    assign HREADYOUT = 1'b1; 

endmodule