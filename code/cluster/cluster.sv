module cluster #(
    parameter IMG_WIDTH = 640,  // width of image
    parameter IMG_HEIGHT = 480  // height of image
)(
    input logic clk,    // clock
    input logic rst_n,  // active-low reset

    // streamed-in pixel values
    input logic signed [11:0] pixel_r,
    input logic signed [11:0] pixel_g,
    input logic signed [11:0] pixel_b,

    input logic pixel_valid,                  // High when pixel data is valid
    input logic [$clog2(IMG_WIDTH)-1:0] x,    // x coordinate of input pixel
    input logic [$clog2(IMG_HEIGHT)-1:0] y,   // y coordinate of input pixel

    // coordinate outputs
    output logic [$clog2(IMG_WIDTH)-1:0] x_0,
    output logic [$clog2(IMG_HEIGHT)-1:0] y_0,
    output logic [$clog2(IMG_WIDTH)-1:0] x_1,
    output logic [$clog2(IMG_HEIGHT)-1:0] y_1,
    output logic [$clog2(IMG_WIDTH)-1:0] x_2,
    output logic [$clog2(IMG_HEIGHT)-1:0] y_2,
    
    output logic done // indicates clusters have been identified
);

    localparam tol = 16;    // pixel tolerance

    // color 0 expected RGB
    localparam color_ref_r0 = 50;
    localparam color_ref_g0 = 100;
    localparam color_ref_b0 = 150;

    // color 1 expected RGB
    localparam color_ref_r1 = 450;
    localparam color_ref_g1 = 500;
    localparam color_ref_b1 = 550;

    // color 2 expected RGB
    localparam color_ref_r2 = 900;
    localparam color_ref_g2 = 950;
    localparam color_ref_b2 = 1000;

    // color counters
    logic [4:0] k_color_0;
    logic [4:0] k_color_1;
    logic [4:0] k_color_2;

    // accumulation signals
    logic [31:0] sum_x_0;
    logic [31:0] sum_y_0;
    logic [31:0] sum_x_1;
    logic [31:0] sum_y_1;
    logic [31:0] sum_x_2;
    logic [31:0] sum_y_2;

    // indicates color match
    logic match_0;
    logic match_1;
    logic match_2;

    // indicates the end of a frame
    logic frame_end;

    assign frame_end = (x == IMG_WIDTH-1) && (y == IMG_HEIGHT-1);

    // Detect match to appropriate color
    assign match_0 = pixel_valid &&
                     ((pixel_r - color_ref_r0) >= 0 ? (pixel_r - color_ref_r0) : -(pixel_r - color_ref_r0)) <= tol &&
                     ((pixel_g - color_ref_g0) >= 0 ? (pixel_g - color_ref_g0) : -(pixel_g - color_ref_g0)) <= tol &&
                     ((pixel_b - color_ref_b0) >= 0 ? (pixel_b - color_ref_b0) : -(pixel_b - color_ref_b0)) <= tol;

    assign match_1 = pixel_valid &&
                     ((pixel_r - color_ref_r1) >= 0 ? (pixel_r - color_ref_r1) : -(pixel_r - color_ref_r1)) <= tol &&
                     ((pixel_g - color_ref_g1) >= 0 ? (pixel_g - color_ref_g1) : -(pixel_g - color_ref_g1)) <= tol &&
                     ((pixel_b - color_ref_b1) >= 0 ? (pixel_b - color_ref_b1) : -(pixel_b - color_ref_b1)) <= tol;

    assign match_2 = pixel_valid &&
                     ((pixel_r - color_ref_r2) >= 0 ? (pixel_r - color_ref_r2) : -(pixel_r - color_ref_r2)) <= tol &&
                     ((pixel_g - color_ref_g2) >= 0 ? (pixel_g - color_ref_g2) : -(pixel_g - color_ref_g2)) <= tol &&
                     ((pixel_b - color_ref_b2) >= 0 ? (pixel_b - color_ref_b2) : -(pixel_b - color_ref_b2)) <= tol;

    // Control registers
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            k_color_0 <= '0;
            sum_x_0 <= '0;
            sum_y_0 <= '0;
        end else if(frame_end) begin
            k_color_0 <= '0;
            sum_x_0 <= '0;
            sum_y_0 <= '0;
        end else if(k_color_0 == 5'd16) begin
            // done sampling for color 0
        end else if(match_0) begin
            k_color_0 <= k_color_0 + 1;
            sum_x_0 <= sum_x_0 + x;
            sum_y_0 <= sum_y_0 + y;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            k_color_1 <= '0;
            sum_x_1 <= '0;
            sum_y_1 <= '0;
        end else if(frame_end) begin
            k_color_1 <= '0;
            sum_x_1 <= '0;
            sum_y_1 <= '0;
        end else if(k_color_1 == 5'd16) begin
            // done sampling for color 1
        end else if(match_1) begin
            k_color_1 <= k_color_1 + 1;
            sum_x_1 <= sum_x_1 + x;
            sum_y_1 <= sum_y_1 + y;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            k_color_2 <= '0;
            sum_x_2 <= '0;
            sum_y_2 <= '0;
        end else if(frame_end) begin
            k_color_2 <= '0;
            sum_x_2 <= '0;
            sum_y_2 <= '0;
        end else if(k_color_2 == 5'd16) begin
            // done sampling for color 2
        end else if(match_2) begin
            k_color_2 <= k_color_2 + 1;
            sum_x_2 <= sum_x_2 + x;
            sum_y_2 <= sum_y_2 + y;
        end
    end

    // output registers
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_0 <= '0;
            y_0 <= '0;
        end else if(frame_end) begin
            x_0 <= sum_x_0 >> 4;
            y_0 <= sum_y_0 >> 4;
        end else begin
            x_0 <= '0;
            y_0 <= '0;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_1 <= '0;
            y_1 <= '0;
        end else if(frame_end) begin
            x_1 <= sum_x_1 >> 4;
            y_1 <= sum_y_1 >> 4;
        end else begin
            x_1 <= '0;
            y_1 <= '0;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_2 <= '0;
            y_2 <= '0;
        end else if(frame_end) begin
            x_2 <= sum_x_2 >> 4;
            y_2 <= sum_y_2 >> 4;
        end else begin
            x_2 <= '0;
            y_2 <= '0;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            done <= 0;
        end else if(frame_end) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule