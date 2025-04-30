// RAW2RGB.v
`timescale 1ns/1ps
`default_nettype wire

module RAW2RGB #(
    parameter IMG_WIDTH   = 640,      // width of image
    parameter IMG_HEIGHT  = 480,      // height of image
    parameter ANGLE_DEPTH = 10,        // bits needed to specify angle
    parameter FRAME_COUNT = 110
)(
    // pixel-domain interface
    input  wire                          iCLK,       // pixel clock (D5M_PIXLCLK) - ~27MHz CLK
    input  wire                          iCLK_HF,    //50MHz CLK
    input  wire                          iRST,       // active‑low reset
    input  wire [11:0]                   iDATA,      // raw Bayer input
    input  wire                          iDVAL,      // raw data valid
    input  wire [$clog2(IMG_WIDTH)-1:0]  iX_Cont,    // pixel X coordinate
    input  wire [$clog2(IMG_HEIGHT)-1:0] iY_Cont,    // pixel Y coordinate

    // reference angles (from top‑level ROMs @ 30 Hz)
    input  wire [ANGLE_DEPTH-1:0]        refer_in_u,   //
    input  wire [ANGLE_DEPTH-1:0]        refer_in_ll,  //
    input  wire [ANGLE_DEPTH-1:0]        refer_in_lr,  //
    input  wire                          en,

    // RGB output
    output wire [11:0]                   oRed,        // demosaiced R
    output wire [11:0]                   oGreen,      // demosaiced G
    output wire [11:0]                   oBlue,       // demosaiced B
    output wire                          oDVAL,       // RGB data valid

    // happy_feet results
    output wire [31:0]                   oScore,      // final score
    output wire                          oDone,        // done signal
    output wire                          oMatch0, 
    output wire                          oMatch1, 
    output wire                          oMatch2,

    output wire                          oDTW_RDY_U,
    output reg [9:0]                     k,
    output wire [10:0]                    frame_end_count
);

    // internal line‑buffer signals
    wire [11:0] mDATA_0, mDATA_1;
    reg  [11:0] mDATAd_0, mDATAd_1;
    reg  [11:0] mCCD_R;
    reg  [12:0] mCCD_G;
    reg  [11:0] mCCD_B;
    reg         mDVAL;

    reg fill;

    //reg [9:0] k;

    always @(posedge iCLK_HF or negedge iRST) begin
        if(~iRST) begin
            k <= 10'd0;
            fill <= 1;
        end else if(k == FRAME_COUNT - 1) begin
            // stay
            fill <= 0;
        end else begin
            k <= k + 1;
            fill <= 1;
        end
    end

    

    // connect outputs
    assign oRed   = mCCD_R;
    assign oGreen = mCCD_G[12:1];
    assign oBlue  = mCCD_B;
    assign oDVAL  = mDVAL;

    // line buffer
    Line_Buffer1 uLinebuf (
        .clken   (iDVAL),
        .clock   (iCLK),
        .shiftin (iDATA),
        .taps0x  (mDATA_1),
        .taps1x  (mDATA_0)
    );

    // Bayer→RGB demosaic, one valid per 2×2 neighborhood
    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            mDATAd_0 <= 0;
            mDATAd_1 <= 0;
            mDVAL    <= 0;
            mCCD_R   <= 0;
            mCCD_G   <= 0;
            mCCD_B   <= 0;
        end else begin
            mDATAd_0 <= mDATA_0;
            mDATAd_1 <= mDATA_1;
            mDVAL    <= ~(iY_Cont[0] | iX_Cont[0]) & iDVAL;
            case ({iY_Cont[0], iX_Cont[0]})
                2'b10: begin
                    mCCD_R <= mDATA_0;
                    mCCD_G <= mDATAd_0 + mDATA_1;
                    mCCD_B <= mDATAd_1;
                end
                2'b11: begin
                    mCCD_R <= mDATAd_0;
                    mCCD_G <= mDATA_0 + mDATAd_1;
                    mCCD_B <= mDATA_1;
                end
                2'b00: begin
                    mCCD_R <= mDATA_1;
                    mCCD_G <= mDATA_0 + mDATAd_1;
                    mCCD_B <= mDATAd_0;
                end
                2'b01: begin
                    mCCD_R <= mDATAd_1;
                    mCCD_G <= mDATAd_0 + mDATA_1;
                    mCCD_B <= mDATA_0;
                end
                default: ;
            endcase
        end
    end

    //------------------------------------------------------------------------
    // happy_feet instantiation now fed from top‑level ROMs
    //------------------------------------------------------------------------
    happy_feet #(
        .IMG_WIDTH   (IMG_WIDTH),
        .IMG_HEIGHT  (IMG_HEIGHT),
        .ANGLE_DEPTH (ANGLE_DEPTH),
        .FRAME_COUNT (FRAME_COUNT)
    ) happy_feet_inst (
        .clk         (iCLK_HF),
        .rst_n       (iRST),
        .pixel_r     (oRed),
        .pixel_g     (oGreen),
        .pixel_b     (oBlue),
        .en          (en),
        .pixel_valid (oDVAL),
        .x           (iX_Cont),
        .y           (iY_Cont),
        .fill        (fill),

        // reference angles
        .refer_in_u  (refer_in_u),
        .refer_in_ll (refer_in_ll),
        .refer_in_lr (refer_in_lr),

        .score       (oScore),
        .done        (oDone),
        .oMatch0     (oMatch0),
        .oMatch1     (oMatch1),
        .oMatch2     (oMatch2),

        .oDTW_RDY_U(DTW_RDY_U),
        .frame_end_count(frame_end_count)
    );

endmodule

`default_nettype wire
