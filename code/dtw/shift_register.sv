`default_nettype none 

module shift_register(in, clk, rst_n, last, band, out);
	///////////////////////////////////////////////
	//
	//
	//
	///////////////////////////////////////////
	
    parameter R = 2;
	parameter WIDTH = 8;

	input reg [WIDTH - 1 : 0] in;
    input reg clk, rst_n;
	output reg [WIDTH - 1 : 0] last, band, out;

    reg [WIDTH - 1 : 0] sreg [R : 0];

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sreg[0] <= 0;
            sreg[1] <= 0;
            sreg[2] <= 0;
        end
        else begin
            sreg[0] <= in;
            sreg[1] <= sreg[0];
            sreg[2] <= sreg[1];
        end
    end
	
assign last = sreg[0];
assign band = sreg[R - 1];
assign out = sreg[R];

endmodule

`default_nettype wire