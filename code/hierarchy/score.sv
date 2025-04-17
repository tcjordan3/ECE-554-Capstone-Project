module score #(
    parameter DATA_WIDTH = 32,   // bits needed to specify score
    parameter MAX_VALUE = (1 << DATA_WIDTH) - 1
)(
    input logic clk,                        // clock
    input logic rst_n,                      // active-low reset
    input logic start,                      // indicates score computation can begin
    input logic [DATA_WIDTH-1:0] score_u,   // score from dtw_u
    input logic [DATA_WIDTH-1:0] score_ll,  // score from dtw_ll
    input logic [DATA_WIDTH-1:0] score_lr,  // score from dtw_lr
    output logic [DATA_WIDTH+3:0] score,    // final score
    output logic done                       // indicates score has been computed
);
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin    
            done <= 0;
            score <= '0;
        end
        else if(start) begin
            score <= MAX_VALUE + MAX_VALUE + MAX_VALUE - ( score_u + score_lr + score_ll);
            done <= 1;
        end
        else
            done <= 0;
    end

endmodule