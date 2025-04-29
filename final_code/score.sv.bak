module score #(
    parameter DATA_WIDTH = 32   // bits needed to specify score
)(
    input logic clk,                        // clock
    input logic rst_n,                      // active-low reset
    input logic start,                      // indicates score computation can begin
    input logic [DATA_WIDTH-1:0] score_u,   // score from dtw_u
    input logic [DATA_WIDTH-1:0] score_ll,  // score from dtw_ll
    input logic [DATA_WIDTH-1:0] score_lr,  // score from dtw_lr
    output logic [DATA_WIDTH+1:0] score,    // final score
    output logic done                       // indicates score has been computed
);

    assign score = 32'hFFFF;

endmodule
