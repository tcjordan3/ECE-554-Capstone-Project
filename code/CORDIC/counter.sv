module counter(
    input logic clk,          // clock
    input logic rst_n,        // active-low reset
    input logic start,        // indicates when to begin counting
    output logic [4:0] k      // count value
);

logic toggle;   // toggle flag to track every other clock cycle

// toggle flip-flop
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        toggle <= 1'b0;
    end else if(start) begin
        toggle <= 1'b0;
    end else begin
        toggle <= ~toggle;
    end
end

// count register
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        k <= '0;
    end else if(start) begin
        k <= '0;
    end else if(k == 5'b10100) begin
        k <= '0;
    end else if(toggle) begin  // only increment when toggle is high
        k <= k + 1;
    end
end

endmodule