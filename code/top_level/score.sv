module score #(
    parameter DATA_WIDTH = 10   // bits needed to specify score
)(
    input logic clk,                        // clock
    input logic rst_n,                      // active-low reset
    input logic start,                      // indicates score computation can begin
    input logic [DATA_WIDTH-1:0] score_u,   // score from dtw_u
    input logic [DATA_WIDTH-1:0] score_ll,  // score from dtw_ll
    input logic [DATA_WIDTH-1:0] score_lr,  // score from dtw_lr
    output logic [DATA_WIDTH-1:0] score,    // final score
    output logic done                       // indicates score has been computed
);

    localparam logic [15:0] MAX = 16'hFFFF;

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            score <= '0;
            done <= 0;
        end else if(start) begin
            score <= MAX - score_u -score_ll - score_lr;
            done <= 1;
        end
    end

endmodule