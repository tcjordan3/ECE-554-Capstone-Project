module CORDIC_tb();
    // inputs/outputs
    logic clk;            // clock
    logic rst_n;          // active-low reset
    logic [7:0] x;        // x-coordinate input
    logic [7:0] y;        // y-coordinate input
    logic start;          // indicates beginning of approximation
    logic [7:0] angle;    // approximated angle output

    // intermediate signals
    logic [4:0] k;        // iteration count
    logic [7:0] LUT_k;    // angle output of LUT

    // module instantiation
    counter iCOUNTER(.clk(clk), .rst_n(rst_n), .start(start), .k(k));

    LUT iLUT(.k(k), .LUT_k(LUT_k));

    cordic iCORDIC(.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x), .y(y), .start(start), .angle(angle));

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 50 MHz clock
    end

    // test logic
    initial begin
        // initialize signals
        start = 0;
        x = '0;
        y = '0;

        // apply reset
        #10 rst_n = 0;
        #10 rst_n = 1;

        // TEST #1: atan(17/3) ~ 80
        x = 8'd3;
        y = 8'd17;

        #20 start = 1;
        @(posedge clk);
        start = 0;

        wait(iCORDIC.rdy == 1);
        #20;
        $display("angle value: %0d", angle);
        $stop;
    end
endmodule