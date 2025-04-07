module shifter #(
    parameter ANGLE_DEPTH = 10     // bits needed to specify angle
)(
    input logic clk,                             // clock
    input logic rst_n,                           // active-low reset
    input logic fill,                            // indicates the shift register should store reference angles
    input logic [ANGLE_DEPTH-1:0] angle_in,      // reference angle input to shift register
    output logic [ANGLE_DEPTH-1:0] angle_out     // reference angle output by shift register
);

    logic [ANGLE_DEPTH-1:0] shift_reg [0:2];    // shift register
    logic [1:0] ptr;                            // pointer

    // shift register control logic
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            ptr <= 2'b10;
            angle_out <= '0;
            shift_reg[0] = '0;
            shift_reg[1] = '0;
            shift_reg[2] = '0;
        end else if(fill) begin
            shift_reg[ptr] <= angle_in;
            if(ptr != 2'b00) begin
                ptr <= ptr - 1;
            end
        end else begin
            angle_out <= shift_reg[2];
            shift_reg[2] <= shift_reg[1];
            shift_reg[1] <= shift_reg[0];
	    shift_reg[0] <= '0;
            if(ptr != 2'b10) begin
                ptr <= ptr + 1; 
            end
        end
    end

endmodule