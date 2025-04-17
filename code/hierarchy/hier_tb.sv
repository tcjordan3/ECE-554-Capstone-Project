module hier_tb();

    parameter COORD_DEPTH = 8;  // bits to specify coordinate
    parameter ANGLE_DEPTH = 32; // bits to specify angle

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

    logic [31:0] score;
    logic done;

    integer x;          // initial x coordinate
    integer y;          // initial y coordinate
    integer k;          // counter
    integer refer_val;  // value of reference angle
    integer test_case;  // test case number
    
    // Arrays for test coordinate paths
    integer test_x[3:0][21:0];
    integer test_y[3:0][21:0];
    integer test_refstart[3:0];
    integer test_refinc[3:0];

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
        // Initialize test data
        // Test Case 0: Original test - decreasing x, increasing y
        for (int i = 0; i < 22; i++) begin
            test_x[0][i] = 70 - (i * 10);
            test_y[0][i] = 90 + (i * 10);
        end
        test_refstart[0] = 45;
        test_refinc[0] = 10;
        
        // Test Case 1: Increasing x, increasing y (diagonal movement)
        for (int i = 0; i < 22; i++) begin
            test_x[1][i] = 20 + (i * 5);
            test_y[1][i] = 20 + (i * 5);
        end
        test_refstart[1] = 35;
        test_refinc[1] = 1;
        
        // Test Case 2: Decreasing x, decreasing y (inverse diagonal)
        for (int i = 0; i < 22; i++) begin
            test_x[2][i] = 100 - (i * 4);
            test_y[2][i] = 100 - (i * 4);
        end
        test_refstart[2] = 35;
        test_refinc[2] = 1;
        
        // Test Case 3: Circular-like path (predefined points)
        test_x[3][0] = 60; test_x[3][1] = 70; test_x[3][2] = 80; test_x[3][3] = 85; test_x[3][4] = 90;
        test_x[3][5] = 90; test_x[3][6] = 85; test_x[3][7] = 80; test_x[3][8] = 70; test_x[3][9] = 60;
        test_x[3][10] = 50; test_x[3][11] = 40; test_x[3][12] = 30; test_x[3][13] = 20; test_x[3][14] = 15;
        test_x[3][15] = 10; test_x[3][16] = 10; test_x[3][17] = 15; test_x[3][18] = 20; test_x[3][19] = 30;
        test_x[3][20] = 40; test_x[3][21] = 50;
        
        test_y[3][0] = 50; test_y[3][1] = 55; test_y[3][2] = 60; test_y[3][3] = 70; test_y[3][4] = 80;
        test_y[3][5] = 90; test_y[3][6] = 100; test_y[3][7] = 110; test_y[3][8] = 115; test_y[3][9] = 120;
        test_y[3][10] = 120; test_y[3][11] = 120; test_y[3][12] = 115; test_y[3][13] = 110; test_y[3][14] = 100;
        test_y[3][15] = 90; test_y[3][16] = 80; test_y[3][17] = 70; test_y[3][18] = 60; test_y[3][19] = 55;
        test_y[3][20] = 50; test_y[3][21] = 50;
        
        test_refstart[3] = 90;
        test_refinc[3] = 5;

        // initialize signals
        start = 0;
        fill = 0;
        x_0 = 0;
        y_0 = 0;
        x_1 = 0;
        y_1 = 0;
        x_2 = 0;
        y_2 = 0;
        
        // Run all test cases
        for (test_case = 0; test_case < 4; test_case++) begin
            // apply reset
            @(posedge clk);
            rst_n = 0;
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            
            $display("\n=== Running Test Case %0d ===", test_case + 1);
            
            // Load reference angles
            refer_val = test_refstart[test_case];
            @(posedge clk);
            fill = 1;
            
            repeat (22) begin
                refer = refer_val;
                #1;
                
                // update reference angle
                refer_val = refer_val + test_refinc[test_case];
                @(posedge clk);
            end
            fill = 0;
            
            // Run coordinate test
            k = 0;
            
            repeat (22) begin
                x_0 = test_x[test_case][k];
                y_0 = test_y[test_case][k];
                
                repeat (22) begin
                    @(posedge clk);
                end
                start = 1;
                
                @(posedge clk) begin
                    start = 0;
                    #1;
                    $display("Test %0d - Coordinate pair #%0d: (%0d, %0d)", 
                             test_case + 1, k + 1, x_0, y_0);
                end
                
                wait(DUT.iCORDICUPPER.angle_rdy == 1);
                #1;
                $display("CORDIC output angle: %0d", DUT.iCORDICUPPER.angle);
                
                // update counter
                k = k + 1;
            end
            
            wait(done == 1);
            #1;
            $display("Test %0d - DTW score: %0d", test_case + 1, score);
        end
        
        $display("\n=== All tests completed ===");
        $stop;
    end
endmodule