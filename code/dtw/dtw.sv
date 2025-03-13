`default_nettype none 

module (camera, refer, score, clk, rst_n);
	///////////////////////////////////////////////
	//
	//
	//
	///////////////////////////////////////////
	 
	parameter R = 10;
	parameter WIDTH = 8;

	input [WIDTH - 1:0] camera, refer;
	input rst_n, clk;
	output [WIDTH - 1:0] score;

	reg [WIDTH - 1:0] last, band, output, min, accum, distance;
	
	shift_register sreg(.in(accum), .clk(clk), .rst_n(rst_n), .last(last), .band(band), .output(output));

	// distance
	always ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) begin:
			distance <= 0;
		end
		else begin
			distance <= camera - refer; //mod this
		end
	end

	// minimum
	assign min = (last < band) ? (last < output ? last : output) : (band < output ? band : output);
	// add
	always ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) begin:
			accum <= 0;
		end
		else begin
			accum <= distance + min;
		end
	end

	assign score = output;

endmodule

`default_nettype wire