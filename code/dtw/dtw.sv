`default_nettype none 

module dtw(camera, refer, score, clk, rst_n);
	///////////////////////////////////////////////
	//
	//
	//
	///////////////////////////////////////////
	 
	parameter R = 10;
	parameter WIDTH = 8;

	input reg [WIDTH - 1:0] camera, refer;
	input reg rst_n, clk;
	output reg [WIDTH - 1:0] score;

	reg [WIDTH - 1:0] last, band, out, min, accum, distance;
	
	shift_register sreg(.in(accum), .clk(clk), .rst_n(rst_n), .last(last), .band(band), .out(out));

	// distance
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			distance <= 0;
		end
		else if (camera >= refer) begin
			distance <= camera - refer; //mod this
		end
		else
			distance <= refer - camera;
	end

	// minimum
	assign min = (last < band) ? (last < out ? last : out) : (band < out ? band : out);
	// add
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			accum <= 0;
		end
		else begin
			accum <= distance + min;
		end
	end

	assign score = out;

endmodule

`default_nettype wire