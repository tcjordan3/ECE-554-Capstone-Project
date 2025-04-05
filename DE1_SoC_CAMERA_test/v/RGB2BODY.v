module RGB2BODY(
    input  [10:0] iX_Cont,
    input  [10:0] iY_Cont,
    input  [11:0] in_R,
    input  [11:0] in_G,
    input  [11:0] in_B,
    input         iCLK,
    input         iRST,
    output reg [10:0] left_hand_x,
    output reg [10:0] left_hand_y,
    output reg [10:0] head_x,
    output reg [10:0] head_y,
    output reg [10:0] right_hand_x,
    output reg [10:0] right_hand_y,
    output reg        coordinates_ready
);

// Threshold parameters (adjust as needed)
parameter THRESHOLD_HIGH = 12'd3000;
parameter THRESHOLD_LOW  = 12'd1500;

// Detection flags to latch coordinates once per frame
reg found_left;
reg found_head;
reg found_right;

always @(posedge iCLK or negedge iRST) begin
    if (!iRST) begin
        left_hand_x       <= 0;
        left_hand_y       <= 0;
        head_x            <= 0;
        head_y            <= 0;
        right_hand_x      <= 0;
        right_hand_y      <= 0;
        found_left        <= 0;
        found_head        <= 0;
        found_right       <= 0;
        coordinates_ready <= 0;
    end else begin
        // Reset detection flags at the start of a new frame
        if ((iX_Cont == 0) && (iY_Cont == 0)) begin
            found_left        <= 0;
            found_head        <= 0;
            found_right       <= 0;
            coordinates_ready <= 0;  // Clear coordinates_ready at frame start
        end

        // Neon Pink detection (for left hand):
        // Red and Blue above THRESHOLD_HIGH and Green below THRESHOLD_LOW.
        if (!found_left && (in_R > THRESHOLD_HIGH) && (in_B > THRESHOLD_HIGH) && (in_G < THRESHOLD_LOW)) begin
            left_hand_x <= iX_Cont;
            left_hand_y <= iY_Cont;
            found_left  <= 1;
        end

        // Bright Green detection (for head):
        // Green above THRESHOLD_HIGH and Red and Blue below THRESHOLD_LOW.
        if (!found_head && (in_G > THRESHOLD_HIGH) && (in_R < THRESHOLD_LOW) && (in_B < THRESHOLD_LOW)) begin
            head_x <= iX_Cont;
            head_y <= iY_Cont;
            found_head <= 1;
        end

        // Bright Yellow detection (for right hand):
        // Red and Green above THRESHOLD_HIGH and Blue below THRESHOLD_LOW.
        if (!found_right && (in_R > THRESHOLD_HIGH) && (in_G > THRESHOLD_HIGH) && (in_B < THRESHOLD_LOW)) begin
            right_hand_x <= iX_Cont;
            right_hand_y <= iY_Cont;
            found_right  <= 1;
        end

        // Assert coordinates_ready when all body parts have been found.
        if (found_left && found_head && found_right)
            coordinates_ready <= 1;
        else
            coordinates_ready <= 0;
    end
end

endmodule
