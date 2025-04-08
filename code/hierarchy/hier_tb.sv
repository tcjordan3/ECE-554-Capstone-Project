module hier_tb();

    parameter COORD_DEPTH = 8;  // bits to specify coordinate
    parameter ANGLE_DEPTH = 10; // bits to specify angle

    logic clk;      // clock
    logic rst_n;    // active-low reset
    logic start;    // indicates when system should initiate
    logic fill;     // indicates when to fill shift register

    // coordinate inputs
    logic signed [COORD_DEPTH-1:0] x_0;
    logic signed [COORD_DEPTH-1:0] y_0;
    logic signed [COORD_DEPTH-1:0] x_1;
    logic signed [COORD_DEPTH-1:0] y_1;
    logic signed [COORD_DEPTH-1:0] x_2;
    logic signed [COORD_DEPTH-1:0] y_2;

    logic signed [ANGLE_DEPTH-1:0] refer;  // reference angles to be fed to shift register

    logic [ANGLE_DEPTH-1:0] score;
    logic done;

    integer x;          // initial x coordinate
    integer y;          // initial y coordinate
    integer k;          // counter
    integer refer_val;  // value of reference angle

    // module instantiation
    hier #(
        .COORD_DEPTH(COORD_DEPTH),
        .ANGLE_DEPTH(ANGLE_DEPTH)
    ) DUT(.clk(clk), .rst_n(rst_n), .start(start), .fill(fill), .refer_in(refer),
           .x_0(x_0), .y_0(y_0), .x_1(x_1), .y_1(y_1), .x_2(x_2), .y_2(y_2), .score(score), .done(done));

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 50 MHz clock
    end

    // test logic
    initial begin
        // initialize signals
        start = 0;
        x_0 = 0;
        y_0 = 0;
        x_1 = 0;
        y_1 = 0;
        x_2 = 0;
        y_2 = 0;

        // apply reset
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;

        refer_val = 45;

        // store reference angles
        @(posedge clk);
        fill = 1;

        repeat (20) begin
	    refer = refer_val;
            #1;

            // update reference angle
            refer_val = refer_val  + 10;
            @(posedge clk);
        end
        fill = 0;

        // Test coordinates: (70, 90), (60, 100), (50, 110)
        x = 70;
        y = 90;
        k = 1;

        repeat (20) begin
            x_0 = x;
            y_0 = y;

            repeat (3) begin
		@(posedge clk);
	    end
            start = 1;

            @(posedge clk) begin
                start = 0;
                #1;
                $display("coordinate pair #%0d: (%0d, %0d)", k, x, y);
                $display("Retrieved coordinates: (%0d,  %0d)", DUT.iLABEL.x_u, DUT.iLABEL.y_u);
            end

            wait(DUT.iCORDICUPPER.angle_rdy == 1);
            #1;
            $display("cordic output: %0d", DUT.iCORDICUPPER.angle);

            // update variables
            x = x - 10;
            y = y + 10;
            k = k + 1;
        end

        wait(done == 1);
        #1;
        $display("Expected DTW score: 12. Actual DTW score: %0d", score);
        $stop;
    end
endmodule