`timescale 1ns / 1ps

module TB_AHBspi ();

    localparam [2:0] BYTE = 3'b000, HALF = 3'b001, WORD = 3'b010;   // HSIZE values
    localparam [1:0] IDLE = 2'b00, NONSEQ = 2'b10;    // HTRANS values

    reg HCLK;				// bus clock
    reg HRESETn;            // bus reset, active low
    reg HSELx = 1'b0;       // selects this slave
    reg [31:0] HADDR = 32'h0;    // address
    reg [1:0] HTRANS = 2'b0;    // transaction type (only bit 1 used)
    reg HWRITE = 1'b0;            // write transaction
    reg [2:0] HSIZE = 3'b0;        // transaction width (max 32-bit supported)
    reg [31:0] HWDATA = 32'h0;    // write data
    wire [31:0] HRDATA;     // read data from slave
    wire HREADY;            // ready signal - from slave, also to slave
	 
    wire SPI_mosi_x;
    wire SPI_miso_x;
    wire[31:0] SPI_ss_x;
    wire SPI_clk_x;
    
    reg block_clk;
    wire SPI_ss_disp_c;
    
    
    assign SPI_ss_disp_c = SPI_ss_x[0];

    AHBspi dut(
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HSEL(HSELx),
        .HREADY(HREADY),    
        .HADDR(HADDR),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HTRANS(HTRANS),
        .HWDATA(HWDATA),
        .HRDATA(HRDATA),
        .HREADYOUT(HREADY),    
        .SPI_MISO_i(SPI_miso_x),
        .SPI_MOSI_o(SPI_mosi_x),
        .SPI_SS_o(SPI_ss_x),
        .SPI_CLK_o(SPI_clk_x)
        );
        
    Nexys4Display dispTest(
        .rst_low_i(HRESETn),
        .block_clk_i(block_clk),
        .spi_sclk_i(SPI_clk_x),   //id
        .spi_ss_i(SPI_ss_disp_c), // Display is slave index 0
        .spi_mosi_i(SPI_mosi_x),  //id
        .spi_miso_o(SPI_miso_x),  //id
        .segment_o(),
        .digit_o()
    );

    initial
    begin
        HCLK = 1'b0;
        forever	// generate 50 MHz clock
        begin
          #10 HCLK = ~HCLK;
        end
    end
    
    initial
    begin
        block_clk = 1'b0;
        forever	// generate 5 MHz clock for display
        begin
          #100 block_clk = ~block_clk;
        end
    end
    
    initial
    begin
        HRESETn = 1'b1;
        #20 HRESETn = 1'b0;
        #20 HRESETn = 1'b1;
        #50;
        
        // Set SPI slave select all disabled except last (active low)
        // to select the display
        AHBwrite(WORD, 32'h4, 32'hFF_FF_FF_FE);
        // Write two bytes to the display
        AHBwrite(HALF, 32'h8, 32'h00_00_11_08);
        
        // Wait until the intended number of bytes have been
        // written by SPI to the display
        while(~receivedData[4]) begin            
            AHBread(WORD, 32'h0, 32'h0);
            AHBidle;
            #100;
        end
        
        // Once the two bytes have been written, disable
        // the display slave select
        AHBwrite(WORD, 32'h4, 32'hFF_FF_FF_FF);
        AHBidle;
        #300;        
        
        HSELx = 1'b0;
    end
    
    // AHB bus tasks
    reg [31:0] nextWdata = 32'h0;   // delayed data for write transactions
    reg [31:0] expectRdata = 32'h0; // expected read data for read transactions
    reg [31:0] rExpectRead;         // store expected read data
    reg checkRead; 
    reg error = 1'b0;  // read error signal - asserted for one cycle AFTER read completes
    reg[31:0] receivedData = 32'd0;
    
    task AHBwrite;        // simulates write transaction on AHB Lite
        input [2:0] size;   // transaction width - BYTE, HALF or WORD
        input [31:0] addr;  // address
        input [31:0] data;  // data to be written
        begin
            wait (HREADY == 1'b1); // wait for ready signal - previous transaction completing
            @ (posedge HCLK);  // align with clock
            #2 HSIZE = size;    // set up signals for address phase, just after clock edge
            HTRANS = NONSEQ;
            HWRITE = 1'b1;
            HADDR = addr;
            HSELx = 1'b1;
            nextWdata = data;    // store data for use in data phase
        end
    endtask
    
    task AHBread;       // simulates read transaction on AHB Lite
        input [2:0] size;   // transaction width - BYTE, HALF or WORD
        input [31:0] addr;  // address
        input [31:0] data;  // expected data from slave
        begin  
            wait (HREADY == 1'b1); // wait for ready signal - previous transaction completing
            @ (posedge HCLK);  // align with clock
            #2 HSIZE = size;  // set up signals for address phase, just after clock edge
            HTRANS = NONSEQ;
            HWRITE = 1'b0;
            HADDR = addr;
            HSELx = 1'b1;
            expectRdata = data;  // store expected data for checking in data phase
        end
    endtask
    
    task AHBidle;       // use after read or write to put bus in idle state
        begin  
            wait (HREADY == 1'b1); // wait for ready signal - previous transaction completing
            @ (posedge HCLK);        // then wait for clock edge
            #2 HTRANS = IDLE;        // set transaction type to idle
            HSELx = 1'b0;           // deselect the slave
        end
    endtask
    
    // register holds write data until needed
    always @ (posedge HCLK or negedge HRESETn) begin
        if (~HRESETn) begin
            HWDATA <= 32'b0;
        end
        else if (HWRITE && HTRANS && HREADY) begin// write transaction moving to data phase
            #1 HWDATA <= nextWdata;
        end
    end
    
    // register holds read data until needed, another remembers that read in progress
    always @ (posedge HCLK or negedge HRESETn)
		if (~HRESETn) begin
			rExpectRead <= 32'b0;
            checkRead <= 1'b0;
        end
		else if (~HWRITE && HTRANS && HREADY) begin // read transaction moving to data phase
            rExpectRead <= expectRdata;	// update register with expected data
            checkRead <=1'b1;
        end
		else if (HREADY) // some other transaction moving to data phase
            checkRead <= 1'b0;		//  no need to check

    always @ (posedge HCLK)
		if (checkRead & HREADY)	begin// read transaction completing
				error = (HRDATA != rExpectRead);	// read transaction completing
                receivedData = HRDATA;
        end
        else error = 1'b0;	// error will be asserted for one cycle AFTER problem detected
     

endmodule