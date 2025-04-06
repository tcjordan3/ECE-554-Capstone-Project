module dtw #(
    parameter DATA_WIDTH = 32,         
    parameter SIZE = 20,             
    parameter BAND_RADIUS = 4,        
    parameter BAND_SIZE = 2*BAND_RADIUS+1 
)(
    input wire clk,
    input wire rst_n, 
    input wire [DATA_WIDTH-1:0] refer,  
    input wire [DATA_WIDTH-1:0] camera,  
    output reg [DATA_WIDTH-1:0] score,
	output reg ready_refer,
	output reg ready_camera,
    input wire ready,
    output reg done
);
    
    logic [$clog2(SIZE):0] i, j, count;
    
    logic [DATA_WIDTH-1:0] inp;
    
    logic [DATA_WIDTH-1:0] last;   // w(i,j-1)
    logic [DATA_WIDTH-1:0] band;   // w(i-1,j)
    logic [DATA_WIDTH-1:0] out;    // w(i-1,j-1)      
    
    logic [DATA_WIDTH-1:0] dtw_calc_result;
    
    logic [DATA_WIDTH-1:0] min_ab, min_abc;
    
    logic [DATA_WIDTH-1:0] distance_result, refer_out;
    
    logic compute_enable;
    logic skip_computation;
    logic shift_ready;
    logic first;
	logic read_refer;
	logic refer_full;
        
    //assign score = (state == IDLE) ? 0 : dtw_calc_result;
    assign shift_ready = ready && (!skip_computation);

    shift_register_dtw #(
        .WIDTH(DATA_WIDTH),
        .R(BAND_SIZE)
    ) shift_reg (
        .in(dtw_calc_result),
        .clk(clk),
        .rst_n(rst_n),
        .last(last),   
        .band(band),    
        .out(out),
        .ready(shift_ready)
    );

	shift_register #(
		.DEPTH(BAND_RADIUS),
		.DATA_WIDTH(DATA_WIDTH)
	) fifo (
		.clk(clk),
		.rst_n(rst_n),
		.rden(read_refer),
		.wren(ready_refer),
		.i_data(refer),
		.o_data(refer_out),
		.full(refer_full),
		.empty()
	);

    assign min_ab = (last < band) ? last : band;
    assign min_abc = (min_ab < out) ? min_ab : out;
    
    assign distance_result = (inp > refer_out) ? (inp - refer_out) : (refer_out - inp);
    // assign distance_result = diff * diff; 

    typedef enum reg [1:0] {IDLE, INCR, COMPUTE, DONE} state_t;
    state_t state, next_state;
    
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    assign dtw_calc_result = (first) ? '0 : 
                             (skip_computation ? {{4'b0000}, {(DATA_WIDTH - 4){1'b1}}} : 
                             (min_abc + distance_result)); 
    
    // Control logic
    always_comb begin
            next_state = state;
            case (state)
                IDLE: begin
                    i = 0;
                    j = 0;
                    first = 1;
                    compute_enable = 0;
                    skip_computation = 0;
					read_refer = 0;
					ready_camera = 0;
					ready_refer = 0;
					count = 0;
                    done = 0;
                    score = 0;
                    if (ready) begin
						ready_refer = 1;
						if (refer_full) begin
                        	skip_computation = 0;
                        	next_state = INCR;
							read_refer = 0;
							ready_camera = 1;
							ready_refer = 0;
						end
                    end
                end
                
                INCR: begin
                    // read_refer = 1;
					// ready_camera = 0;
					// ready_refer = 0;
                    if (ready) begin
                        compute_enable = 1;

                        if ( (i !== 0) || (j !== 0)) begin
                            first = 0;
                        end

                        skip_computation = (i == 0 && j != 0) ||    // Skip first row (except [0,0])
                                            (j == 0 && i != 0); // Skip if outside the band radius

                        
                        // At the beginning of a new row, load the x value
                        if (count == 0) begin
                            inp = camera;
                        end

                        // Update computation progress
                        //if (compute_enable) begin
                            // Check if we've completed the DTW calculation
                            if (i == SIZE -1  && j == SIZE - 1) begin
                                next_state = DONE;
                                compute_enable = 0;
                                skip_computation = 1;
                                score = dtw_calc_result;
                            end
                            
                            // Update counters
                            if (j == SIZE - 1) begin
                                j = 0;
                                if (i == SIZE - 1) begin
                                    i = 0;
                                end 
                            end
                            if (count == (BAND_RADIUS - 1)) begin
                                j = j + 1;
                                i = i + 1;
                                ready_refer = 1;
                                ready_camera = 1;
                                count = 0;
                            end
                            else begin
							    count = count + 1;
                            end
							read_refer = 1;
                        //end
                    end
                end

                COMPUTE: begin
                    
                end
                
                DONE: begin
                    done = 1;
                    compute_enable = 0;
                    next_state = IDLE;
                end
                default: next_state = IDLE;
            endcase
        end

endmodule