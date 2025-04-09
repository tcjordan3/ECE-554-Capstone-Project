module shifter #(
    parameter ANGLE_DEPTH = 10,      // bits needed to specify angle
    parameter NUM_VALUES = 25        // number of values to store in shift register
)(
    input logic clk,                               // clock
    input logic rst_n,                             // active-low reset
    input logic fill,                              // shift register stores angle_in when high
    input logic [ANGLE_DEPTH-1:0] angle_in,        // reference angle input
    output logic [ANGLE_DEPTH-1:0] angle_out,      // reference angle output
    input logic ready                              // output angle when high
);

    // Calculate the number of bits needed to index NUM_VALUES
    localparam PTR_WIDTH = $clog2(NUM_VALUES);

    logic [ANGLE_DEPTH-1:0] shift_reg [0:NUM_VALUES-1]; // shift register array
    logic [PTR_WIDTH-1:0] ptr;                          // pointer for fill logic

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ptr <= NUM_VALUES - 1;
            angle_out <= '0;
            for (int i = 0; i < NUM_VALUES; i++) begin
                shift_reg[i] <= '0;
            end
        end 
        else if (fill) begin
            shift_reg[ptr] <= angle_in;
            if (ptr != 0) begin
                ptr <= ptr - 1;
            end
        end 
        else if (ready) begin
            angle_out <= shift_reg[NUM_VALUES-1];
            for (int i = NUM_VALUES-1; i > 0; i--) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= '0;
            if (ptr != NUM_VALUES - 1) begin
                ptr <= ptr + 1;
            end
        end
    end

endmodule