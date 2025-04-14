module shifter #(
    parameter ANGLE_DEPTH = 10,      // bits needed to specify angle
    parameter NUM_VALUES = 22        // number of values to store in shift register
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

    logic [ANGLE_DEPTH-1:0] fifo_array [0:NUM_VALUES-1]; // FIFO array
    logic [PTR_WIDTH-1:0] write_ptr;                     // Write pointer
    logic [PTR_WIDTH-1:0] read_ptr;                      // Read pointer
    logic [PTR_WIDTH:0] count;                           // Count of elements in FIFO

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            write_ptr <= '0;
            read_ptr <= '0;
            count <= '0;
            angle_out <= '0;
            for (int i = 0; i < NUM_VALUES; i++) begin
                fifo_array[i] <= '0;
            end
        end 
        else begin
            // Fill operation - store new angle
            if (fill && count < NUM_VALUES) begin
                fifo_array[write_ptr] <= angle_in;
                write_ptr <= (write_ptr == NUM_VALUES - 1) ? '0 : write_ptr + 1;
                count <= count + 1;
            end
            
            // Ready operation - output stored angle
            if (ready && count > 0) begin
                angle_out <= fifo_array[read_ptr];
                read_ptr <= (read_ptr == NUM_VALUES - 1) ? '0 : read_ptr + 1;
                count <= count - 1;
            end
        end
    end

endmodule