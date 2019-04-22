`timescale 1ns / 1ps    
/*************************************************************************/
/* Author: Conor Dooley/Daniel Groos October 2016                        */
/* Digital System Design                                                 */
/* Extended to 8 digits 31/03/19 Conor Dooley                            */
/*************************************************************************/
module DisplayInterface (
    input             reset,
    input             clock,
    input      [31:0] value,
    input      [7:0]  enable,
    input      [7:0]  point,
    output     [7:0]  segment, 
    output reg [7:0]  digit
    );

    reg  [2:0]  countOutput;
    wire [2:0]  nextCount;
    reg  [3:0]  rawSeg;
    wire [6:0]  segSeven;
    wire [10:0] enableCountNext;
    reg  [10:0] enableCount;
    wire        enableReg;
    reg         radixOut;

    //slows down clock 2048 times to get readable digit cycling, by using an 11 bit counter & an enable input on the 2 bit count register
    always @ (posedge clock or posedge reset)
    begin
        if(reset) enableCount <= 11'b0;
        else      enableCount <= enableCountNext;
    end
    assign enableCountNext = enableCount + 1'b1;
    //enable digit count register every 2048 cycles
    assign enableReg = (enableCount == 11'd0)? 1'b1 : 1'b0;
    //2 bit counter selects which 4 bits to send to hex2seg, which point bit to use, and which digit to light up
    always @ (posedge clock or posedge reset)
    begin
        if(reset)           countOutput <= 3'd0;
        else if (enableReg) countOutput <= nextCount;
        else                countOutput <= countOutput; 
    end
    assign nextCount = countOutput + 1'b1;
    //selecting digit changes 2 bit count into 1 cold for display selection
    always @ (countOutput)
    begin
        case(countOutput)
            3'b000: digit = 8'b11111110;
            3'b001: digit = 8'b11111101;
            3'b010: digit = 8'b11111011;
            3'b011: digit = 8'b11110111;
            3'b100: digit = 8'b11101111;
            3'b101: digit = 8'b11011111;
            3'b110: digit = 8'b10111111;
            3'b111: digit = 8'b01111111;
        endcase
    end
    //chooses which 4 bits to send to hex2seg based on 2 bit counter
    always @ (countOutput, value)
    begin
        case(countOutput)
            3'b000: rawSeg = value[3:0];
            3'b001: rawSeg = value[7:4];
            3'b010: rawSeg = value[11:8];
            3'b011: rawSeg = value[15:12];
            3'b100: rawSeg = value[19:16];
            3'b101: rawSeg = value[23:20];
            3'b110: rawSeg = value[27:24];
            3'b111: rawSeg = value[31:28];  
        endcase
    end
    //converts 4 bit input hex into 7 bit segment information
    BcdToSeg bcdSeg (
        .number(rawSeg), 
        .pattern(segSeven)
    );
    
    //selecting radix - pipes 1 bit onwards to be joined with 7bit segment info depending on digit counter
    always @ (countOutput, point)
    begin
        case(countOutput)
            3'b000: radixOut = ~point[0];
            3'b001: radixOut = ~point[1]; 
            3'b010: radixOut = ~point[2];
            3'b011: radixOut = ~point[3];
            3'b100: radixOut = ~point[4];
            3'b101: radixOut = ~point[5];
            3'b110: radixOut = ~point[6];
            3'b111: radixOut = ~point[7]; 
        endcase
    end
    //7 bit pattern + 1 bit radix point to 8 bit segment output
    assign segment = { segSeven[6:0], radixOut } | {(8){~enable[countOutput]}}; //enable mask 
endmodule