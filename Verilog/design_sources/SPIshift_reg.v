module SPIwrite_shift_reg (
    input wire spi_clk_i,
    input wire rstn_i,
    output reg shift_out_o,
    input wire[7:0] data_i,
    input wire load_data_en_i
) 

reg[7:0] shift_reg_r;

assign shift_out_o = shift_reg_r[7];

always @(data_i, load_data_en_i, shift_reg_r, rstn_i) begin
    if(load_data_en_i) begin
        next_shift_reg_r = data_i;    
    else    
        shift_reg_next_r = {shift_reg_r[6:0], 1'b0};
    end
    
    if(~rstn_i) begin
        shift_reg_r = 8'd0;
    end
end

// Writing
always @(negedge spi_clk_i) begin    
    shift_reg_r <= shift_reg_next_r;
end

endmodule