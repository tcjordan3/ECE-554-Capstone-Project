module cordic_iteration #(parameter ITERATIONS = 20) (
    input logic clk,                // clock
    input logic rst_n,              // active-low reset
    input logic start,              // high when a new iteration begins
    input logic [4:0] k,            // iteration counter
    input logic [9:0] LUT_k,        // angle from lookup table
    input logic [7:0] x,            // x coordinate
    input logic [7:0] y,            // y coordinate
    input logic [9:0] angle_begin,  // starting angle
    output logic rdy,               // high when angle fully computed
    output logic [9:0] angle_final  // angle to compute
);

    logic [7:0] x_k;   // x coordinate at the kth iteration
    logic [7:0] y_k;   // y coordinate at the kth iteration

    logic add;              // high when adding; low when subtracting
    logic initialize;       // high when we need to initialize angle and coordinates

    typedef enum reg [1:0] {IDLE, ITERATE, DONE} state_t;
    state_t state, nxt_state;

    // Next state and reset logic
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= nxt_state;
        end
    end

    always_comb begin
        // default outputs
        nxt_state = state;
        rdy = 0;
        add = 0;
        initialize = 0;

        case(state)
            IDLE : begin    // wait to begin iterating; initialize coordinates and angle
                if(start) begin
                    initialize = 1;
                    nxt_state = ITERATE;
                end
            end

            ITERATE : begin // Determine if current iteration requires addition or subtraction
                if(y_k[7] == 0) begin
                    add = 1;
                end else begin
		            add = 0;
		        end

                if(k == ITERATIONS - 1) begin
                    nxt_state = DONE;
                end
            end

            DONE : begin    // indicate angle is ready before reset
                rdy = 1;
                nxt_state = IDLE;
            end
        endcase
    end

    // accumulation registers for iterative updates
    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n) begin
            x_k <= '0;
            y_k <= '0;
            angle_final <= '0;
        end else if(initialize) begin
            x_k <= x;
            y_k <= y;
            angle_final <= angle_begin;
        end else if(state == ITERATE) begin
            if(add) begin
                x_k <= x_k + (y_k >> k);
                y_k <= y_k - (x_k >> k);
                angle_final <= angle_final + LUT_k;
            end else begin
                x_k <= x_k - (y_k >> k);
                y_k <= y_k + (x_k >> k);
                angle_final <= angle_final - LUT_k;
            end
        end 
    end

endmodule