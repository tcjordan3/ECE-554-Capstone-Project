module gameloop(clk, rst_n, refer, camera, score, ready_camera, ready_refer);

    input logic clk, rst_n, ready_camera, ready_refer;
    input logic [31:0] refer, camera;
    output logic [31:0] score;

    logic ready;

    logic [31:0] out_refer, out_camera, dtwscore;

    //shift_register sregrefer(.in(refer), .clk(clk), .rst_n(rst_n), .out(out_refer), .ready_in(ready_refer), .ready_out(ready), .empty(empty_refer));
    //shift_register sregcamera(.in(camera), .clk(clk), .rst_n(rst_n), .out(out_camera), .ready_in(ready_camera), .ready_out(ready), .empty(empty_camera));
    dtw_accelerator idtw(.camera(out_camera), .refer(out_refer), .score(dtwscore), .clk(clk), .rst_n(rst_n), .ready(ready));
    fifo fiforefer(.clk(clk), .rst_n(rst_n), .rden(ready), .wren(ready_refer), .i_data(refer), .o_data(out_refer), .full(), .empty(empty_refer));
    fifo fifocamera(.clk(clk), .rst_n(rst_n), .rden(ready), .wren(ready_camera), .i_data(camera), .o_data(out_camera), .full(), .empty(empty_camera));

    assign ready = !(empty_camera || empty_refer);

    assign score = dtwscore;


endmodule