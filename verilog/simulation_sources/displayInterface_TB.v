`timescale 1ns / 1ps
module TB_displayInterface;
	// Inputs to module being verified
	reg clock, reset;
	reg [31:0] value;
	// Outputs from module being verified
	wire [7:0] segment, digit;
	// Instantiate module
	DisplayInterface uut (
		.clock(clock),
		.value(value),
		.reset(reset),
        .point(8'haa),
        .enable(8'd255),
		.segment(segment),
		.digit(digit)
		);
	// Generate clock signal
	initial
		begin
			clock  = 1'b1;
			forever
				#100 clock  = ~clock ;
		end
	// Generate other input signals
	initial
		begin
			value = 32'h0;
			reset = 1'b0;
			#50
			value = 32'h0000ffff;
			#0
			reset = 1'b1;
			#100
			reset = 1'b0;
			#600
			value = 32'h00000004;
			#900
			value = 32'h00000005;
			#800
			value = 132'h00000056;
			#1500
			value = 132'h000000aa;
			#6050
			$stop;
		end
endmodule
