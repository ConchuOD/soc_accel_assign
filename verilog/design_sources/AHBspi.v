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
        output wire [31:0] HRDATA,
        output wire        HREADYOUT,
        // SPI
        input              SPI_MISO_i,
        output wire        SPI_MOSI_o,
        output wire [31:0] SPI_SS_o,
        output wire        SPI_CLK_o
    );
    
    localparam [7:0] CONTROL_STATUS_ADDR=8'h00, SPI_SLAVE_SELECT_ADDR=8'h04, SPI_WDATA_ADDR=8'h08, SPI_RDATA_ADDR=8'h0C; 
    localparam [31:0] CONTROL_STATUS_REG_BITMASK = 32'h00_00_FF_E0; 
    localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;
    localparam[3:0] CS_RDATA_READY_INDEX = 0, CS_RDATA_BYTES_VALID_COUNT_INDEX = 1, CS_WDATA_FINISHED_INDEX = 4, CS_WDATA_VALID_BYTES_INDEX = 5,
                    CS_SS_ACTIVE_HIGH = 13;
                    
    localparam IDLE = 1'b0, TRANSACT = 1'b1;

    reg [31:0] HADDR_r;
    reg [ 2:0] HSIZE_r;
    reg write_r, read_r;
    
    reg[31:0] ctrl_status_r; 
    reg[31:0] spi_ss_r, write_only_r, read_only_r;
    wire[31:0] spi_ss_c;
    wire spi_ready_x;
    
    reg await_rdata_read_r;
    wire ahb_read_spi_data_c;
    
    reg[1:0] spi_state_r;   
    
    reg[31:0] read_data_r;   
    reg reset_fill_level_r;
    
    wire[31:0] spi_read_data_x;
    reg        spi_enable_r;
    wire       spi_ss_reduce_c;
    reg[2:0]   spi_data_byte_writes_required_r;
    wire[2:0]  spi_read_data_bytes_valid_x;
    reg spi_transact_underway_r;
    
    assign spi_ss_c        = (ctrl_status_r[CS_SS_ACTIVE_HIGH]) ? ~spi_ss_r : spi_ss_r;
    assign spi_ss_reduce_c = ~&spi_ss_c;
    assign SPI_SS_o        = spi_ss_c;
    
    always @(posedge HCLK) begin
        // Address phase
        if(HREADY) begin
            HADDR_r <= HADDR;
            HSIZE_r <= HSIZE; // Not used currently - probably should be
            // e.g. if num valid bytes in control register is greater than HSIZE for
            // an intended write, don't write down...
            write_r <= HWRITE & HSEL & HTRANS[1];
            read_r  <= ~HWRITE & HSEL & HTRANS[1];
        end 

        if(~HRESETn) begin
            HADDR_r <= 32'b0;
            HSIZE_r <= 3'b0;
            write_r <= 1'b0;
            read_r  <= 1'b0;
        end
    end     
    
    always @(HADDR_r, ctrl_status_r, spi_ss_r, write_only_r, read_only_r) begin
        case (HADDR_r[7:0])
        (CONTROL_STATUS_ADDR):   read_data_r              <= ctrl_status_r;
        (SPI_SLAVE_SELECT_ADDR): read_data_r              <= spi_ss_r;
        (SPI_WDATA_ADDR):        read_data_r              <= write_only_r;
        (SPI_RDATA_ADDR):        read_data_r              <= read_only_r;               
        endcase
    end
    
    assign HRDATA              = read_data_r;
    assign ahb_read_spi_data_c = (read_r & HADDR_r[7:0] == SPI_RDATA_ADDR);
    
    always @(ctrl_status_r, HADDR_r) begin
        if((ctrl_status_r[CS_WDATA_VALID_BYTES_INDEX +: 3] <= 3'd4) & ~ahb_read_spi_data_c) begin
            spi_data_byte_writes_required_r           <= ctrl_status_r[CS_WDATA_VALID_BYTES_INDEX +: 3];               
        end
        else begin
            spi_data_byte_writes_required_r           <= 3'd0;               
        end    
    end
    
    //                              CONTROL/STATUS
    // | CPOL | CPHA | SPI_SS_ACTIVE_HIGH | NOT USED | WDATA_VALID_BYTES | WDATA_FINISHED | RDATA_BYTES_VALID_COUNT | RDATA_READY |
    // |  15  |  14  |          13        |   12-8   |       7,6,5       |       4        |           3,2,1         |      0      |
    
    always @(posedge HCLK) begin
        // Data phase   
        if(write_r) begin
            case (HADDR_r[7:0])
            (SPI_SLAVE_SELECT_ADDR): spi_ss_r             <= HWDATA;
            (SPI_WDATA_ADDR):        write_only_r         <= HWDATA;            
            endcase
        end
    
        if(~HRESETn) begin
            spi_ss_r                        <= 32'hFF_FF_FF_FF;
            write_only_r                    <= 32'd0;
        end
    end
    
    always @(posedge HCLK) begin
        reset_fill_level_r <= 1'b0;
        
        if(write_r & (HADDR_r[7:0] == CONTROL_STATUS_ADDR)) begin
            ctrl_status_r <= HWDATA & CONTROL_STATUS_REG_BITMASK;                                         
        end
        
        case (spi_state_r)
        IDLE : begin
            if(write_r & spi_ss_reduce_c & spi_data_byte_writes_required_r > 3'd0 & spi_ready_x) begin
                spi_state_r                            <= TRANSACT;
                spi_enable_r                           <= 1'b1; 
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b0; // The data requested to be written has not been written yet                
            end
        end        
        TRANSACT : begin
            // Logic for WDATA_FINISHED flag
            // Ensures SPI transaction has started
            if(spi_read_data_bytes_valid_x > 3'd0) begin
                spi_transact_underway_r <= 1'b1;
            end 

            if(spi_read_data_bytes_valid_x == spi_data_byte_writes_required_r) begin
                spi_enable_r <= 1'b0;
            end    
            
            // Know SPI is ready for another transaction here
            if(spi_transact_underway_r & spi_ready_x) begin
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b1; // Have written down the number of bytes requested to be written
                ctrl_status_r[CS_RDATA_READY_INDEX]    <= 1'b1; // Have written down the number of bytes requested to be written
                //spi_enable_r                           <= 1'b0; 
                spi_transact_underway_r                <= 1'b0;
            end
            
            // User doesn't care about the data received from SPI
            // and wants to perform another write
            if(write_r & spi_ready_x & ctrl_status_r[CS_RDATA_READY_INDEX]) begin
                spi_enable_r                           <= 1'b1; 
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b0; // Read has occurred, so reset the data_written flag
                ctrl_status_r[CS_RDATA_READY_INDEX]    <= 1'd0;
            end
            
            read_only_r                                <= spi_read_data_x;
            
            // If slave has been disabled, or the SPI read data has been read,
            // we can idle
            if(~spi_ss_reduce_c | spi_data_byte_writes_required_r == 3'd0) begin
                spi_state_r                            <= IDLE;
                spi_enable_r                           <= 1'b0;                
                ctrl_status_r[CS_WDATA_FINISHED_INDEX] <= 1'b0; // Read has occurred, so reset the data_written flag
                ctrl_status_r[CS_RDATA_READY_INDEX]    <= 1'd0;
                ctrl_status_r[CS_RDATA_BYTES_VALID_COUNT_INDEX +: 3] <= 3'd0;
                spi_transact_underway_r <= 1'b0;
            end
        end 
        endcase
        
        if(~HRESETn) begin
            spi_state_r   <= IDLE;
            read_only_r   <= 32'd0;
            spi_enable_r  <= 1'b0;
            ctrl_status_r <= 32'd0;
            spi_transact_underway_r <= 1'b0;
        end
    end
    
    SPIMaster spiMaster (
        .clk_i(HCLK),
        .rstn_i(HRESETn),
        .enable_i(spi_enable_r),
        .spi_write_data_i(write_only_r),
        .spi_write_data_bytes_valid_i(spi_data_byte_writes_required_r), // How many bytes did he want to write down?
        .reset_fill_level_i(reset_fill_level_r),
        .spi_miso_i(SPI_MISO_i),
        .spi_mosi_o(SPI_MOSI_o),
        .spi_clk_o(SPI_CLK_o),
        .spi_read_data_o(spi_read_data_x),
        .spi_read_data_bytes_valid_o(spi_read_data_bytes_valid_x),
        .ready_o(spi_ready_x)
    );

    // Never delayed
    assign HREADYOUT = 1'b1; 

endmodule