module game_control (
    input  wire clk,       // system clock
    input  wire rst_n,     // active?low reset (e.g. DLY_RST_2)
    input  wire start_sig, // active?high start pulse (e.g. ~KEY[0])
    input  wire end_sig,   // active?high stop pulse  (e.g. ~KEY[3])
    output reg  state      // game_on flag: 1 = capture running, 0 = paused
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= 1'b0;      // on reset, force paused
        else if (end_sig)
            state <= 1'b0;      // stop takes priority
        else if (start_sig)
            state <= 1'b1;      // then start
        // otherwise retain previous state
    end

endmodule

