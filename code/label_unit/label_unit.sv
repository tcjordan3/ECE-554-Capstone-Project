module label_unit(
    input clk,          // clock
    input rst_n,        // active-low reset
    input start,        // high when coordinates received

    // x & y input coordinates from cluster unit
    input logic signed [7:0] x_0,
    input logic signed [7:0] y_0,
    input logic signed [7:0] x_1,
    input logic signed [7:0] y_1,
    input logic signed [7:0] x_2,
    input logic signed [7:0] y_2,
    // uppermost coordinate pair
    output logic [7:0] x_u,
    output logic [7:0] y_u,
    // lower-left coordinate pair
    output logic [7:0] x_ll,
    output logic [7:0] y_ll,
    // lower-right coordinate pair
    output logic [7:0] x_lr,
    output logic [7:0] y_lr
);

    // registers for determining output
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_u <= '0;
            y_u <= '0;
            x_ll <= '0;
            y_ll <= '0;
            x_lr <= '0;
            y_lr <= '0;
        end else if(start) begin
            if((y_0 >= y_1) && (y_0 >= y_2)) begin      // y_0 is uppermost point
                x_u <= x_0;
                y_u <= y_0;
                if(x_1 >= x_2) begin                     // (x_1, y_1) is lower-right pair
                    x_lr <= x_1;
                    y_lr <= y_1;
                    x_ll <= x_2;
                    y_ll <= y_2;
                end else begin                          // (x_2, y_2) is lower-right pair
                    x_lr <= x_2;
                    y_lr <= y_2;
                    x_ll <= x_1;
                    y_ll <= y_1;
                end
            end else if(y_1 >= y_0 && y_1 >= y_2) begin // y_1 is uppermost point
                x_u <= x_1;
                y_u <= y_1;
                if(x_0 > x_2) begin                     // (x_0, y_0) is lower-right pair
                    x_lr <= x_0;
                    y_lr <= y_0;
                    x_ll <= x_2;
                    y_ll <= y_2;
                end else begin                          // (x_2, y_2) is lower-right pair
                    x_lr <= x_2;
                    y_lr <= y_2;
                    x_ll <= x_0;
                    y_ll <= y_0;
                end
            end else begin                              // y_2 is uppermost point
                x_u <= x_2;
                y_u <= y_2;
                if(x_0 > x_1) begin                     // (x_0, y_0) is lower-right pair
                    x_lr <= x_0;
                    y_lr <= y_0;
                    x_ll <= x_1;
                    y_ll <= y_1;
                end else begin                          // (x_1, y_1) is lower-right pair
                    x_lr <= x_1;
                    y_lr <= y_1;
                    x_ll <= x_0;
                    y_ll <= y_0;
                end
            end
        end
    end

endmodule
