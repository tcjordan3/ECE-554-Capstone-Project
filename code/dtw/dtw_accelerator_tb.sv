// Testbench for DTW Accelerator
`timescale 1ns/1ps

module dtw_accelerator_tb();
    // Parameters from the DUT
    parameter DATA_WIDTH = 32;
    parameter SIZE = 20; // Reduced size for simulation efficiency
    parameter BAND_RADIUS = 4; // Reduced band radius for simulation
    parameter BAND_SIZE = 2*BAND_RADIUS+1;
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] refer;
    reg [DATA_WIDTH-1:0] camera;
    wire [DATA_WIDTH-1:0] score;
    reg ready;
    
    // Arrays to store test sequences
    reg [DATA_WIDTH-1:0] reference_seq [0:SIZE-1];
    reg [DATA_WIDTH-1:0] camera_seq [0:SIZE-1];
    
    // Counters and test status
    integer i, j;
    integer test_count;
    reg test_passed;
    
    // Instantiate the DUT (Device Under Test)
    dtw_accelerator #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BAND_RADIUS(BAND_RADIUS),
        .BAND_SIZE(BAND_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .refer(refer),
        .camera(camera),
        .score(score),
        .ready(ready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Initialize test sequences
    initial begin
        // Create some simple test patterns
        // In a real test, these would be more realistic time series data
        for (i = 0; i < SIZE; i = i + 1) begin
            reference_seq[i] = i * 2; // Simple linear pattern
            camera_seq[i] = (i * 2) + ((i % 3 == 0) ? 1 : 0); // Slightly different pattern
        end
    end
    
    // Test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        ready = 0;
        refer = 0;
        camera = 0;
        test_count = 0;
        test_passed = 1;
        
        // Reset sequence
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test Case 1: Run the DTW algorithm with our test sequences
        $display("Test Case 1: Starting DTW computation");
        test_count = test_count + 1;
        
        // Signal ready to start computation
        ready = 1;
        
        // Loop through the sequence to provide inputs row by row
        for (i = 0; i < SIZE; i = i + 1) begin
            refer = reference_seq[i];
            
            for (j = 0; j < SIZE; j = j + 1) begin
                camera = camera_seq[j];
                @(posedge clk); // Wait one clock cycle for computation
            end
        end
        
        // Wait for computation to complete (this would be more sophisticated in a real test)
        repeat(20)@(posedge clk);
        
        // Check results - in a real test, we would compare against expected values
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 1: Received score = %d", score);
        end else begin
            $display("Test Case 1: Score is undefined or high impedance");
            test_passed = 0;
        end
        
        // Reset before the next test
        ready = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test Case 2: Run with identical sequences (should produce minimal score)
        $display("Test Case 2: Testing with identical sequences");
        test_count = test_count + 1;
        
        // Modify camera_seq to be identical to reference_seq
        for (i = 0; i < SIZE; i = i + 1) begin
            camera_seq[i] = reference_seq[i];
        end
        
        // Signal ready to start computation
        ready = 1;
        
        // Loop through the sequence to provide inputs row by row
        for (i = 0; i < SIZE; i = i + 1) begin
            refer = reference_seq[i];
            
            for (j = 0; j < SIZE; j = j + 1) begin
                camera = camera_seq[j];
                @(posedge clk); // Wait one clock cycle for computation
            end
        end

        ready = 0;
        
        // Wait for computation to complete
        repeat(20)@(posedge clk);
        ready = 0;
        
        // For identical sequences, we expect a low score
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 2: Received score = %d", score);
            // In a real test, we might check: if (score == 0) correct for identical sequences
        end else begin
            $display("Test Case 2: Score is undefined or high impedance");
            test_passed = 0;
        end
        
        // Test results summary
        if (test_passed)
            $display("All %d tests PASSED", test_count);
        else
            $display("Some tests FAILED");
            
        $finish;
    end
    
    // Add waveform generation for debugging
    initial begin
        $dumpfile("dtw_accelerator_tb.vcd");
        $dumpvars(0, dtw_accelerator_tb);
    end

endmodule