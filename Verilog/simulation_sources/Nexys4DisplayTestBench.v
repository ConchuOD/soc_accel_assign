module Nexys4DisplayTestBench ();

	reg rst_pbn;
    reg clk5_x,clk_spi_x;
    reg spi_data,spi_ss;



	initial
	begin
		clk5_x  = 1'b0;
		forever
		begin
			#100 clk5_x = ~clk5_x;
		end
	end
    
    initial
	begin
		clk_spi_x  = 1'b0;
		forever
		begin
			#200 clk_spi_x = ~clk_spi_x;
		end
	end
    
    Nexys4Display dut (
        .rst_low_i(rst_pbn),
        .clock_5meg_i(clk5_x),
        .spi_sclk_i(clk_spi_x),   //idle high, posedge active, < clock_5meg_i
        .spi_ss_i(spi_ss),     //idle high
        .spi_mosi_i(spi_data),   //idle high
        .spi_miso_o(),   //idle high
        .segment_o(), 
        .digit_o()
    );

	initial
	begin
		rst_pbn = 1'b1;
        spi_ss = 1'b1;
        spi_data = 1'b0;
        #10
		rst_pbn = 1'b0;
		#100 
		rst_pbn = 1'b1;
        #100
        spi_ss = 1'b0;        
        #100
        spi_data = 1'b0; //bit 15
        #400
        spi_data = 1'b0;
        #400       
        spi_data = 1'b0;
        #400       
        spi_data = 1'b1;
        #400       
        spi_data = 1'b0;
        #400       
        spi_data = 1'b0;
        #400       
        spi_data = 1'b1;
        #400       
        spi_data = 1'b0; //bit 8
        #400
        
        spi_data = 1'b1; //bit 7
        #400
        spi_data = 1'b0;
        #400       
        spi_data = 1'b1;
        #400       
        spi_data = 1'b0;
        #400       
        spi_data = 1'b1;
        #400       
        spi_data = 1'b0;
        #400       
        spi_data = 1'b1;
        #400       
        spi_data = 1'b0; //bit 0
        #50
        spi_ss = 1'b0;
		#10
		$stop;
	end

endmodule // LoopFilterTestBench 