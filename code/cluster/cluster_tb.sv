module cluster_tb #(
    parameter IMG_WIDTH = 640,  // width of image
    parameter IMG_HEIGHT = 480  // height of image
);

    logic clk;      // clock
    logic rst_n;    // active-low reset

    // streamed-in pixel values
    logic signed [11:0] pixel_r;
    logic signed [11:0] pixel_g;
    logic signed [11:0] pixel_b;

    logic pixel_valid;                      // high when pixel data is valid
    logic [$clog2(IMG_WIDTH)-1:0] x;        // x coordinate of input pixel
    logic [$clog2(IMG_HEIGHT)-1:0] y;       // y coordinate of input pixel

    // coordinate outputs
    logic [$clog2(IMG_WIDTH)-1:0] x_0;
    logic [$clog2(IMG_HEIGHT)-1:0] y_0;
    logic [$clog2(IMG_WIDTH)-1:0] x_1;
    logic [$clog2(IMG_HEIGHT)-1:0] y_1;
    logic [$clog2(IMG_WIDTH)-1:0] x_2;
    logic [$clog2(IMG_HEIGHT)-1:0] y_2;

    logic done; // indicates clusters have been identified

    // module instantiation
    cluster #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) iDUT (
        .clk(clk), 
        .rst_n(rst_n), 
        .pixel_r(pixel_r), 
        .pixel_g(pixel_g), 
        .pixel_b(pixel_b),
        .pixel_valid(pixel_valid), 
        .x(x), 
        .y(y), 
        .x_0(x_0), 
        .y_0(y_0), 
        .x_1(x_1), 
        .y_1(y_1), 
        .x_2(x_2), 
        .y_2(y_2),
        .done(done)
    );

    // Predefined color values from the cluster module
    localparam color_ref_r0 = 50;
    localparam color_ref_g0 = 100;
    localparam color_ref_b0 = 150;
    
    localparam color_ref_r1 = 450;
    localparam color_ref_g1 = 500; 
    localparam color_ref_b1 = 550;
    
    localparam color_ref_r2 = 900;
    localparam color_ref_g2 = 950;
    localparam color_ref_b2 = 1000;

    // Expected positions for test verification
    logic [$clog2(IMG_WIDTH)-1:0] expected_x0, expected_x1, expected_x2;
    logic [$clog2(IMG_HEIGHT)-1:0] expected_y0, expected_y1, expected_y2;

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // test logic
    initial begin
        $display("Starting cluster module tests");
        
        // Initialize signals
        rst_n = 0;
        pixel_valid = 0;
        pixel_r = 0;
        pixel_g = 0;
        pixel_b = 0;
        x = 0;
        y = 0;
        
        // Apply reset
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Run discrete clusters test
        test_discrete_clusters();
        
        // Test scattered clusters
        test_scattered_clusters();
        
        // Test with noise
        test_with_noise();
        
        $display("All tests completed");
        $finish;
    end

    // Test with discrete pixel clusters (exactly 16 pixels per color)
    task test_discrete_clusters();
        $display("\nRunning discrete clusters test");
        
        // Reset
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Coordinates for cluster centers
        expected_x0 = IMG_WIDTH/4;
        expected_y0 = IMG_HEIGHT/4;
        expected_x1 = 3*IMG_WIDTH/4;
        expected_y1 = IMG_HEIGHT/4;
        expected_x2 = IMG_WIDTH/2;
        expected_y2 = 3*IMG_HEIGHT/4;
        
        // Create exact 4x4 grid for each color (16 pixels each)
        // Process entire frame with most pixels as background
        for (int y_pos = 0; y_pos < IMG_HEIGHT; y_pos++) begin
            for (int x_pos = 0; x_pos < IMG_WIDTH; x_pos++) begin
                @(posedge clk);
                x = x_pos;
                y = y_pos;
                pixel_valid = 1;
                
                // Color 0: 4x4 grid at top-left quarter
                if (x_pos >= expected_x0-2 && x_pos <= expected_x0+1 && 
                    y_pos >= expected_y0-2 && y_pos <= expected_y0+1) begin
                    pixel_r = color_ref_r0;
                    pixel_g = color_ref_g0;
                    pixel_b = color_ref_b0;
                end
                // Color 1: 4x4 grid at top-right quarter
                else if (x_pos >= expected_x1-2 && x_pos <= expected_x1+1 && y_pos >= expected_y1-2 && y_pos <= expected_y1+1) begin
                    pixel_r = color_ref_r1;
                    pixel_g = color_ref_g1;
                    pixel_b = color_ref_b1;
                end
                // Color 2: 4x4 grid at bottom-center
                else if (x_pos >= expected_x2-2 && x_pos <= expected_x2+1 && y_pos >= expected_y2-2 && y_pos <= expected_y2+1) begin
                    pixel_r = color_ref_r2;
                    pixel_g = color_ref_g2;
                    pixel_b = color_ref_b2;
                end
                // Background - different from any target color
                else begin
                    pixel_r = 300;
                    pixel_g = 300;
                    pixel_b = 300;
                end
            end
        end
        
        // End of frame
        x = IMG_WIDTH-1;
        y = IMG_HEIGHT-1;
        @(posedge clk);
        pixel_valid = 0;
        
        // Wait for processing
        wait(done);
        
        // Check results
        $display("Discrete clusters test results:");
        $display("Color 0: (%d, %d) - Expected: (%d, %d)", x_0, y_0, expected_x0-0.5, expected_y0-0.5);
        $display("Color 1: (%d, %d) - Expected: (%d, %d)", x_1, y_1, expected_x1-0.5, expected_y1-0.5);
        $display("Color 2: (%d, %d) - Expected: (%d, %d)", x_2, y_2, expected_x2-0.5, expected_y2-0.5);
    endtask

    // Test with scattered pixels (16 pixels spread in regions)
    task test_scattered_clusters();
        automatic int color0_count = 0;
        automatic int color1_count = 0;
        automatic int color2_count = 0;
        automatic int x_sum0 = 0;
        automatic int y_sum0 = 0;
        automatic int x_sum1 = 0;
        automatic int y_sum1 = 0;
        automatic int x_sum2 = 0;
        automatic int y_sum2 = 0;
        
        $display("\nRunning scattered clusters test");
        
        // Reset
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Create three scattered clusters
        for (int y_pos = 0; y_pos < IMG_HEIGHT; y_pos++) begin
            for (int x_pos = 0; x_pos < IMG_WIDTH; x_pos++) begin
                @(posedge clk);
                x = x_pos;
                y = y_pos;
                pixel_valid = 1;
                
                // Color 0: scatter in top-left quadrant
                if (x_pos < IMG_WIDTH/2 && y_pos < IMG_HEIGHT/2 && 
                    (x_pos + y_pos) % 12 == 0 && color0_count < 16) begin
                    pixel_r = color_ref_r0;
                    pixel_g = color_ref_g0;
                    pixel_b = color_ref_b0;
                    color0_count++;
                    x_sum0 += x_pos;
                    y_sum0 += y_pos;
                end
                // Color 1: scatter in top-right quadrant
                else if (x_pos >= IMG_WIDTH/2 && y_pos < IMG_HEIGHT/2 && (x_pos + y_pos) % 12 == 1 && color1_count < 16) begin
                    pixel_r = color_ref_r1;
                    pixel_g = color_ref_g1;
                    pixel_b = color_ref_b1;
                    color1_count++;
                    x_sum1 += x_pos;
                    y_sum1 += y_pos;
                end
                // Color 2: scatter in bottom half
                else if (y_pos >= IMG_HEIGHT/2 && (x_pos + y_pos) % 12 == 2 && color2_count < 16) begin
                    pixel_r = color_ref_r2;
                    pixel_g = color_ref_g2;
                    pixel_b = color_ref_b2;
                    color2_count++;
                    x_sum2 += x_pos;
                    y_sum2 += y_pos;
                end
                // Background
                else begin
                    pixel_r = 300;
                    pixel_g = 300;
                    pixel_b = 300;
                end
            end
        end
        
        // Calculate expected centroids
        expected_x0 = (color0_count > 0) ? x_sum0/color0_count : 0;
        expected_y0 = (color0_count > 0) ? y_sum0/color0_count : 0;
        expected_x1 = (color1_count > 0) ? x_sum1/color1_count : 0;
        expected_y1 = (color1_count > 0) ? y_sum1/color1_count : 0;
        expected_x2 = (color2_count > 0) ? x_sum2/color2_count : 0;
        expected_y2 = (color2_count > 0) ? y_sum2/color2_count : 0;
        
        // End of frame
        x = IMG_WIDTH-1;
        y = IMG_HEIGHT-1;
        @(posedge clk);
        pixel_valid = 0;
        
        // Wait for processing
        wait(done);
        
        // Check results
        $display("Scattered clusters test results:");
        $display("Color 0: Found %d pixels, centroid at (%d, %d) - Expected: (%d, %d)", 
                 color0_count, x_0, y_0, expected_x0, expected_y0);
        $display("Color 1: Found %d pixels, centroid at (%d, %d) - Expected: (%d, %d)", 
                 color1_count, x_1, y_1, expected_x1, expected_y1);
        $display("Color 2: Found %d pixels, centroid at (%d, %d) - Expected: (%d, %d)", 
                 color2_count, x_2, y_2, expected_x2, expected_y2);
    endtask

    // Test with noise
    task test_with_noise();
        automatic int noise_r;
        automatic int noise_g;
        automatic int noise_b;
        automatic int color0_count = 0;
        automatic int color1_count = 0;
        automatic int color2_count = 0;
        automatic int x_sum0 = 0;
        automatic int y_sum0 = 0;
        automatic int x_sum1 = 0;
        automatic int y_sum1 = 0;
        automatic int x_sum2 = 0;
        automatic int y_sum2 = 0;

        $display("\nRunning test with noise");
        
        // Reset
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Create small clusters with noise
        for (int y_pos = 0; y_pos < IMG_HEIGHT; y_pos++) begin
            for (int x_pos = 0; x_pos < IMG_WIDTH; x_pos++) begin
                noise_r = $urandom_range(10) - 5;
                noise_g = $urandom_range(10) - 5;
                noise_b = $urandom_range(10) - 5;
                
                @(posedge clk);
                x = x_pos;
                y = y_pos;
                pixel_valid = 1;
                
                // Color 0: Small cluster in top-left quadrant
                if (((x_pos-IMG_WIDTH/6)**2 + (y_pos-IMG_HEIGHT/6)**2) < 100 && color0_count < 16) begin
                    pixel_r = color_ref_r0 + noise_r;
                    pixel_g = color_ref_g0 + noise_g;
                    pixel_b = color_ref_b0 + noise_b;
                    color0_count++;
                    x_sum0 += x_pos;
                    y_sum0 += y_pos;
                end
                // Color 1: Small cluster in top-right quadrant
                else if (((x_pos-5*IMG_WIDTH/6)**2 + (y_pos-IMG_HEIGHT/6)**2) < 100 && color1_count < 16) begin
                    pixel_r = color_ref_r1 + noise_r;
                    pixel_g = color_ref_g1 + noise_g;
                    pixel_b = color_ref_b1 + noise_b;
                    color1_count++;
                    x_sum1 += x_pos;
                    y_sum1 += y_pos;
                end
                // Color 2: Small cluster in bottom-middle
                else if (((x_pos-IMG_WIDTH/2)**2 + (y_pos-5*IMG_HEIGHT/6)**2) < 100 && color2_count < 16) begin
                    pixel_r = color_ref_r2 + noise_r;
                    pixel_g = color_ref_g2 + noise_g;
                    pixel_b = color_ref_b2 + noise_b;
                    color2_count++;
                    x_sum2 += x_pos;
                    y_sum2 += y_pos;
                end
                // Background
                else begin
                    pixel_r = 300 + noise_r;
                    pixel_g = 300 + noise_g;
                    pixel_b = 300 + noise_b;
                end
            end
        end
        
        // Calculate expected centroids
        expected_x0 = (color0_count > 0) ? x_sum0/color0_count : 0;
        expected_y0 = (color0_count > 0) ? y_sum0/color0_count : 0;
        expected_x1 = (color1_count > 0) ? x_sum1/color1_count : 0;
        expected_y1 = (color1_count > 0) ? y_sum1/color1_count : 0;
        expected_x2 = (color2_count > 0) ? x_sum2/color2_count : 0;
        expected_y2 = (color2_count > 0) ? y_sum2/color2_count : 0;
        
        // End of frame
        x = IMG_WIDTH-1;
        y = IMG_HEIGHT-1;
        @(posedge clk);
        pixel_valid = 0;
        
        // Wait for processing
        wait(done);
        
        // Check results
        $display("Noise test results:");
        $display("Color 0: Found %d pixels, centroid at (%d, %d) - Expected near (%d, %d)", 
                 color0_count, x_0, y_0, expected_x0, expected_y0);
        $display("Color 1: Found %d pixels, centroid at (%d, %d) - Expected near (%d, %d)", 
                 color1_count, x_1, y_1, expected_x1, expected_y1);
        $display("Color 2: Found %d pixels, centroid at (%d, %d) - Expected near (%d, %d)", 
                 color2_count, x_2, y_2, expected_x2, expected_y2);
    endtask
endmodule
