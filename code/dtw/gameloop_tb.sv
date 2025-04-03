`timescale 1ns/1ps

module gameloop_tb();
    logic clk;
    logic rst_n;
    logic [31:0] refer;
    logic [31:0] dance;
    logic ready_dance;
    logic ready_refer;
    logic [31:0] score;
    
    gameloop dut(
        .clk(clk),
        .rst_n(rst_n),
        .refer(refer),
        .dance(dance),
        .score(score),
        .ready_dance(ready_dance),
        .ready_refer(ready_refer)
    );
    
    always begin
        #5 clk = ~clk;
    end
    
    initial begin
        clk = 0;
        rst_n = 0;
        refer = 0;
        dance = 0;
        ready_dance = 0;
        ready_refer = 0;
        
        $display("--- Starting Gameloop Module Testbench ---");
        @(posedge clk)
        @(negedge clk);
        rst_n = 1;
        
        $display("Test Case 1: Basic functionality test");
        
        @(posedge clk);
        ready_refer = 1;
        ready_dance = 1;
        
        @(posedge clk) refer = 1;
        @(posedge clk) refer = 6;
        @(posedge clk) refer = 9;
        @(posedge clk) refer = 7;
        @(posedge clk) refer = 9;
        
        @(posedge clk) dance = 2;
        @(posedge clk) dance = 3;
        @(posedge clk) dance = 7;
        @(posedge clk) dance = 9;
        @(posedge clk) dance = 8;

        ready_refer = 0;
        ready_dance = 0;
        
        repeat(100) @(posedge clk);
        
        $display("Score for similar patterns: %d", score);
        
        $display("Test Case 2: Different patterns");
        
        @(posedge clk) rst_n = 0;
        repeat(3) @(posedge clk);
        @(posedge clk) rst_n = 1;
        
        @(posedge clk);
        ready_refer = 1;
        ready_dance = 1;
        
        @(posedge clk) refer = 3;
        @(posedge clk) refer = 4;
        @(posedge clk) refer = 5;
        @(posedge clk) refer = 7;
        @(posedge clk) refer = 1;
        
        @(posedge clk) dance = 4;
        @(posedge clk) dance = 7;
        @(posedge clk) dance = 9;
        @(posedge clk) dance = 3;
        @(posedge clk) dance = 9;

        ready_refer = 0;
        ready_dance = 0;
        
        repeat(100) @(posedge clk);
        
        $display("Score for different patterns: %d", score);
        
        $display("Test Case 3: Test ready signal functionality");
        
        @(posedge clk) rst_n = 0;
        repeat(3) @(posedge clk);
        @(posedge clk) rst_n = 1;
        
        @(posedge clk);
        ready_refer = 0;
        ready_dance = 0;
        
        @(posedge clk) refer = 1;
        @(posedge clk) dance = 5;
        
        repeat(3) @(posedge clk);
        
        @(posedge clk) ready_refer = 1;
        repeat(3) @(posedge clk);
        
        @(posedge clk) ready_dance = 1;
        
        @(posedge clk) refer = 7;
        @(posedge clk) refer = 5;
        @(posedge clk) refer = 8;
        
        @(posedge clk) dance = 2;
        @(posedge clk) dance = 8;
        @(posedge clk) dance = 5;
        
        repeat(10) @(posedge clk);
        
        $display("Score after ready signals test: %d", score);
        
        repeat(5) @(posedge clk);
        $display("--- Gameloop Module Testbench Completed ---");
        $finish;
    end
    
    initial begin
        $monitor("Time=%0t: ready_refer=%b, ready_dance=%b, refer=%b, dance=%b, score=%d",
                 $time, ready_refer, ready_dance, refer, dance, score);
    end
    
endmodule