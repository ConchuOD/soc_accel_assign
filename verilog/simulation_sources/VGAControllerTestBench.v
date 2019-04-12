module VGAControllerTestBench ();

    reg rst_pbn;
    reg clk_25m_x;

    initial
    begin
        clk_25m_x  = 1'b0;
        forever
        begin
            #20 clk_25m_x = ~clk_25m_x;
        end
    end
    
    VGAController dut(
    .rst_low_i(rst_pbn),
    .block_clk_i(clk_25m_x),
    .h_sync_o(), 
    .v_sync_o()
    );
   
    initial
    begin
        rst_pbn = 1'b0;
        #100
        rst_pbn = 1'b1;
        #1_000_000_000
        rst_pbn = 1'b0;
        $stop;
    end

endmodule // VGAControllerTestBench 