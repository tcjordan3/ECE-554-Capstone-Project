module counter(
    input logic clk,          // clock
    input logic rst_n,        // active-low reset
    input logic start,        // indicates when to begin counting
    output logic [4:0] k      // count value
);

// count register
always_ff @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        k <= '0;
    end else if(start) begin
        k <= '0;
    end else if(k == 5'd19) begin
        k <= '0;
    end else begin
        k <= k + 1;
    end
end

endmodule