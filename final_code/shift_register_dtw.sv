`default_nettype none 

module shift_register_dtw(in, clk, rst_n, last, band, out, ready);
	///////////////////////////////////////////////
	//
	//
	//
	///////////////////////////////////////////
	
    parameter R = 9; // can this be made an input
	parameter WIDTH = 32;

	input reg [WIDTH - 1 : 0] in;
    input reg clk, rst_n, ready;
	output reg [WIDTH - 1 : 0] last, band, out;

    reg [WIDTH - 1 : 0] sreg [R - 1 : 0];

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < R; i++) begin
                    sreg[i] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            end
            //sreg[R - 1] <= '0;

        end
        else if (ready) begin
            sreg[0] <= in;
            for (int i = R-1; i > 0; i--) begin
                    sreg[i] <= sreg[i-1];
            end
        end
    end
	
assign last = sreg[0];
assign band = sreg[R - 2];
assign out = sreg[R - 1];

endmodule

`default_nettype wire