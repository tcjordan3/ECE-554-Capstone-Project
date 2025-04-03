module gameloop(clk, rst_n, refer, dance, score, ready_dance, ready_refer);

    input logic clk, rst_n, ready_dance, ready_refer;
    input logic [31:0] refer, dance;
    output logic [31:0] score;

    logic ready;

    logic [31:0] out_refer, out_dance, dtwscore;

    shift_register sregrefer(.in(refer), .clk(clk), .rst_n(rst_n), .out(out_refer), .ready_in(ready_refer), .ready_out(ready), .empty(empty_refer));
    shift_register sregdance(.in(dance), .clk(clk), .rst_n(rst_n), .out(out_dance), .ready_in(ready_dance), .ready_out(ready), .empty(empty_dance));
    dtw_accelerator idtw(.camera(out_dance), .refer(out_refer), .score(dtwscore), .clk(clk), .rst_n(rst_n), .ready(ready));

    assign ready = !(empty_dance || empty_refer);

    assign score = (1/(dtwscore + 1)) * 100;


endmodule