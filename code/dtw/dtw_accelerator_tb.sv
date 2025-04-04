`timescale 1ns/1ps

module dtw_accelerator_tb();
    parameter DATA_WIDTH = 32;
    parameter SIZE = 20; 
    parameter BAND_RADIUS = 4;
    parameter BAND_SIZE = 2*BAND_RADIUS+1;
    
    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] refer;
    reg [DATA_WIDTH-1:0] camera;
    wire [DATA_WIDTH-1:0] score;
    reg ready;
    
    reg [DATA_WIDTH-1:0] reference_seq [0:SIZE-1];
    reg [DATA_WIDTH-1:0] camera_seq [0:SIZE-1];
    
    integer i, j;
    integer test_count;
    reg test_passed;
    
    dtw_accelerator #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BAND_RADIUS(BAND_RADIUS),
        .BAND_SIZE(BAND_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .refer(camera), //This misnaming is on purpose
        .camera(refer),
        .score(score),
        .ready(ready)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    initial begin
        for (i = 0; i < SIZE; i = i + 1) begin
            reference_seq[i] = i * 2; 
            camera_seq[i] = (i * 2) + ((i % 3 == 0) ? 1 : 0); 
        end
    end
    
    initial begin
        rst_n = 0;
        ready = 0;
        refer = 0;
        camera = 0;
        test_count = 0;
        test_passed = 1;
        
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("Test Case 1: Starting DTW computation");
        test_count = test_count + 1;
        
        ready = 1;
        
        for (i = 0; i < SIZE; i = i + 1) begin
            refer = reference_seq[i];
            
            for (j = 0; j < SIZE; j = j + 1) begin
                camera = camera_seq[j];
                @(posedge clk); 
            end
        end
        
        repeat(20)@(posedge clk);
        
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 1: Received score = %d", score);
        end else begin
            $display("Test Case 1: Score is undefined or high impedance");
            test_passed = 0;
        end
        
        ready = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("Test Case 2: Testing with identical sequences");
        test_count = test_count + 1;
        
        for (i = 0; i < SIZE; i = i + 1) begin
            camera_seq[i] = reference_seq[i];
        end
        
        ready = 1;
        
        for (i = 0; i < SIZE; i = i + 1) begin
            refer = reference_seq[i];
            
            for (j = 0; j < SIZE; j = j + 1) begin
                camera = camera_seq[j];
                @(posedge clk); 
            end
        end

        ready = 0;
        
        repeat(20)@(posedge clk);
        ready = 0;
        
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 2: Received score = %d", score);
        end else begin
            $display("Test Case 2: Score is undefined or high impedance");
            test_passed = 0;
        end
        
        if (test_passed)
            $display("All %d tests PASSED", test_count);
        else
            $display("Some tests FAILED");
            
        $finish;
    end
    
    initial begin
        $dumpfile("dtw_accelerator_tb.vcd");
        $dumpvars(0, dtw_accelerator_tb);
    end

endmodule