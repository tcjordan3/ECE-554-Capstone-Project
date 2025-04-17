module happy_feet_tb();

    parameter IMG_WIDTH = 640;   // width of image
    parameter IMG_HEIGHT = 480;  // height of image
    parameter ANGLE_DEPTH = 10;  // bits needed to specify angle

    logic clk;      // clock
    logic rst_n;    // active-low reset
    
    // streamed-in pixel values
    logic signed [11:0] pixel_r;
    logic signed [11:0] pixel_g;
    logic signed [11:0] pixel_b;

    logic pixel_valid;                     // High when pixel data is valid
    logic [$clog2(IMG_WIDTH)-1:0] x;       // x coordinate of input pixel
    logic [$clog2(IMG_HEIGHT)-1:0] y;      // y coordinate of input pixel

    logic fill;                           // indicates when shift register should accept reference angles
    logic [ANGLE_DEPTH-1:0] refer_in_u;   // reference angle for cordic_dtw_u
    logic [ANGLE_DEPTH-1:0] refer_in_ll;  // reference angle for cordic_dtw_ll
    logic [ANGLE_DEPTH-1:0] refer_in_lr;  // reference angle for cordic_dtw_lr

    logic [31:0] score;   // score of frame sequence
    logic done;           // indicates final score is ready

    // Testbench variables
    static int error_count = 0;
    static int test_count = 0;
    static int refer_val_u, refer_val_ll, refer_val_lr;
    static int refer_inc_u, refer_inc_ll, refer_inc_lr;
    
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

    // module instantiation
    happy_feet #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ANGLE_DEPTH(ANGLE_DEPTH)
    ) iDUT (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_r(pixel_r),
        .pixel_g(pixel_g),
        .pixel_b(pixel_b),
        .pixel_valid(pixel_valid),
        .x(x),
        .y(y),
        .fill(fill),
        .refer_in_u(refer_in_u),
        .refer_in_ll(refer_in_ll),
        .refer_in_lr(refer_in_lr),
        .score(score),
        .done(done)
    );

    // clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    // Monitor for system outputs
    initial begin
        $display("=== Happy Feet Integration Test Starting ===");
        
        forever begin
            @(posedge done);
            $display("Test completed with score: %d", score);
            
            // Wait some cycles to ensure stability
            repeat(5) @(posedge clk);
            
            // Exit after test completes
            $finish;
        end
    end

    // Main test sequence
    initial begin
        // Initialize signals
        init_signals();
        
        // Apply reset
        apply_reset();
        
        $display("Step 1: Loading reference angles");
        
        // Initialize reference angles (following hier_tb approach)
        refer_val_u = 45;   // Starting angle
        refer_inc_u = 10;   // Increment
        
        refer_val_ll = 35;  // Starting angle
        refer_inc_ll = 5;   // Increment
        
        refer_val_lr = 25;  // Starting angle
        refer_inc_lr = 8;   // Increment
        
        // Load reference angles
        load_reference_angles();
        
        $display("Step 2: Processing image data");
        
        // Process an image frame with known clusters
        process_image_frame();
        
        // Wait for processing to complete
        wait(done);
        
        $display("=== Happy Feet Integration Test Complete ===");
    end

    // Initialize all signals
    task init_signals();
        rst_n = 0;
        pixel_valid = 0;
        pixel_r = 0;
        pixel_g = 0;
        pixel_b = 0;
        x = 0;
        y = 0;
        fill = 0;
        refer_in_u = 0;
        refer_in_ll = 0;
        refer_in_lr = 0;
    endtask

    // Apply reset sequence
    task apply_reset();
        @(posedge clk);
        rst_n = 0;
        repeat(2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        $display("Reset applied");
    endtask

    // Load reference angles into shift registers
    task load_reference_angles();
        @(posedge clk);
        fill = 1;
        
        // Following hier_tb approach - load 22 reference angles
        for (int i = 0; i < 22; i++) begin
            refer_in_u = refer_val_u;
            refer_in_ll = refer_val_ll;
            refer_in_lr = refer_val_lr;
            
            // Update reference angles for next cycle
            refer_val_u = refer_val_u + refer_inc_u;
            refer_val_ll = refer_val_ll + refer_inc_ll;
            refer_val_lr = refer_val_lr + refer_inc_lr;
            
            @(posedge clk);
            
            // Log loaded values every few entries
            if (i % 5 == 0) begin
                $display("Loading reference angles [%0d]: U=%0d, LL=%0d, LR=%0d", 
                         i, refer_in_u, refer_in_ll, refer_in_lr);
            end
        end
        
        fill = 0;
        @(posedge clk);
        $display("Reference angles loaded");
    endtask

    // Process full image frame
    task process_image_frame();
        automatic int color0_count = 0;
        automatic int color1_count = 0;
        automatic int color2_count = 0;
        automatic int x_sum0 = 0;
        automatic int y_sum0 = 0;
        automatic int x_sum1 = 0;
        automatic int y_sum1 = 0;
        automatic int x_sum2 = 0;
        automatic int y_sum2 = 0;
        automatic int avg_x0, avg_y0, avg_x1, avg_y1, avg_x2, avg_y2;
        
        // Define cluster positions (discrete clusters like cluster_tb)
        expected_x0 = IMG_WIDTH/4;
        expected_y0 = IMG_HEIGHT/4;
        expected_x1 = 3*IMG_WIDTH/4;
        expected_y1 = IMG_HEIGHT/4;
        expected_x2 = IMG_WIDTH/2;
        expected_y2 = 3*IMG_HEIGHT/4;
        
        $display("Processing image with clusters at:");
        $display("  Color 0: (%0d, %0d)", expected_x0, expected_y0);
        $display("  Color 1: (%0d, %0d)", expected_x1, expected_y1);
        $display("  Color 2: (%0d, %0d)", expected_x2, expected_y2);
        
        // Process entire frame
        for (int y_pos = 0; y_pos < IMG_HEIGHT; y_pos++) begin
            for (int x_pos = 0; x_pos < IMG_WIDTH; x_pos++) begin
                x = x_pos;
                y = y_pos;
                pixel_valid = 1;
                
                // Color 0: 4x4 grid at top-left quarter
                if (x_pos >= expected_x0-2 && x_pos <= expected_x0+1 && 
                    y_pos >= expected_y0-2 && y_pos <= expected_y0+1) begin
                    pixel_r = color_ref_r0;
                    pixel_g = color_ref_g0;
                    pixel_b = color_ref_b0;
                    color0_count++;
                    x_sum0 += x_pos;
                    y_sum0 += y_pos;
                end
                // Color 1: 4x4 grid at top-right quarter
                else if (x_pos >= expected_x1-2 && x_pos <= expected_x1+1 && 
                         y_pos >= expected_y1-2 && y_pos <= expected_y1+1) begin
                    pixel_r = color_ref_r1;
                    pixel_g = color_ref_g1;
                    pixel_b = color_ref_b1;
                    color1_count++;
                    x_sum1 += x_pos;
                    y_sum1 += y_pos;
                end
                // Color 2: 4x4 grid at bottom-center
                else if (x_pos >= expected_x2-2 && x_pos <= expected_x2+1 && 
                         y_pos >= expected_y2-2 && y_pos <= expected_y2+1) begin
                    pixel_r = color_ref_r2;
                    pixel_g = color_ref_g2;
                    pixel_b = color_ref_b2;
                    color2_count++;
                    x_sum2 += x_pos;
                    y_sum2 += y_pos;
                end
                // Background - different from any target color
                else begin
                    pixel_r = 300;
                    pixel_g = 300;
                    pixel_b = 300;
                end
                
                @(posedge clk);
                
                // Log progress during processing
                if (x_pos == 0 && y_pos % 100 == 0) begin
                    $display("Processing row %0d...", y_pos);
                end
            end
        end
        
        // Calculate expected centroids
        avg_x0 = (color0_count > 0) ? x_sum0/color0_count : 0;
        avg_y0 = (color0_count > 0) ? y_sum0/color0_count : 0;
        avg_x1 = (color1_count > 0) ? x_sum1/color1_count : 0;
        avg_y1 = (color1_count > 0) ? y_sum1/color1_count : 0;
        avg_x2 = (color2_count > 0) ? x_sum2/color2_count : 0;
        avg_y2 = (color2_count > 0) ? y_sum2/color2_count : 0;
        
        // End of frame
        x = IMG_WIDTH-1;
        y = IMG_HEIGHT-1;
        @(posedge clk);
        pixel_valid = 0;
        
        $display("Image processing complete");
        $display("Color 0: Found %0d pixels, expected centroid (%0d, %0d)", color0_count, avg_x0, avg_y0);
        $display("Color 1: Found %0d pixels, expected centroid (%0d, %0d)", color1_count, avg_x1, avg_y1);
        $display("Color 2: Found %0d pixels, expected centroid (%0d, %0d)", color2_count, avg_x2, avg_y2);
    endtask

    // Monitor and display internal signals during execution
    initial begin
        automatic int display_count = 0;
        
        // Monitor when clusters are detected
        forever begin
            @(posedge clk);
            if (iDUT.start && display_count == 0) begin
                display_count++;
                $display("Clusters detected:");
                $display("  Cluster 0: (%0d, %0d)", iDUT.x_0, iDUT.y_0);
                $display("  Cluster 1: (%0d, %0d)", iDUT.x_1, iDUT.y_1);
                $display("  Cluster 2: (%0d, %0d)", iDUT.x_2, iDUT.y_2);
            end
            
            // Monitor when label unit completes
            if (iDUT.cordic_start && display_count == 1) begin
                display_count++;
                $display("Label unit identified:");
                $display("  Upper: (%0d, %0d)", iDUT.x_u, iDUT.y_u);
                $display("  Lower Left: (%0d, %0d)", iDUT.x_ll, iDUT.y_ll);
                $display("  Lower Right: (%0d, %0d)", iDUT.x_lr, iDUT.y_lr);
            end
            
            // Monitor when angles are calculated
            if (iDUT.angle_rdy_u && iDUT.angle_rdy_ll && iDUT.angle_rdy_lr && display_count == 2) begin
                display_count++;
                $display("CORDIC angles calculated:");
                $display("  Upper angle: %0d", iDUT.angle_u);
                $display("  Lower Left angle: %0d", iDUT.angle_ll);
                $display("  Lower Right angle: %0d", iDUT.angle_lr);
            end
            
            // Monitor DTW scores
            if (iDUT.done_u && iDUT.done_ll && iDUT.done_lr && display_count == 3) begin
                display_count++;
                $display("DTW calculations complete:");
                $display("  Upper score: %0d", iDUT.score_u);
                $display("  Lower Left score: %0d", iDUT.score_ll);
                $display("  Lower Right score: %0d", iDUT.score_lr);
            end
        end
    end
endmodule
