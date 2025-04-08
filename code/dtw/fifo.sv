module fifo
#(
  parameter DEPTH=20,
  parameter DATA_WIDTH=32
)
(
  input  clk,
  input  rst_n,
  input  rden,
  input  wren,
  input  [DATA_WIDTH-1:0] i_data,
  output [DATA_WIDTH-1:0] o_data,
  output full,
  output empty
);
    logic [DATA_WIDTH-1:0] queue [DEPTH-1:0];
    logic [10:0] index;
    logic emp, ful;
    logic [DATA_WIDTH-1:0] o_data_temp;

    always @(posedge clk, negedge rst_n) begin
	if (~rst_n) begin
	    o_data_temp <= 0;
	    index <= 0;
	    emp <= 1;
	    ful <= 0;
	end
	else if (wren & !full) begin
	    queue[index] <= i_data;
	    index <= index + 1;
	    if (index == DEPTH - 1) begin
	    	emp <= 0;
    	        ful <= 1;
	    end
	end
	else if (rden & !empty) begin
	    o_data_temp <= queue[0];
		 for (int i = 0; i < DEPTH-1; i++) begin
			queue[i] <= queue[i+1];
		 end
		 queue[DEPTH-1] <= 0;
	    //queue[7:0] <= {8'h00, queue[7], queue[6], queue[5], queue[4], queue[3], queue[2], queue[1]};
	    index <= index-1;
	    if (index == 0) begin
		emp <= 1;
	        ful <= 0;
	    end
	end 
    end
    
assign full = ful;
assign empty = emp;
assign o_data = o_data_temp;


endmodule