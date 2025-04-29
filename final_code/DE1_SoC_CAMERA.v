// DE1_SoC_CAMERA.v
// Top-level module for capturing frames from a D5M camera, converting
// raw Bayer data to RGB, matching live frames against reference angles
// stored in ROM, computing a dance score via the happy_feet core, and
// displaying results on VGA, HEX displays, and LEDs.  A finite-state
// machine manages splash screens, countdown, gameplay, and end screens.

`timescale 1ns/1ps
`default_nettype wire

module DE1_SoC_CAMERA(
    // ADC (audio codec) interface (unused in this design)
    inout        ADC_CS_N,
    output       ADC_DIN,
    input        ADC_DOUT,
    output       ADC_SCLK,

    // Audio interface (unused)
    input        AUD_ADCDAT,
    inout        AUD_ADCLRCK,
    inout        AUD_BCLK,
    output       AUD_DACDAT,
    inout        AUD_DACLRCK,
    output       AUD_XCK,

    // FPGA clocks
    input        CLOCK2_50,
    input        CLOCK3_50,
    input        CLOCK4_50,
    input        CLOCK_50,      // 50 MHz main clock

    // SDRAM interface
    output [12:0] DRAM_ADDR,
    output [ 1:0] DRAM_BA,
    output        DRAM_CAS_N,
    output        DRAM_CKE,
    output        DRAM_CLK,
    output        DRAM_CS_N,
    inout  [15:0] DRAM_DQ,
    output        DRAM_LDQM,
    output        DRAM_RAS_N,
    output        DRAM_UDQM,
    output        DRAM_WE_N,

    // Fan control (unused)
    output        FAN_CTRL,

    // I2C for camera configuration
    output        FPGA_I2C_SCLK,
    inout         FPGA_I2C_SDAT,

    // GPIO: used for UART TX on bit 0
    inout  [35:0] GPIO_0,

    // Six 7 segment HEX displays
    output  [6:0] HEX0,
    output  [6:0] HEX1,
    output  [6:0] HEX2,
    output  [6:0] HEX3,
    output  [6:0] HEX4,
    output  [6:0] HEX5,

    `ifdef ENABLE_HPS
    // HPS ports omitted
    `endif

    // IRDA interface (unused)
    input         IRDA_RXD,
    output        IRDA_TXD,

    // Pushbuttons and switches
    input    [3:0] KEY,  // KEY[0]=start, KEY[1]=exposure adj, KEY[2]=stop, KEY[3]=reset
    input    [9:0] SW,   // SW[0]=exposure direction, SW[9]=zoom mode

    // Ten red LEDs: first three show match flags
    output   [9:0] LEDR,

    // PS/2 ports (unused)
    inout         PS2_CLK,
    inout         PS2_CLK2,
    inout         PS2_DAT,
    inout         PS2_DAT2,

    // TD input (unused)
    input         TD_CLK27,
    input   [7:0] TD_DATA,
    input         TD_HS,
    output        TD_RESET_N,
    input         TD_VS,

    `ifdef ENABLE_USB
    // USB ports omitted
    `endif

    // VGA interface
    output   [7:0] VGA_B,
    output        VGA_BLANK_N,
    output        VGA_CLK,
    output   [7:0] VGA_G,
    output   [7:0] VGA_R,
    output        VGA_HS,
    output        VGA_SYNC_N,
    output        VGA_VS,

    // D5M camera interface
    input   [11:0] D5M_D,       // raw Bayer pixel data
    input         D5M_FVAL,     // frame valid
    input         D5M_LVAL,     // line valid
    input         D5M_PIXLCLK,  // pixel clock
    output        D5M_RESET_N,  // camera reset (active low)
    output        D5M_SCLK,     // I2C clock for camera
    inout         D5M_SDATA,    // I2C data for camera
    input         D5M_STROBE,   // unused
    output        D5M_TRIGGER,  // camera trigger (held high)
    output        D5M_XCLKIN    // camera clock input
);

    //========================================================================
    // 1) Internal signal declarations
    //========================================================================
    // SDRAM read interface
    wire        Read;
    wire [15:0] Read_DATA1, Read_DATA2;

    // Raw capture outputs
    wire [15:0] X_Cont, Y_Cont;   // pixel coordinates
    wire        mCCD_DVAL;        // raw data valid
    wire [11:0] mCCD_DATA;        // raw Bayer data
    wire [31:0] Frame_Cont;       // captured frame count

    // Reset-delay chain outputs
    wire        DLY_RST_0, DLY_RST_1, DLY_RST_2, DLY_RST_3, DLY_RST_4;

    // Registered latch of raw data
    reg  [11:0] rCCD_DATA;
    reg         rCCD_LVAL, rCCD_FVAL;

    // RGB conversion outputs
    wire [11:0] sCCD_R, sCCD_G, sCCD_B;
    wire        sCCD_DVAL;

    // Clocks for SDRAM controller and VGA logic
    wire        sdram_ctrl_clk, VGA_CTRL_CLK;
    wire  [9:0] oVGA_R, oVGA_G, oVGA_B;

    // Scoring interface
    wire [31:0] score;            // final score
    wire        done;             // scoring complete
    wire        match0, match1, match2; // match LEDs
    wire        dtw_rdy_u; 
    wire [10:0] frame_end_count; 

    //========================================================================
    // 2) Finite-state machine definitions
    //========================================================================
    localparam S_SPLASH  = 3'd0,
               S_COUNT3  = 3'd1,
               S_COUNT2  = 3'd2,
               S_COUNT1  = 3'd3,
               S_CAPTURE = 3'd4,
               S_END     = 3'd5;

    reg [2:0] fsm_state;  // current FSM state
    reg [7:0] frame_cnt;  // line/frame counter for countdown
    reg       vsync_d;    // delayed VGA vsync signal

    //========================================================================
    // 3) 30 Hz tick for reference index and HEX display
    //========================================================================
    reg [20:0] div30;
    wire       tick30 = (div30 == 21'd1666666);  // approx 50e6/30

    always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            div30 <= 0;
        else if (tick30)
            div30 <= 0;
        else
            div30 <= div30 + 1;
    end

    reg start_happy_feet; 
    always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2) 
            start_happy_feet <= 0; 
        else if (mCCD_DVAL & S_CAPTURE)
            start_happy_feet <= 1;
    end

    // Reference-ROM index increments at 30 Hz during capture
    reg [9:0] ref_index;
    always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            ref_index <= 0;
        else if (fsm_state == S_CAPTURE && ref_index < 10'd109)
            ref_index <= ref_index + 1;
    end

    reg [9:0] frame_index;
        always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            frame_index <= 0;
        else if ((fsm_state == S_CAPTURE) && tick30 && (frame_index < 10'd601))
            frame_index <= frame_index + 1;
   	end

    reg capture_frame; 
	always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
	if(!DLY_RST_2)
	    capture_frame <= 0; 
	else if(frame_index % 6 < 1) 
	    capture_frame <= 1; 
	else
            capture_frame <= 0; 
	end

    // Seconds counter displayed on HEX during capture
    reg [23:0] sec_cnt;
    always @(posedge tick30 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            sec_cnt <= 0;
        else if (fsm_state == S_CAPTURE )
            sec_cnt <= sec_cnt + 1;
    end

    //========================================================================
    // 4) Camera start/reset and LED outputs
    //========================================================================
    // Press KEY[0] to begin countdown or auto-start
    assign auto_start  = KEY[0] & DLY_RST_3 & ~DLY_RST_4;
    // Camera free-run trigger and reset lines
    assign D5M_TRIGGER = 1'b1;
    assign D5M_RESET_N = DLY_RST_1;
    // Show match flags on first three LEDs
    assign LEDR[0] = match0;
    assign LEDR[1] = match1;
    assign LEDR[2] = match2;
    assign LEDR[9] = dtw_rdy_u; 

    // Latch raw pixel data into registers on camera pixel clock
    always @(posedge D5M_PIXLCLK) begin
        rCCD_DATA <= D5M_D;
        rCCD_LVAL <= D5M_LVAL;
        rCCD_FVAL <= D5M_FVAL;
    end

    // Forward the PLL-generated VGA clock
    assign VGA_CTRL_CLK = VGA_CLK;

    //========================================================================
    // 5) Reset-delay chain (KEY[3] acts as system reset)
    //========================================================================
    Reset_Delay u_reset(
        .iCLK   (CLOCK_50),
        .iRST   (KEY[3]),
        .oRST_0 (DLY_RST_0),
        .oRST_1 (DLY_RST_1),
        .oRST_2 (DLY_RST_2),
        .oRST_3 (DLY_RST_3),
        .oRST_4 (DLY_RST_4)
    );

    //========================================================================
    // 6) Capture raw Bayer frames into SDRAM
    //========================================================================
    CCD_Capture u_capture(
        .oDATA       (mCCD_DATA),
        .oDVAL       (mCCD_DVAL),
        .oX_Cont     (X_Cont),
        .oY_Cont     (Y_Cont),
        .oFrame_Cont (Frame_Cont),
        .iDATA       (rCCD_DATA),
        .iFVAL       (rCCD_FVAL),
        .iLVAL       (rCCD_LVAL),
        // Start on KEY[0] press or auto_start after reset delay
        .iSTART      (!KEY[3] | auto_start),
        .iEND        (!KEY[2]),
        .iCLK        (~D5M_PIXLCLK),
        .iRST        (DLY_RST_2)
    );

    //========================================================================
    // 7) Reference-angle ROM lookup at 30Hz
    //========================================================================
    wire [9:0] refer_u, refer_ll, refer_lr;
    angles_u   rom_u  (.clock(CLOCK_50), .address(ref_index), .q(refer_u));
    angles_ll  rom_ll (.clock(CLOCK_50), .address(ref_index), .q(refer_ll));
    angles_lr  rom_lr (.clock(CLOCK_50), .address(ref_index), .q(refer_lr));

    //========================================================================
    // 8) RAW to RGB conversion + happy_feet scoring
    //========================================================================
    RAW2RGB u_raw2rgb(
        .iCLK        (D5M_PIXLCLK),
        .iCLK_HF      (CLOCK_50),
        .iRST        (DLY_RST_1),
        .iDATA       (mCCD_DATA),
        .iDVAL       (mCCD_DVAL),
        .iX_Cont     (X_Cont),
        .iY_Cont     (Y_Cont),
        .refer_in_u  (refer_u),
        .refer_in_ll (refer_lr),
        .refer_in_lr (refer_ll),
        .en          ((fsm_state == S_CAPTURE) & capture_frame),
        //.en          ((fsm_state == S_CAPTURE)),
        .oRed        (sCCD_R),
        .oGreen      (sCCD_G),
        .oBlue       (sCCD_B),
        .oDVAL       (sCCD_DVAL),
        .oScore      (score),
        .oDone       (done),
        .oMatch0     (match0),
        .oMatch1     (match1),
        .oMatch2     (match2),
        .oDTW_RDY_U  (dtw_rdy_u),
        .frame_end_count(frame_end_count)
    );

    //========================================================================
    // 9) Synchronize done signal into VGA clock domain, latch score
    //========================================================================
    reg done_s1, done_s2;
    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            {done_s2, done_s1} <= 2'b00;
        else
            {done_s2, done_s1} <= {done_s1, done};
    end
    wire done_vga = done_s2;

    reg [31:0] score_vga;
    reg        done_prev;
    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2) begin
            done_prev <= 1'b0;
            score_vga <= 32'd0;
        end else begin
            done_prev <= done_vga;
            if (done)
                score_vga <= score;
        end
    end

    //========================================================================
    // 10) HEX display logic: show seconds then final score
    //========================================================================
    //wire [23:0] display_val =
        //done ? score_vga[23:0]
                 //: {19'd0, sec_cnt};


    wire [23:0] display_val = done ? score_vga[23:0] : frame_end_count; 

    SEG7_LUT_6 u_seg7(
        .oSEG0(HEX0),
        .oSEG1(HEX1),
        .oSEG2(HEX2),
        .oSEG3(HEX3),
        .oSEG4(HEX4),
        .oSEG5(HEX5),
        .iDIG (display_val)
    );

    //========================================================================
    // 11) SDRAM PLL and controller configuration
    //========================================================================
    sdram_pll u_pll(
        .refclk   (CLOCK_50),
        .rst      (!DLY_RST_0),
        .outclk_0 (sdram_ctrl_clk),
        .outclk_1 (DRAM_CLK),
        .outclk_2 (D5M_XCLKIN),
        .outclk_3 (VGA_CLK)
    );

    Sdram_Control u_sdram(
        .RESET_N     (KEY[3]),         // reset from pushbutton
        .CLK         (sdram_ctrl_clk),

        // Write port for green+blue
        .WR1_DATA    ({1'b0, sCCD_G[11:7], sCCD_B[11:2]}),
        .WR1         (sCCD_DVAL),
        .WR1_ADDR    (0),
        .WR1_MAX_ADDR(640*480),
        .WR1_LENGTH  (8'h50),
        .WR1_LOAD    (!DLY_RST_0),
        .WR1_CLK     (~D5M_PIXLCLK),

        // Write port for green+red
        .WR2_DATA    ({1'b0, sCCD_G[6:2], sCCD_R[11:2]}),
        .WR2         (sCCD_DVAL),
        .WR2_ADDR    (23'h100000),
        .WR2_MAX_ADDR(23'h100000 + 640*480),
        .WR2_LENGTH  (8'h50),
        .WR2_LOAD    (!DLY_RST_0),
        .WR2_CLK     (~D5M_PIXLCLK),

        // Read ports for VGA
        .RD1_DATA    (Read_DATA1),
        .RD1         (Read),
        .RD1_ADDR    (0),
        .RD1_MAX_ADDR(640*480),
        .RD1_LENGTH  (8'h50),
        .RD1_LOAD    (!DLY_RST_0),
        .RD1_CLK     (VGA_CTRL_CLK),

        .RD2_DATA    (Read_DATA2),
        .RD2         (Read),
        .RD2_ADDR    (23'h100000),
        .RD2_MAX_ADDR(23'h100000 + 640*480),
        .RD2_LENGTH  (8'h50),
        .RD2_LOAD    (!DLY_RST_0),
        .RD2_CLK     (VGA_CTRL_CLK),

        // Physical SDRAM pins
        .SA          (DRAM_ADDR),
        .BA          (DRAM_BA),
        .CS_N        (DRAM_CS_N),
        .CKE         (DRAM_CKE),
        .RAS_N       (DRAM_RAS_N),
        .CAS_N       (DRAM_CAS_N),
        .WE_N        (DRAM_WE_N),
        .DQ          (DRAM_DQ),
        .DQM         ({DRAM_UDQM, DRAM_LDQM})
    );

    //========================================================================
    // 12) Configure camera via I²C
    //========================================================================
    I2C_CCD_Config u_i2c(
        .iCLK            (CLOCK2_50),
        .iRST_N          (DLY_RST_2),
        .iEXPOSURE_ADJ   (KEY[1]),
        .iEXPOSURE_DEC_p (SW[0]),
        .iZOOM_MODE_SW   (SW[9]),
        .I2C_SCLK        (D5M_SCLK),
        .I2C_SDAT        (D5M_SDATA)
    );

    //========================================================================
    // 13) Generate half-second tick to alternate splash screens
    //========================================================================
    reg [24:0] splash_div;
    wire       splash_tick = (splash_div == 25'd25000000); // 0.5 s at 50 MHz

    always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            splash_div <= 0;
        else if (splash_tick)
            splash_div <= 0;
        else
            splash_div <= splash_div + 1;
    end

    // Selector for two splash images
    reg splash_sel;
    always @(posedge CLOCK_50 or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            splash_sel <= 1'b0;
        else if (fsm_state == S_SPLASH && splash_tick)
            splash_sel <= ~splash_sel;
    end

    //========================================================================
    // 14) VSYNC edge detect and shared ROM address counter
    //========================================================================
    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            vsync_d <= 1'b0;
        else
            vsync_d <= VGA_VS;
    end

    reg [18:0] rom_addr;
    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            rom_addr <= 0;
        else if (vsync_d && !VGA_VS)
            rom_addr <= 0;       // reset address on each frame
        else if (Read)
            rom_addr <= rom_addr + 1;
    end

    //========================================================================
    // 15) Instantiate screen ROMs and expand 1-bit to 10-bit pixels
    //========================================================================
    // Splash #1 and #2 alternating
    wire q_spl1, q_spl2;
    start_screen        rom_spl1 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_spl1));
    start_screen_second rom_spl2 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_spl2));
    wire [9:0] px_spl1   = q_spl1 ? 10'h3FF : 10'h000;
    wire [9:0] px_spl2   = q_spl2 ? 10'h3FF : 10'h000;
    wire [9:0] px_splash = splash_sel ? px_spl2 : px_spl1;

    // Countdown screens: 3, 2, 1
    wire q_3, q_2, q_1;
    start_screen_3 rom_3 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_3));
    start_screen_2 rom_2 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_2));
    start_screen_1 rom_1 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_1));
    wire [9:0] px3 = q_3 ? 10'h3FF : 10'h000;
    wire [9:0] px2 = q_2 ? 10'h3FF : 10'h000;
    wire [9:0] px1 = q_1 ? 10'h3FF : 10'h000;

    // End screens based on star rating
    wire q_e1, q_e2, q_e3, q_e4, q_e5;
    end_screen_1star rom_e1 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_e1));
    end_screen_2star rom_e2 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_e2));
    end_screen_3star rom_e3 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_e3));
    end_screen_4star rom_e4 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_e4));
    end_screen_5star rom_e5 (.address(rom_addr), .clock(VGA_CTRL_CLK), .q(q_e5));
    wire [9:0] px_e1 = q_e1 ? 10'h3FF : 10'h000;
    wire [9:0] px_e2 = q_e2 ? 10'h3FF : 10'h000;
    wire [9:0] px_e3 = q_e3 ? 10'h3FF : 10'h000;
    wire [9:0] px_e4 = q_e4 ? 10'h3FF : 10'h000;
    wire [9:0] px_e5 = q_e5 ? 10'h3FF : 10'h000;

    localparam [31:0]
      STAR1_THRESH = 32'd1907,
      STAR2_THRESH = 32'd1250,
      STAR3_THRESH = 32'd2000,
      STAR4_THRESH = 32'd3500;

    wire [9:0] px_end =
        (score_vga < STAR1_THRESH) ? px_e1 :
        (score_vga < STAR2_THRESH) ? px_e2 :
        (score_vga < STAR3_THRESH) ? px_e3 :
        (score_vga < STAR4_THRESH) ? px_e4 :
                                     px_e5;

    // Live camera pixels from SDRAM read ports
    wire [9:0] cam_r10 = Read_DATA2[ 9:0];
    wire [9:0] cam_g10 = {Read_DATA1[14:10], Read_DATA2[14:10]};
    wire [9:0] cam_b10 = Read_DATA1[ 9:0];

    //========================================================================
    // 16) FSM transitions on VSYNC edges to advance game states
    //========================================================================
    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2) begin
            fsm_state <= S_SPLASH;
            frame_cnt <= 8'd0;
        end else begin
            case (fsm_state)
              S_SPLASH:
                if (~KEY[0] && vsync_d)        // KEY[0] to start
                    fsm_state <= S_COUNT3;

              S_COUNT3:
                if (vsync_d && !VGA_VS) begin
                    if (frame_cnt == 8'd59) begin
                        fsm_state <= S_COUNT2;
                        frame_cnt <= 8'd0;
                    end else begin
                        frame_cnt <= frame_cnt + 1;
                    end
                end

              S_COUNT2:
                if (vsync_d && !VGA_VS) begin
                    if (frame_cnt == 8'd59) begin
                        fsm_state <= S_COUNT1;
                        frame_cnt <= 8'd0;
                    end else begin
                        frame_cnt <= frame_cnt + 1;
                    end
                end

              S_COUNT1:
                if (vsync_d && !VGA_VS) begin
                    if (frame_cnt == 8'd59) begin
                        fsm_state <= S_CAPTURE;
                        frame_cnt <= 8'd0;
                    end else begin
                        frame_cnt <= frame_cnt + 1;
                    end
                end

              S_CAPTURE:
                if (frame_index == 10'd601)
                    fsm_state <= S_END;

              default: ;
            endcase
        end
    end

    //========================================================================
    // 17) UART transmit on transition from COUNT1 to CAPTURE
    //========================================================================
    reg  [2:0] prev_st;
    reg        uart_start;
    wire       uart_busy, uart_pin;

    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            prev_st <= S_SPLASH;
        else
            prev_st <= fsm_state;
    end

    wire send_uart = (fsm_state == S_COUNT3 && prev_st != S_COUNT3);

    always @(posedge VGA_CTRL_CLK or negedge DLY_RST_2) begin
        if (!DLY_RST_2)
            uart_start <= 1'b0;
        else if (send_uart)
            uart_start <= 1'b1;
        else
            uart_start <= 1'b0;
    end

    uart_tx #(
        .CLK_FREQ(25_000_000),
        .BAUD    (115200)
    ) u_uart_tx (
        .clk      (VGA_CTRL_CLK),
        .rst      (!DLY_RST_2),
        .tx_start (uart_start),
        .tx_data  (8'hA5),
        .tx_busy  (uart_busy),
        .tx_pin   (uart_pin)
    );

    assign GPIO_0 = {{35{1'bz}}, uart_pin};

    //========================================================================
    // 18) Final VGA pixel multiplexer and controller
    //========================================================================
    wire [9:0] vga_r10 = (fsm_state == S_SPLASH) ? px_splash :
                         (fsm_state == S_COUNT3) ? px3       :
                         (fsm_state == S_COUNT2) ? px2       :
                         (fsm_state == S_COUNT1) ? px1       :
                         (fsm_state == S_END    ) ? px_end    :
                                                    cam_r10;

    wire [9:0] vga_g10 = (fsm_state == S_SPLASH) ? px_splash :
                         (fsm_state == S_COUNT3) ? px3       :
                         (fsm_state == S_COUNT2) ? px2       :
                         (fsm_state == S_COUNT1) ? px1       :
                         (fsm_state == S_END    ) ? px_end    :
                                                    cam_g10;

    wire [9:0] vga_b10 = (fsm_state == S_SPLASH) ? px_splash :
                         (fsm_state == S_COUNT3) ? px3       :
                         (fsm_state == S_COUNT2) ? px2       :
                         (fsm_state == S_COUNT1) ? px1       :
                         (fsm_state == S_END    ) ? px_end    :
                                                    cam_b10;

    VGA_Controller u_vga(
        .oRequest     (Read),
        .iRed         (vga_r10),
        .iGreen       (vga_g10),
        .iBlue        (vga_b10),
        .oVGA_R       (oVGA_R),
        .oVGA_G       (oVGA_G),
        .oVGA_B       (oVGA_B),
        .oVGA_H_SYNC  (VGA_HS),
        .oVGA_V_SYNC  (VGA_VS),
        .oVGA_SYNC    (VGA_SYNC_N),
        .oVGA_BLANK   (VGA_BLANK_N),
        .iCLK         (VGA_CTRL_CLK),
        .iRST_N       (DLY_RST_2),
        .iZOOM_MODE_SW(SW[9])
    );

    assign VGA_R = oVGA_R[9:2];
    assign VGA_G = oVGA_G[9:2];
    assign VGA_B = oVGA_B[9:2];

endmodule

`default_nettype wire
