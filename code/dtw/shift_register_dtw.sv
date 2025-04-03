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
            sreg[0] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[1] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[2] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[3] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[4] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[5] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[6] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[7] <= {{4'b0000}, {(WIDTH - 4){1'b1}}};
            sreg[8] <= '0;

        end
        else if (ready) begin
            sreg[0] <= in;
            sreg[1] <= sreg[0];
            sreg[2] <= sreg[1];
            sreg[3] <= sreg[2];
            sreg[4] <= sreg[3];
            sreg[5] <= sreg[4];
            sreg[6] <= sreg[5];
            sreg[7] <= sreg[6];
            sreg[8] <= sreg[7];
        end
    end
	
assign last = sreg[0];
assign band = sreg[R - 2];
assign out = sreg[R - 1];

endmodule

`default_nettype wire