module Nexys4DisplayTestBench ();

    reg rst_pbn;
    reg clk6m25_x,clk_spi_x;
    reg spi_data,spi_ss;
    
    integer bits_to_send;
    integer clock_inc;

    initial
    begin
        clk6m25_x  = 1'b0;
        forever
        begin
            #80 clk6m25_x = ~clk6m25_x;
        end
    end
    
    task send_spi_message;
    input [0:15] val_to_send; //indexed in reverse
    begin
        bits_to_send = 16;
        spi_ss       = 1'b0;
        
        for(clock_inc=0;clock_inc<bits_to_send;clock_inc=clock_inc+1)
        begin
            #50  spi_data  = val_to_send[clock_inc];
            #150 clk_spi_x = 1'b1; //send clock high
            #200 clk_spi_x = 1'b0; //send clock low
        end        
        #10;
        spi_ss = 1'b1;        
    end
    endtask
    
    task send_spi_message_noss;
    input [0:15] val_to_send; //indexed in reverse
    begin
        bits_to_send = 16;
        //spi_ss       = 1'b0;
                
        for(clock_inc=0;clock_inc<bits_to_send;clock_inc=clock_inc+1)
        begin
            #50  spi_data  = val_to_send[clock_inc];
            #150 clk_spi_x = 1'b1; //send clock high            
            #200 clk_spi_x = 1'b0; //send clock low
        end
        spi_ss = 1'b1;        
    end
    endtask
    
    task send_spi_message_fail;
    input [0:15] val_to_send; //indexed in reverse
    begin
        bits_to_send = 16;
        spi_ss       = 1'b0;
             
        for(clock_inc=0;clock_inc<bits_to_send/2;clock_inc=clock_inc+1)
        begin
            #50  spi_data  = val_to_send[clock_inc];
            #150 clk_spi_x = 1'b1; //send clock high
            #200 clk_spi_x = 1'b0; //send clock low
        end
        #10;
        spi_ss = 1'b1;        
    end
    endtask
    
    Nexys4Display dut (
        .rst_low_i(rst_pbn),
        .block_clk_i(clk6m25_x),
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
        clk_spi_x  = 1'b0;
        #10
        rst_pbn = 1'b0;
        #100 
        rst_pbn = 1'b1;
        #100
        send_spi_message(16'b0001_0000_0000_1100);
        #1000
        send_spi_message_fail(16'h1_6_ee);
        #1000
        send_spi_message(16'h1_1_aa);
        #1000
        send_spi_message(16'h1_1_aa);
        #1000
        send_spi_message(16'h1_2_bb);
        #1000
        send_spi_message(16'h1_3_cc);
        #1000
        send_spi_message(16'h1_4_dd);
        #1000
        send_spi_message(16'h0_4_ff);
        #1000
        send_spi_message(16'h1_ff_77);
        #1000
        send_spi_message_noss(16'h1_1_ee);
        #300
        $stop;
    end

endmodule // Nexys4DisplayTestBench 