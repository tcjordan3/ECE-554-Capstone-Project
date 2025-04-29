// shift_register.sv
`timescale 1ns/1ps
`default_nettype none

module shift_register #(
    parameter DEPTH       = 4,
    parameter DATA_WIDTH = 32
)(
    // Port declarations with explicit net types
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    rden,
    input  wire                    wren,
    input  wire [DATA_WIDTH-1:0]   i_data,
    output wire [DATA_WIDTH-1:0]   o_data,
    output wire                    readytoread,
    output wire                    empty,
    input  wire                    shift
);

    // Internal storage
    logic [DATA_WIDTH-1:0] queue [0:DEPTH-1];

    // Status signals
    logic [$clog2(DEPTH)-1:0] count;
    logic                     full;
    logic [$clog2(DEPTH)-1:0] read_ptr;

    // Combinational outputs
    assign full        = (count == DEPTH);
    assign empty       = (count == 0);
    assign readytoread = (count == 2);
    assign o_data      = queue[read_ptr];

    // Write side: push new data into queue
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                queue[i] <= '0;
            end
        end else if (wren && !full) begin
            // shift everything up
            for (int i = DEPTH-1; i > 0; i--) begin
                queue[i] <= queue[i-1];
            end
            queue[0] <= i_data;
            if (empty) begin
                queue[1] <= i_data; // duplicate so readytoread sees two
            end
            count <= count + 1;
        end
    end

    // Read side: decrement pointer on read
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= DEPTH - 1;
        end else if (rden && !empty) begin
            if (read_ptr == 0 || shift)
                read_ptr <= DEPTH - 1;
            else
                read_ptr <= read_ptr - 1;
        end
    end

endmodule

`default_nettype wire

