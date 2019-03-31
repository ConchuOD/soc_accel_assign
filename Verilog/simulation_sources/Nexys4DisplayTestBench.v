module Nexys4DisplayTestBench ();

	reg rst_pbn;
    reg clk5_x,clk_spi_x;
    reg spi_data,spi_ss;
    
    integer bits_to_send;
    integer clock_inc;

	initial
	begin
		clk5_x  = 1'b0;
		forever
		begin
			#100 clk5_x = ~clk5_x;
		end
	end
    
    task send_spi_message;
    input [0:15] val_to_send; //indexed in reverse
    begin
        clk_spi_x    = 1'b1;
        bits_to_send = 16;
        spi_ss       = 1'b0;
        spi_ss       = 1'b0;
        
        #200 clk_spi_x = 1'b0;
        
		for(clock_inc=0;clock_inc<bits_to_send;clock_inc=clock_inc+1)
		begin
            #50  spi_data  = val_to_send[clock_inc];
            #150 clk_spi_x = 1'b1; //send clock high            
			#200 clk_spi_x = 1'b0; //send clock low
		end
        spi_ss = 1'b1;        
    end
    endtask
    
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
        spi_data = 1'b1;
        clk_spi_x  = 1'b1;
        #10
		rst_pbn = 1'b0;
		#100 
		rst_pbn = 1'b1;
        #100
        send_spi_message(16'b0001_0000_0000_1100);
        send_spi_message(16'h1_1_aa);
        send_spi_message(16'h1_2_bb);
        send_spi_message(16'h1_3_cc);
        send_spi_message(16'h1_4_dd);
        send_spi_message(16'h0_4_ff);
        send_spi_message(16'h1_ff_77);
		#300
		$stop;
	end

endmodule // LoopFilterTestBench 