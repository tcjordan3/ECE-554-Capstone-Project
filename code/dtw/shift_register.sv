`default_nettype none 

module shift_register(in, clk, rst_n, out, ready_in, ready_out, empty);
	///////////////////////////////////////////////
	//
	//
	//
	///////////////////////////////////////////
	
    parameter R = 2; // can this be made an input
	parameter WIDTH = 8;

	input reg [WIDTH - 1 : 0] in;
    input reg clk, rst_n, ready_in, ready_out, empty;
	output reg [WIDTH - 1 : 0] out;

    logic [WIDTH - 1 : 0] sreg [R : 0];
    logic [WIDTH - 1 : 0] count;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sreg[0] <= 0;
            sreg[1] <= 0;
            sreg[2] <= 0;
            count = 0;
        end
        else if (ready_in) begin
            sreg[0] <= in;
            sreg[1] <= sreg[0];
            sreg[2] <= sreg[1];
            count += 1;
        end
        else if (ready_out) begin
            out = sreg[R];
            count -=1;
        end
    end

    assign empty = (count == 0);
endmodule

`default_nettype wire