module hier #(
    parameter ANGLE_DEPTH,          // bits needed to specify angle
    parameter COORD_DEPTH           // bits needed to specify coordinate
)(
    input logic clk,                // clock
    input logic rst_n,              // active-low reset
    input logic start,              // indicates when system should initiate

    input logic fill,		    	           // indicates when shift register should accept reference angles
    input logic [ANGLE_DEPTH-1:0] refer_in,    // reference angle

    // coordinate inputs to label_unit
    input logic signed [COORD_DEPTH-1:0] x_0,
    input logic signed [COORD_DEPTH-1:0] y_0,
    input logic signed [COORD_DEPTH-1:0] x_1,
    input logic signed [COORD_DEPTH-1:0] y_1,
    input logic signed [COORD_DEPTH-1:0] x_2,
    input logic signed [COORD_DEPTH-1:0] y_2,

    output logic [ANGLE_DEPTH-1:0] score,             // score output by DTW
    output logic done                                 // indicates score is ready
);

    // intermediate signals
    // label_unit
    logic [COORD_DEPTH-1:0] x_u;
    logic [COORD_DEPTH-1:0] y_u;
    logic [COORD_DEPTH-1:0] x_ll;
    logic [COORD_DEPTH-1:0] y_ll;
    logic [COORD_DEPTH-1:0] x_lr;
    logic [COORD_DEPTH-1:0] y_lr;

    // counter/LUT/cordic
    logic [COORD_DEPTH-1:0] x_u_cordic;
    logic [COORD_DEPTH-1:0] y_u_cordic;
    logic [4:0] k;
    logic [ANGLE_DEPTH-1:0] LUT_k;
    logic start_flopped;    // flopped start signal
    logic cordic_start;     // start signal for cordic unit
    logic [ANGLE_DEPTH-1:0] angle_cordic;

    // dtw
    logic [ANGLE_DEPTH-1:0] camera;
    logic [ANGLE_DEPTH-1:0] refer;

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

    // module instantiation
    label_unit iLABEL(.clk(clk), .rst_n(rst_n), .start(start),
                      .x_0(x_0), .y_0(y_0), .x_1(x_1), .y_1(y_1), .x_2(x_2), .y_2(y_2),
                      .x_u(x_u), .y_u(y_u), .x_ll(x_ll), .y_ll(y_ll), .x_lr(x_lr), .y_lr(y_lr));

    counter iCOUNTER(.clk(clk), .rst_n(rst_n), .start(cordic_start), .k(k));
    LUT iLUT(.k(k), .LUT_k(LUT_k));
    // for now we will only test one cordic-dtw pair
    cordic iCORDICUPPER(.clk(clk), .rst_n(rst_n), .k(k), .LUT_k(LUT_k), .x(x_u), .y(y_u), .start(cordic_start),
                   .angle(angle_cordic), .angle_rdy(angle_rdy));

    // buffer cordic output
    always @(posedge clk, negedge rst_n) begin
	if(~rst_n) begin
	    camera <= '0;
	end else if(angle_rdy) begin
	    camera <= angle_cordic;
	end
    end

    shifter iSHIFTERREFERENCE(.clk(clk), .rst_n(rst_n), .fill(fill), .angle_in(refer_in), .angle_out(refer));

    dtw_accelerator iDTW(.clk(clk), .rst_n(rst_n), .refer(refer), .camera(camera), .score(score), .ready(angle_rdy), .done(done));
endmodule