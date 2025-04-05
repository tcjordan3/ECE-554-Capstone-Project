
// --------------------------------------------------------------------
// Overlay Module
// This module takes the original pixel color output from RAW2RGB (orig_R, orig_G, orig_B)
// and the current pixel coordinates (provided by X_Cont and Y_Cont).
// If the current pixel falls within a 50x50 square (±25 pixels) centered on any of the 
// detected body part coordinates (provided by RGB2BODY), then the pixel color is overridden
// with the corresponding neon color.
// --------------------------------------------------------------------
module Overlay(
    input  [11:0] orig_R,
    input  [11:0] orig_G,
    input  [11:0] orig_B,
    input  [10:0] current_x,  // Use lower 11 bits of X_Cont
    input  [10:0] current_y,  // Use lower 11 bits of Y_Cont
    input  [10:0] left_hand_x,
    input  [10:0] left_hand_y,
    input  [10:0] head_x,
    input  [10:0] head_y,
    input  [10:0] right_hand_x,
    input  [10:0] right_hand_y,
    output reg [11:0] out_R,
    output reg [11:0] out_G,
    output reg [11:0] out_B
);
    parameter HALF_SIZE = 25; // Half of 50x50 square

    // Neon colors in 12-bit (0-4095)
    localparam [11:0] NEON_PINK_R   = 12'd4095;
    localparam [11:0] NEON_PINK_G   = 12'd0;
    localparam [11:0] NEON_PINK_B   = 12'd4095;

    localparam [11:0] NEON_GREEN_R  = 12'd0;
    localparam [11:0] NEON_GREEN_G  = 12'd4095;
    localparam [11:0] NEON_GREEN_B  = 12'd0;

    localparam [11:0] NEON_YELLOW_R = 12'd4095;
    localparam [11:0] NEON_YELLOW_G = 12'd4095;
    localparam [11:0] NEON_YELLOW_B = 12'd0;
    
    always @(*) begin
        // Default: use the original pixel color.
        out_R = orig_R;
        out_G = orig_G;
        out_B = orig_B;
        
        // If within left-hand region, override with neon pink.
        if ((current_x >= left_hand_x - HALF_SIZE) && (current_x < left_hand_x + HALF_SIZE) &&
            (current_y >= left_hand_y - HALF_SIZE) && (current_y < left_hand_y + HALF_SIZE))
        begin
            out_R = NEON_PINK_R;
            out_G = NEON_PINK_G;
            out_B = NEON_PINK_B;
        end
        // Else if within head region, override with neon green.
        else if ((current_x >= head_x - HALF_SIZE) && (current_x < head_x + HALF_SIZE) &&
                 (current_y >= head_y - HALF_SIZE) && (current_y < head_y + HALF_SIZE))
        begin
            out_R = NEON_GREEN_R;
            out_G = NEON_GREEN_G;
            out_B = NEON_GREEN_B;
        end
        // Else if within right-hand region, override with neon yellow.
        else if ((current_x >= right_hand_x - HALF_SIZE) && (current_x < right_hand_x + HALF_SIZE) &&
                 (current_y >= right_hand_y - HALF_SIZE) && (current_y < right_hand_y + HALF_SIZE))
        begin
            out_R = NEON_YELLOW_R;
            out_G = NEON_YELLOW_G;
            out_B = NEON_YELLOW_B;
        end
    end
endmodule
