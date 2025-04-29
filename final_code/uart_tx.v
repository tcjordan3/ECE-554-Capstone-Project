// ============================================================================
// uart_tx.v
// Simple UART transmitter (8?N?1) in Verilog?2001 syntax.
// ============================================================================
module uart_tx #(
    parameter CLK_FREQ = 25000000,  // input clock frequency
    parameter BAUD     = 115200     // baud rate
)(
    input        clk,        // system clock
    input        rst,        // synchronous reset, active high
    input        tx_start,   // pulse to start sending
    input  [7:0] tx_data,    // byte to send
    output reg   tx_busy,    // high while transmitting
    output reg   tx_pin      // UART TX output (idles high)
);

    // how many clk ticks per UART bit
    localparam integer BIT_TICKS = CLK_FREQ / BAUD;

    // state encoding
    localparam IDLE      = 2'd0,
               START_BIT = 2'd1,
               DATA_BITS = 2'd2,
               STOP_BIT  = 2'd3;

    reg [1:0]  state;
    integer    tick_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    //------------------------------------------------------------------------------  
    // Main FSM
    //------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx_pin    <= 1'b1;
            tx_busy   <= 1'b0;
            tick_cnt  <= 0;
            bit_idx   <= 0;
            shift_reg <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin  <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_busy   <= 1'b1;
                        shift_reg <= tx_data;
                        tick_cnt  <= 0;
                        state     <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_pin <= 1'b0;  // start bit
                    if (tick_cnt < BIT_TICKS-1) begin
                        tick_cnt <= tick_cnt + 1;
                    end else begin
                        tick_cnt <= 0;
                        bit_idx  <= 0;
                        state    <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_pin <= shift_reg[bit_idx];
                    if (tick_cnt < BIT_TICKS-1) begin
                        tick_cnt <= tick_cnt + 1;
                    end else begin
                        tick_cnt <= 0;
                        if (bit_idx < 7)
                            bit_idx <= bit_idx + 1;
                        else
                            state   <= STOP_BIT;
                    end
                end

                STOP_BIT: begin
                    tx_pin <= 1'b1;  // stop bit
                    if (tick_cnt < BIT_TICKS-1) begin
                        tick_cnt <= tick_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

