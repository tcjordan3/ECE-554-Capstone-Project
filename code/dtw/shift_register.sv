module shift_register
#(
  parameter DEPTH=4,
  parameter DATA_WIDTH=32
)
(
  input  logic clk,
  input  logic rst_n,
  input  logic rden,
  input  logic wren,
  input  logic [DATA_WIDTH-1:0] i_data,
  output logic [DATA_WIDTH-1:0] o_data,
  output logic readytoread,
  output logic empty,
  input logic shift
);
    logic [DATA_WIDTH-1:0] queue [0:DEPTH-1];

    logic full;
    
    logic [$clog2(DEPTH):0] read_ptr; // Read pointer for accessing elements
    logic [$clog2(DEPTH):0] count;      // Number of valid elements
    logic wren_2;
    logic wren_3;
    
    // Status signals
    assign full = (count == DEPTH);
    assign empty = (count == 0);
    assign readytoread = (count == 2);
    assign o_data = queue[read_ptr];
    
    // Output data 
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            wren_2 <= 0;
            wren_3 <= 0;
        end
        else if (full) begin
            wren_2 <= wren;
            wren_3 <= wren_2;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            read_ptr <= DEPTH - 1;
            count <= 0;
            for (int i = 0; i < DEPTH; i++) begin
                queue[i] <= '0;
            end
        end
        else begin
            if (wren && !full) begin
                for (int i = DEPTH-1; i > 0; i--) begin
                    queue[i] <= queue[i-1];
                end
                
                // Write new value at the head
                queue[0] <= i_data;
                if(empty) begin
                    queue[1] <= i_data;
                end
                
                count <= count + 1;
            end
            else if (wren_3 && full) begin
                queue[0] <= i_data;
                for (int i = DEPTH-1; i > 0; i--) begin
                        queue[i] <= queue[i-1];
                    end
            end
            
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            read_ptr <= DEPTH - 1;
        end
        else if (rden && !empty) begin
            read_ptr <= read_ptr - 1;
            if (read_ptr == 0 || shift) begin
                read_ptr <= DEPTH - 1;
            end
        end
    end
endmodule