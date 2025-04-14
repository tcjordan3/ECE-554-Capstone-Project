module label_unit_tb();
    // inputs/outputs
    logic clk;      // clock
    logic rst_n;    // active-low reset
    logic start;    // start signal

    // input coordinate pairs
    logic signed [7:0] x_0;
    logic signed [7:0] y_0;
    logic signed [7:0] x_1;
    logic signed [7:0] y_1;
    logic signed [7:0] x_2;
    logic signed [7:0] y_2;

    // identified coordinate pairings by label_unit
    logic signed [7:0] x_u;
    logic signed [7:0] y_u;
    logic signed [7:0] x_lr;
    logic signed [7:0] y_lr;
    logic signed [7:0] x_ll;
    logic signed [7:0] y_ll;

    // instantiate label_unit
    label_unit iDUT(.clk(clk), .rst_n(rst_n), .start(start),
                    .x_0(x_0), .y_0(y_0), .x_1(x_1), .y_1(y_1), .x_2(x_2), .y_2(y_2),
                    .x_u(x_u), .y_u(y_u), .x_lr(x_lr), .y_lr(y_lr), .x_ll(x_ll), .y_ll(y_ll));

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 50 MHz clock
    end

    // test logic
    initial begin
        // initialize signals
        start = 0;

        // apply reset
        #10 rst_n = 0;
        #10 rst_n = 1;

        // TEST #1: (-5, 0) -> ll, (0, 10) -> u, (2, 4) -> lr
        #20;
	    @(posedge clk);
        start = 1;

        x_0 = -5;
        y_0 = 0;
        x_1 = 0;
        y_1 = 10;
        x_2 = 2;
        y_2 = 4;
        
        @(posedge clk) begin
        start = 0;
	#5;
        $display("TEST #1: (-5, 0) -> ll, (0, 10) -> u, (2, 4) -> lr");
        $display("x_ll: %0d, y_ll: %0d, x_u: %0d, y_u: %0d, x_lr: %0d, y_lr: %0d",
                 x_ll, y_ll, x_u, y_u, x_lr, y_lr);
	end

        // TEST #2: (3, 0) -> ll, (0, 10) -> u, (6, 5) -> lr
        #20;
	    @(posedge clk);
        start = 1;

        x_0 = 0;
        y_0 = 10;
        x_1 = 6;
        y_1 = 5;
        x_2 = 3;
        y_2 = 0;
        
        @(posedge clk) begin
        start = 0;
	#5;
        $display("TEST #2: (3, 0) -> ll, (0, 10) -> u, (6, 5) -> lr");
        $display("x_ll: %0d, y_ll: %0d, x_u: %0d, y_u: %0d, x_lr: %0d, y_lr: %0d",
                 x_ll, y_ll, x_u, y_u, x_lr, y_lr);
	$stop;
	end
    end
endmodule