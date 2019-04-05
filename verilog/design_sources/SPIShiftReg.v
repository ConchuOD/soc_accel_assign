module SPIShiftReg 
#(
    parameter RWn = 0
    // Other parameters based on writing/reading on posedge/negedge clk_i,
    // are required
    // This version only accounts for SPI slaves that 
    // - read on posedge SPI_clk
    // - write on negedge SPI_clk
    // - have an idle high SPI_clk
)
(   
    input  wire       clk_i,
    input  wire       rstn_i,
    input  wire       data_bit_i,
    input  wire [7:0] data_byte_i,
    output wire [7:0] data_byte_o,
    input  wire       load_byte_en_i,
    input  wire       load_bit_en_i,
    output wire       shift_out_o
); 

reg[7:0] shift_reg_r;

assign shift_out_o = shift_reg_r[7]; 
assign data_byte_o = shift_reg_r;       

generate
    // Read shift register
    if(RWn == 1) begin : genReadShiftReg
        // Async reset - will have to talk about this
        always @(posedge clk_i, negedge rstn_i) begin 
            if(load_bit_en_i) begin
                shift_reg_r = {shift_reg_r[6:0], data_bit_i};
            end
            
            if(~rstn_i) begin
                shift_reg_r <= 8'd0;
            end            
        end
    end 
    // Write shift register
    else if(RWn == 0) begin : genWriteShiftReg
        // TODO: Async reset - will have to talk about this
        always @(negedge clk_i, negedge rstn_i) begin
            if(load_byte_en_i) begin
                shift_reg_r <= data_byte_i; 
            end   
            else if(load_bit_en_i) begin   
                shift_reg_r <= {shift_reg_r[6:0], data_bit_i}; // Should be pulling in data for the next byte if it is available here
            end
            
            if(~rstn_i) begin
                shift_reg_r <= 8'd0;
            end
        end
    end
endgenerate

endmodule