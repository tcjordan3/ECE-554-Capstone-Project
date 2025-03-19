module cordic #(parameter ITERATIONS = 20) (
    input logic clk,              // clock
    input logic rst_n,            // active-low reset
    input logic [4:0] k,          // iteration counter
    input logic [7:0] LUT_k,      // angle from the lookup table
    input logic [7:0] x,          // x coordinate
    input logic [7:0] y,          // y coordinate
    input logic start,            // high when a new iteration is beginning
    output logic [7:0] angle      // angle to compute
);

    logic [7:0] x_cordic;         // x coordinate to iterate upon
    logic [7:0] y_cordic;         // y coordinate to iterate upon
    logic [7:0] angle_begin;      // angle to iterate upon
    logic [7:0] angle_final;      // angle output by the CORDIC_ITERATION

    logic rdy;                    // high when angle is ready to be read

    // Initialize iteration parameters
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_cordic <= '0;
            y_cordic <= '0;
            angle_begin <= '0;
        end else if(x < 0) begin
            x_cordic <= -x;
            y_cordic <= -y;
            angle_begin <= 8'd180;
        end else begin
            x_cordic <= x;
            y_cordic <= y;
        end
    end

    cordic_iteration #(ITERATIONS) iCORDIC_ITERATION(.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x_cordic), .start(start),
                                                    .y(y_cordic), .angle_begin(angle_begin), .rdy(rdy), .angle_final(angle_final));

    // Output angle when finished iterating
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            angle <= '0;
        end else if(rdy) begin
            angle <= angle_final;
        end else begin
            angle <= '0;
        end
    end

endmodule