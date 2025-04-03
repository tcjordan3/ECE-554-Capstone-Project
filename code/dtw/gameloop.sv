module gameloop(clk, rst_n, refer, dance, score, ready_dance, ready_refer);

    input clk, rst_n, ready_dance, ready_refer;
    input refer, dance;
    output score;

    logic ready;

    shift_register sregrefer(.in(refer), .clk(clk), .rst_n(rst_n), .out(out_refer), .ready_in(ready_refer), .ready_out(ready), .empty(empty_refer));
    shift_register sregdance(.in(dance), .clk(clk), .rst_n(rst_n), .out(out_dance), .ready_in(ready_dance), .ready_out(ready), .empty(empty_dance));
    dtw idtw(.camera(out_dance), .refer(out_refer), .score(dtwscore), .clk(clk), .rst_n(rst_n), .ready(ready));

    assign ready = empty_dance || empty_refer;


endmodule