module scp
(
    input  src_clk_i,
    input  dest_clk_i,
    input  rstn_i,
    input  input_pulse_i,
    output reg output_pulse_o    
);
    reg source_sync_r;
    reg dest_sync_r, dest_sync_d_r;

    always @(posedge src_clk_i) begin
        if (input_pulse_i) begin
            source_sync_r <= ~source_sync_r;
        end
        
        if(~rstn_i) begin
            source_sync_r <= 1'b0;
        end
    end
    
    always @(negedge dest_clk_i) begin
        dest_sync_r <= source_sync_r;
        dest_sync_d_r <= dest_sync_r;
        output_pulse_o <= dest_sync_r ^ dest_sync_d_r;
        
        if(~rstn_i) begin
            dest_sync_r <= 1'b0;
            dest_sync_d_r <= 1'b0;
            output_pulse_o <= 1'b0;
        end
    end
endmodule