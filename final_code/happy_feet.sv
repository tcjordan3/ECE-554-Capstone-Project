module happy_feet #(
    parameter IMG_WIDTH = 640,  // height of image
    parameter IMG_HEIGHT = 480, // width of image
    parameter ANGLE_DEPTH = 10,  // bits needed to specify angle
    parameter FRAME_COUNT = 500, // number of reference frames
    parameter OUTPUT_WIDTH = 32
)(
    input logic clk,    // clock
    input logic rst_n,  // active-low reset

    // streamed-in pixel values
    input logic signed [11:0] pixel_r,
    input logic signed [11:0] pixel_g,
    input logic signed [11:0] pixel_b,

    input logic en, // enable signal

    input logic pixel_valid,                  // High when pixel data is valid
    input logic [$clog2(IMG_WIDTH)-1:0] x,    // x coordinate of input pixel
    input logic [$clog2(IMG_HEIGHT)-1:0] y,   // y coordinate of input pixel

    input logic fill,                           // indicates when shift register should accept reference angles
    input logic [ANGLE_DEPTH-1:0] refer_in_u,   // reference angle for cordic_dtw_u
    input logic [ANGLE_DEPTH-1:0] refer_in_ll,  // reference angle for cordic_dtw_ll
    input logic [ANGLE_DEPTH-1:0] refer_in_lr,  // reference angle for cordic_dtw_lr

    output logic [OUTPUT_WIDTH - 1:0] score,   // score of frame sequence
    output logic done,            // indicates final score is ready

    output logic oMatch0,
    output logic oMatch1,
    output logic oMatch2,
    output logic oDTW_RDY_U,
    output logic [10:0] frame_end_count

);

    localparam COORD_DEPTH = $clog2(IMG_WIDTH); // bits needed to specify coordinate

    logic start;    // indicates system can begin processing coordinates



    // cluster coordinate outputs
    logic signed [COORD_DEPTH-1:0] x_0;
    logic signed [COORD_DEPTH-1:0] y_0;
    logic signed [COORD_DEPTH-1:0] x_1;
    logic signed [COORD_DEPTH-1:0] y_1;
    logic signed [COORD_DEPTH-1:0] x_2;
    logic signed [COORD_DEPTH-1:0] y_2;

    // label_unit coordinate outputs
    logic signed [COORD_DEPTH-1:0] x_u;
    logic signed [COORD_DEPTH-1:0] y_u;
    logic signed [COORD_DEPTH-1:0] x_ll;
    logic signed [COORD_DEPTH-1:0] y_ll;
    logic signed [COORD_DEPTH-1:0] x_lr;
    logic signed [COORD_DEPTH-1:0] y_lr;

    logic start_flopped;    // flopped start signal
    logic cordic_start;     // indicates when cordic can begin processing coordinates

    logic [4:0] k;                  // iteration count
    logic [ANGLE_DEPTH-1:0] LUT_k;  // LUT angle output

    // cordic-dtw_u signals
    logic [ANGLE_DEPTH-1:0] angle_u;
    logic angle_rdy_u;
    logic [ANGLE_DEPTH-1:0] refer_u;
    logic ready_refer_u;
    logic camera_ready_u;
    logic [ANGLE_DEPTH-1:0] camera_u;
    logic full_u;
    logic dtw_ready_u;
    logic [31:0] score_u;
    logic done_u;

    // cordic-dtw_ll signals
    logic [ANGLE_DEPTH-1:0] angle_ll;
    logic angle_rdy_ll;
    logic [ANGLE_DEPTH-1:0] refer_ll;
    logic ready_refer_ll;
    logic camera_ready_ll;
    logic [ANGLE_DEPTH-1:0] camera_ll;
    logic full_ll;
    logic dtw_ready_ll;
    logic [31:0] score_ll;
    logic done_ll;

    // cordic-dtw_lr signals
    logic [ANGLE_DEPTH-1:0] angle_lr;
    logic angle_rdy_lr;
    logic [ANGLE_DEPTH-1:0] refer_lr;
    logic ready_refer_lr;
    logic camera_ready_lr;
    logic [ANGLE_DEPTH-1:0] camera_lr;
    logic full_lr;
    logic dtw_ready_lr;
    logic [31:0] score_lr;
    logic done_lr;

    // module instantiation
    cluster iCLUSTER(.clk(clk), .rst_n(rst_n), .pixel_r(pixel_r), .pixel_g(pixel_g), .pixel_b(pixel_b),
                     .pixel_valid(pixel_valid), .x(x), .y(y), .en(en),
                    .x_0(x_0), .y_0(y_0), .x_1(x_1), .y_1(y_1), .x_2(x_2), .y_2(y_2), .done(start), .oMatch0(oMatch0), .oMatch1(oMatch1), .oMatch2(oMatch2), .frame_end_count(frame_end_count));

    label_unit #(.COORD_DEPTH(COORD_DEPTH)) iLABEL
                (.clk(clk), .rst_n(rst_n), .start(start),
                 .x_0(x_0), .y_0(y_0), .x_1(x_1), .y_1(y_1), .x_2(x_2), .y_2(y_2),
                 .x_u(x_u), .y_u(y_u), .x_ll(x_ll), .y_ll(y_ll), .x_lr(x_lr), .y_lr(y_lr));

    // flop start signal to account for processing time of label_unit
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
	        start_flopped <= 0;
            cordic_start <= 0;
        end else begin
	        start_flopped <= start;
            cordic_start <= start_flopped;
        end
    end

    counter iCOUNTER(.clk(clk), .rst_n(rst_n), .start(cordic_start), .k(k));
    LUT iLUT(.k(k), .LUT_k(LUT_k));

    // three cordic-dtw pairs
    cordic #(.COORD_DEPTH(COORD_DEPTH)) iCORDIC_U
    (.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x_u), .y(y_u), .start(cordic_start),
     .angle(angle_u), .angle_rdy(angle_rdy_u));

    shifter #(.ANGLE_DEPTH(ANGLE_DEPTH), .NUM_VALUES(FRAME_COUNT)) iSHIFTER_U
    (.clk(clk), .rst_n(rst_n), .fill(fill), .angle_in(refer_in_u), .angle_out(refer_u), .ready(ready_refer_u));
    fifo  #(.DEPTH(FRAME_COUNT), .DATA_WIDTH(ANGLE_DEPTH)) iFIFO_U
    (.clk(clk), .rst_n(rst_n), .rden(camera_ready_u), .wren(angle_rdy_u),
     .i_data(angle_u), .o_data(camera_u), .full(full_u), .empty(dtw_ready_u));

    dtw #(
        .DATA_WIDTH(ANGLE_DEPTH + 1),
        .SIZE(FRAME_COUNT),
        .BAND_RADIUS(4),
        .BAND_SIZE(4)
    ) iDTW_U (
        .clk(clk),
        .rst_n(rst_n),
        .camera(camera_u), 
        .refer(refer_u),
        .score(score_u),
        .ready(!dtw_ready_u),
        .ready_refer(ready_refer_u),
        .ready_camera(camera_ready_u),
        .done(done_u)
    );

    cordic #(.COORD_DEPTH(COORD_DEPTH)) iCORDIC_LL
    (.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x_ll), .y(y_ll), .start(cordic_start),
     .angle(angle_ll), .angle_rdy(angle_rdy_ll));

    shifter #(.ANGLE_DEPTH(ANGLE_DEPTH), .NUM_VALUES(FRAME_COUNT)) iSHIFTER_LL
    (.clk(clk), .rst_n(rst_n), .fill(fill), .angle_in(refer_in_ll), .angle_out(refer_ll), .ready(ready_refer_ll));
    fifo  #(.DEPTH(FRAME_COUNT), .DATA_WIDTH(ANGLE_DEPTH)) iFIFO_LL
    (.clk(clk), .rst_n(rst_n), .rden(camera_ready_ll), .wren(angle_rdy_ll),
     .i_data(angle_ll), .o_data(camera_ll), .full(full_ll), .empty(dtw_ready_ll));

    dtw #(
        .DATA_WIDTH(ANGLE_DEPTH + 1),
        .SIZE(FRAME_COUNT),
        .BAND_RADIUS(4),
        .BAND_SIZE(4)
    ) iDTW_LL (
        .clk(clk),
        .rst_n(rst_n),
        .camera(camera_ll), 
        .refer(refer_ll),
        .score(score_ll),
        .ready(!dtw_ready_ll),
        .ready_refer(ready_refer_ll),
        .ready_camera(camera_ready_ll),
        .done(done_ll)
    );

    cordic #(.COORD_DEPTH(COORD_DEPTH)) iCORDIC_LR
    (.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x_lr), .y(y_lr), .start(cordic_start),
     .angle(angle_lr), .angle_rdy(angle_rdy_lr));

    shifter #(.ANGLE_DEPTH(ANGLE_DEPTH), .NUM_VALUES(FRAME_COUNT)) iSHIFTER_LR
    (.clk(clk), .rst_n(rst_n), .fill(fill), .angle_in(refer_in_lr), .angle_out(refer_lr), .ready(ready_refer_lr));
    fifo  #(.DEPTH(FRAME_COUNT), .DATA_WIDTH(ANGLE_DEPTH)) iFIFO_LR
    (.clk(clk), .rst_n(rst_n), .rden(camera_ready_lr), .wren(angle_rdy_lr),
     .i_data(angle_lr), .o_data(camera_lr), .full(full_lr), .empty(dtw_ready_lr));

    dtw #(
        .DATA_WIDTH(ANGLE_DEPTH + 1),
        .SIZE(FRAME_COUNT),
        .BAND_RADIUS(4),
        .BAND_SIZE(4)
    ) iDTW_LR (
        .clk(clk),
        .rst_n(rst_n),
        .camera(camera_lr), 
        .refer(refer_lr),
        .score(score_lr),
        .ready(!dtw_ready_lr),
        .ready_refer(ready_refer_lr),
        .ready_camera(camera_ready_lr),
        .done(done_lr)
    );

    score #(.ANGLE_DEPTH(31), .DATA_WIDTH(OUTPUT_WIDTH)) iSCORE
    (.clk(clk),  .rst_n(rst_n), .start(done_u & done_ll & done_lr),
     .score_u(score_u), .score_ll(score_ll), .score_lr(score_lr), .score(score), .done(done));


logic test_dtw;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    test_dtw <= 1'b0;
  else if (dtw_ready_u)
    test_dtw <= 1'b1;
end

assign oDTW_RDY_U = test_dtw;

    
endmodule