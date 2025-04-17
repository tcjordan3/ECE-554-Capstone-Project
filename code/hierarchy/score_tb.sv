`timescale 1ns/1ps

module score_tb;
    // Parameters
    parameter DATA_WIDTH = 8;  // Using smaller width for simulation
    parameter MAX_VALUE = (1 << DATA_WIDTH) - 1;
    
    // Inputs
    logic clk;
    logic rst_n;
    logic start;
    logic [DATA_WIDTH-1:0] score_u;
    logic [DATA_WIDTH-1:0] score_ll;
    logic [DATA_WIDTH-1:0] score_lr;
    
    // Outputs
    logic [DATA_WIDTH+3:0] score_out;
    logic done;
    
    // Instantiate the DUT (Device Under Test)
    score #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_VALUE(MAX_VALUE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .score_u(score_u),
        .score_ll(score_ll),
        .score_lr(score_lr),
        .score(score_out),
        .done(done)
    );
    
    // Clock generation
    always begin
        #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        start = 0;
        score_u = 0;
        score_ll = 0;
        score_lr = 0;
        
        // Reset sequence
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        
        // Test case 1: All scores are 0 (best possible DTW scores)
        @(posedge clk);
        score_u = 0;
        score_ll = 0;
        score_lr = 0;
        start = 1;
        @(posedge clk); 
        start = 0;
        
        wait(done);
        $display("Test Case 1:");
        $display("Inputs: score_u=%d, score_ll=%d, score_lr=%d", score_u, score_ll, score_lr);
        $display("Expected output: %d", 3*MAX_VALUE);
        $display("Actual output: %d", score_out);
        $display("Done signal: %b", done);
        
        // Test case 2: All scores are MAX_VALUE (worst possible DTW scores)
        repeat(4)@(posedge clk);
        score_u = MAX_VALUE;
        score_ll = MAX_VALUE;
        score_lr = MAX_VALUE;
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done);
        $display("Test Case 2:");
        $display("Inputs: score_u=%d, score_ll=%d, score_lr=%d", score_u, score_ll, score_lr);
        $display("Expected output: %d", 0);
        $display("Actual output: %d", score_out);
        $display("Done signal: %b", done);
        
        // Test case 3: Mixed scores
        repeat(4)@(posedge clk);
        score_u = MAX_VALUE/4;     // 75% of max score
        score_ll = MAX_VALUE/2;    // 50% of max score
        score_lr = 3*MAX_VALUE/4;  // 25% of max score
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done);
        $display("Test Case 3:");
        $display("Inputs: score_u=%d, score_ll=%d, score_lr=%d", score_u, score_ll, score_lr);
        $display("Expected output: %d", 384);
        $display("Actual output: %d", score_out);
        $display("Done signal: %b", done);
        
        // End simulation
       repeat(4)@(posedge clk);
       $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("At time %t: u=%d, ll=%d, lr=%d, out=%d, done=%b", 
                 $time, score_u, score_ll, score_lr, score_out, done);
    end
    
endmodule