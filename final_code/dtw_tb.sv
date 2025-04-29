`timescale 1ns/1ps

module dtw_tb;
  // parameters
  localparam DATA_WIDTH  = 10;
  localparam SIZE        = 602;
  localparam BAND_RADIUS = 4;
  localparam BAND_SIZE   = 4;

  // clock and reset
  reg clk;
  reg rst_n;

  // DUT I/O
  reg                       ready;
  reg  [DATA_WIDTH-1:0]     refer;
  reg  [DATA_WIDTH-1:0]     camera;
  wire [DATA_WIDTH-1:0]     score;
  wire                      ready_refer;
  wire                      ready_camera;
  wire                      done;

  // instantiate DUT
  dtw #(
    .DATA_WIDTH  (DATA_WIDTH),
    .SIZE        (SIZE),
    .BAND_RADIUS (BAND_RADIUS),
    .BAND_SIZE   (BAND_SIZE)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .refer         (refer),
    .camera        (camera),
    .score         (score),
    .ready_refer   (ready_refer),
    .ready_camera  (ready_camera),
    .ready         (ready),
    .done          (done)
  );

  // test data arrays
  reg [DATA_WIDTH-1:0] test_refer  [0:SIZE-1];
  reg [DATA_WIDTH-1:0] test_camera [0:SIZE-1];
  integer ref_idx, cam_idx, i;

  // clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz clock
  end

  // initialize test vectors (simple ramp, replace or $readmemh as needed)
  initial begin
    for (i = 0; i < SIZE; i = i + 1) begin
      test_refer[i]  = i;
      test_camera[i] = SIZE - i;
    end
  end

  // drive reset and ready
  initial begin
    rst_n = 0;
    ready = 0;
    refer = 0;
    camera = 0;
    ref_idx = 0;
    cam_idx = 0;

    #20;
    rst_n = 1;
    #20;
    ready = 1;        // start the DTW run
  end

  // feed refer and camera whenever DUT is ready for them
  always @(posedge clk) begin
    if (ready_refer && ref_idx < SIZE) begin
      refer  <= test_refer[ref_idx];
      ref_idx <= ref_idx + 1;
    end

    if (ready_camera && cam_idx < SIZE) begin
      camera  <= test_camera[cam_idx];
      cam_idx <= cam_idx + 1;
    end
  end

  // finish when done
  always @(posedge clk) begin
    if (done) begin
      #10;
      $display("DTW complete, score = %0d", score);
      $finish;
    end
  end

endmodule

