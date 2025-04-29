module happy_feet_tb();

    parameter IMG_WIDTH = 640;   // width of image
    parameter IMG_HEIGHT = 480;  // height of image
    parameter ANGLE_DEPTH = 10;  // bits needed to specify angle
    parameter NUM_FRAMES = 22;   // number of frames to process for DTW to output a score

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

    // Positions for each frame to simulate motion
    logic [$clog2(IMG_WIDTH)-1:0] positions_x0[NUM_FRAMES];
    logic [$clog2(IMG_HEIGHT)-1:0] positions_y0[NUM_FRAMES];
    logic [$clog2(IMG_WIDTH)-1:0] positions_x1[NUM_FRAMES];
    logic [$clog2(IMG_HEIGHT)-1:0] positions_y1[NUM_FRAMES];
    logic [$clog2(IMG_WIDTH)-1:0] positions_x2[NUM_FRAMES];
    logic [$clog2(IMG_HEIGHT)-1:0] positions_y2[NUM_FRAMES];

    // Current frame being processed
    int current_frame;

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
        
        @(posedge done);
        $display("Test completed with final score: %d", score);
        
        // Wait some cycles to ensure stability
        repeat(5) @(posedge clk);
        
        // Exit after test completes
        $stop;
    end

    // Main test sequence
    initial begin
        // Initialize signals and frame positions
        init_signals();
        init_frame_positions();
        
        // Apply reset
        apply_reset();
        
        $display("Step 1: Loading reference angles");
        
        // Initialize reference angles (following hier_tb approach)
        refer_val_u = 45;   // Starting angle
        refer_inc_u = 1;    // Increment
        
        refer_val_ll = 35;  // Starting angle
        refer_inc_ll = 2;   // Increment
        
        refer_val_lr = 25;  // Starting angle
        refer_inc_lr = 3;   // Increment
        
        // Load reference angles
        load_reference_angles();
        
        $display("Step 2: Processing %0d image frames to simulate motion", NUM_FRAMES);
        
        // Process all frames sequentially
        for (current_frame = 0; current_frame < NUM_FRAMES; current_frame++) begin
            process_image_frame(current_frame);
            
            if (current_frame < NUM_FRAMES-1) begin
                // After each frame except the last, wait for start signal and immediately start next frame
                @(posedge iDUT.start);
                $display("  Start signal detected for frame %0d, immediately beginning next frame", current_frame);
            end else begin
                // For the last frame, wait for the CORDIC angles to be ready
                // This ensures the final (22nd) angle is properly processed
                wait(iDUT.angle_rdy_u && iDUT.angle_rdy_ll && iDUT.angle_rdy_lr);
                $display("  Final frame %0d angles processed, waiting for DTW computation", current_frame);
            end
        end
        
        // Wait for final processing to complete
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
        current_frame = 0;
    endtask

    // Initialize positions for each frame to simulate motion
    task init_frame_positions();
        // Base position
        automatic int base_x0 = IMG_WIDTH/4;
        automatic int base_y0 = IMG_HEIGHT/4;
        automatic int base_x1 = 3*IMG_WIDTH/4;
        automatic int base_y1 = IMG_HEIGHT/4; 
        automatic int base_x2 = IMG_WIDTH/2;
        automatic int base_y2 = 3*IMG_HEIGHT/4;
        
        // Set initial positions
        positions_x0[0] = base_x0;
        positions_y0[0] = base_y0;
        positions_x1[0] = base_x1;
        positions_y1[0] = base_y1;
        positions_x2[0] = base_x2;
        positions_y2[0] = base_y2;
        
        // Generate motion pattern for all frames
        for (int i = 1; i < NUM_FRAMES; i++) begin
            // Simple motion pattern: circular movement
            positions_x0[i] = base_x0 + $rtoi(15.0 * $cos(i * 2 * 3.14159 / 22));
            positions_y0[i] = base_y0 + $rtoi(15.0 * $sin(i * 2 * 3.14159 / 22));
            
            positions_x1[i] = base_x1 + $rtoi(12.0 * $cos(i * 2 * 3.14159 / 22 + 0.5));
            positions_y1[i] = base_y1 + $rtoi(12.0 * $sin(i * 2 * 3.14159 / 22 + 0.5));
            
            positions_x2[i] = base_x2 + $rtoi(10.0 * $cos(i * 2 * 3.14159 / 22 + 1.0));
            positions_y2[i] = base_y2 + $rtoi(10.0 * $sin(i * 2 * 3.14159 / 22 + 1.0));
        end
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

    // Process a single image frame
    task process_image_frame(int frame_idx);
        automatic int color0_count = 0;
        automatic int color1_count = 0;
        automatic int color2_count = 0;
        automatic int x_sum0 = 0;
        automatic int y_sum0 = 0;
        automatic int x_sum1 = 0;
        automatic int y_sum1 = 0;
        automatic int x_sum2 = 0;
        automatic int y_sum2 = 0;

        // Calculate centroids for verification
        automatic int avg_x0 = (color0_count > 0) ? x_sum0/color0_count : 0;
        automatic int avg_y0 = (color0_count > 0) ? y_sum0/color0_count : 0;
        automatic int avg_x1 = (color1_count > 0) ? x_sum1/color1_count : 0;
        automatic int avg_y1 = (color1_count > 0) ? y_sum1/color1_count : 0;
        automatic int avg_x2 = (color2_count > 0) ? x_sum2/color2_count : 0;
        automatic int avg_y2 = (color2_count > 0) ? y_sum2/color2_count : 0;
        
        // Get current positions for this frame
        automatic logic [$clog2(IMG_WIDTH)-1:0] current_x0 = positions_x0[frame_idx];
        automatic logic [$clog2(IMG_HEIGHT)-1:0] current_y0 = positions_y0[frame_idx];
        automatic logic [$clog2(IMG_WIDTH)-1:0] current_x1 = positions_x1[frame_idx];
        automatic logic [$clog2(IMG_HEIGHT)-1:0] current_y1 = positions_y1[frame_idx];
        automatic logic [$clog2(IMG_WIDTH)-1:0] current_x2 = positions_x2[frame_idx];
        automatic logic [$clog2(IMG_HEIGHT)-1:0] current_y2 = positions_y2[frame_idx];
        
        $display("Processing frame %0d of %0d", frame_idx+1, NUM_FRAMES);
        $display("  Color 0: (%0d, %0d)", current_x0, current_y0);
        $display("  Color 1: (%0d, %0d)", current_x1, current_y1);
        $display("  Color 2: (%0d, %0d)", current_x2, current_y2);
        
        // Reset x,y to (0,0) for the start of each frame
        x = 0;
        y = 0;
        pixel_valid = 1;
        @(posedge clk);
        
        // Process entire frame pixel by pixel
        for (int y_pos = 0; y_pos < IMG_HEIGHT; y_pos++) begin
            for (int x_pos = 0; x_pos < IMG_WIDTH; x_pos++) begin
                x = x_pos;
                y = y_pos;
                
                // Color 0: 4x4 grid at current upper position
                if (x_pos >= current_x0-2 && x_pos <= current_x0+1 && 
                    y_pos >= current_y0-2 && y_pos <= current_y0+1) begin
                    pixel_r = color_ref_r0;
                    pixel_g = color_ref_g0;
                    pixel_b = color_ref_b0;
                    color0_count++;
                    x_sum0 += x_pos;
                    y_sum0 += y_pos;
                end
                // Color 1: 4x4 grid at current lower left position
                else if (x_pos >= current_x1-2 && x_pos <= current_x1+1 && 
                         y_pos >= current_y1-2 && y_pos <= current_y1+1) begin
                    pixel_r = color_ref_r1;
                    pixel_g = color_ref_g1;
                    pixel_b = color_ref_b1;
                    color1_count++;
                    x_sum1 += x_pos;
                    y_sum1 += y_pos;
                end
                // Color 2: 4x4 grid at current lower right position
                else if (x_pos >= current_x2-2 && x_pos <= current_x2+1 && 
                         y_pos >= current_y2-2 && y_pos <= current_y2+1) begin
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
                
                // Log progress sparingly
                if (x_pos == 0 && y_pos % 120 == 0) begin
                    $display("  Processing row %0d...", y_pos);
                end
            end
        end
        
        $display("Frame %0d complete - centroids: (%0d,%0d), (%0d,%0d), (%0d,%0d)", 
            frame_idx, avg_x0, avg_y0, avg_x1, avg_y1, avg_x2, avg_y2);

        // Reset x and y to prevent lingering 'start' signal on last frame
        x = 0;
        y = 0;
        // @(posedge clk);
    endtask

    // Monitor and display internal signals during execution
    initial begin
        int frame_monitor = -1;
        logic previous_start = 0;
        
        forever begin
            @(posedge clk);
            
            // Detect rising edge of start signal to track frame boundaries
            if (iDUT.start && !previous_start) begin
                frame_monitor++;
                $display("\nFrame %0d processed, detected start signal:", frame_monitor);
                $display("  Clusters detected:");
                $display("    Cluster 0: (%0d, %0d)", iDUT.x_0, iDUT.y_0);
                $display("    Cluster 1: (%0d, %0d)", iDUT.x_1, iDUT.y_1);
                $display("    Cluster 2: (%0d, %0d)", iDUT.x_2, iDUT.y_2);
            end
            previous_start = iDUT.start;
            
            // Monitor when start_flopped signal is asserted
            if (iDUT.start_flopped && !iDUT.start) begin
                $display("  Label unit identified:");
                $display("    Upper: (%0d, %0d)", iDUT.x_u, iDUT.y_u);
                $display("    Lower Left: (%0d, %0d)", iDUT.x_ll, iDUT.y_ll);
                $display("    Lower Right: (%0d, %0d)", iDUT.x_lr, iDUT.y_lr);
            end
            
            // Monitor angles when they're all ready
            if (iDUT.angle_rdy_u && iDUT.angle_rdy_ll && iDUT.angle_rdy_lr) begin
                $display("  CORDIC angles:");
                $display("    Upper: %0d", iDUT.angle_u);
                $display("    Lower Left: %0d", iDUT.angle_ll);
                $display("    Lower Right: %0d", iDUT.angle_lr);
            end
            
            // Monitor DTW scores when they're all available
            if (iDUT.done_u && iDUT.done_ll && iDUT.done_lr) begin
                $display("  DTW scores:");
                $display("    Upper: %0d", iDUT.score_u);
                $display("    Lower Left: %0d", iDUT.score_ll);
                $display("    Lower Right: %0d", iDUT.score_lr);
            end
        end
    end
endmodule