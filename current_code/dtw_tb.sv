`timescale 1ns/1ps

module dtw_tb();
    parameter DATA_WIDTH = 32;
    parameter SIZE = 20; 
    parameter BAND_RADIUS = 4;
    parameter BAND_SIZE = 2*BAND_RADIUS+1;
    
    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] camera, out_camera;
    reg [DATA_WIDTH-1:0] refer, out_refer;
    wire [DATA_WIDTH-1:0] score;
    reg ready;
    
    reg [DATA_WIDTH-1:0] camera_seq [0:SIZE-1];
    reg [DATA_WIDTH-1:0] refer_seq [0:SIZE-1];
    
    integer i, j;
    integer test_count;
    reg test_passed;

    logic refer_ready, camera_ready, write_camera, write_refer;
    
    dtw #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .BAND_RADIUS(BAND_RADIUS),
        .BAND_SIZE(BAND_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .camera(out_camera), 
        .refer(out_refer),
        .score(score),
        .ready(ready),
        .ready_refer(refer_ready),
        .ready_camera(camera_ready),
        .done(done)
    );

    fifo fiforefer(.clk(clk), .rst_n(rst_n), .rden(refer_ready), .wren(write_refer), .i_data(refer), .o_data(out_refer), .full(), .empty(empty_refer));
    fifo fifocamera(.clk(clk), .rst_n(rst_n), .rden(camera_ready), .wren(write_camera), .i_data(camera), .o_data(out_camera), .full(), .empty(empty_camera));

    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    
    initial begin
        rst_n = 0;
        ready = 0;
        camera = 0;
        refer = 0;
        test_count = 0;
        test_passed = 1;
        write_camera <= 0;
        write_refer <= 0;
        
        @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("Test Case 1: Starting DTW computation");
        test_count = test_count + 1;
        
        write_camera <= 1;
        write_refer <= 1;
        for (i = 0; i < SIZE; i = i + 1) begin
            camera = (i + 1) * 2; 
            refer = ((i + 1) * 2) + ((i % 3 == 0) ? 1 : 0); 
            @(posedge clk);
        end
        write_camera <= 0;
        write_refer <= 0;
        
        ready <= 1;

        wait(done)@(posedge clk);
        
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 1: Received score = %d", score);
        end else begin
            $display("Test Case 1: Score is undefined or high imperefer");
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
        
        write_camera <= 1;
        write_refer <= 1;
        for (i = 0; i < SIZE; i = i + 1) begin
            camera = (i + 1) * 2; 
            refer = ((i + 1) * 2); 
            @(posedge clk);
        end
        write_camera <= 0;
        write_refer <= 0;
        
        ready <= 1;

        wait(done)@(posedge clk);
        
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 1: Received score = %d", score);
        end else begin
            $display("Test Case 1: Score is undefined or high imperefer");
            test_passed = 0;
        end
        
        if (score !== 'hx && score !== 'hz) begin
            $display("Test Case 2: Received score = %d", score);
        end else begin
            $display("Test Case 2: Score is undefined or high imperefer");
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
        $dumpvars(0, dtw_tb);
    end

endmodule