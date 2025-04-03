module dtw_accelerator #(
    parameter DATA_WIDTH = 32,         
    parameter SIZE = 2500,             
    parameter BAND_RADIUS = 16,        
    parameter BAND_SIZE = 2*BAND_RADIUS+1 
)(
    input wire clk,
    input wire rst_n, 
    input wire [DATA_WIDTH-1:0] refer,  
    input wire [DATA_WIDTH-1:0] camera,  
    output wire [DATA_WIDTH-1:0] score,
    input wire ready
);

    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    logic [1:0] state, next_state;
    
    logic [$clog2(SIZE):0] i, j;
    
    logic [DATA_WIDTH-1:0] inp;
    
    logic [DATA_WIDTH-1:0] last;   // w(i,j-1)
    logic [DATA_WIDTH-1:0] band;   // w(i-1,j)
    logic [DATA_WIDTH-1:0] out;    // w(i-1,j-1)      
    
    logic [DATA_WIDTH-1:0] dtw_calc_result;
    
    logic [DATA_WIDTH-1:0] min_ab, min_abc;
    
    logic [DATA_WIDTH-1:0] distance_result;
    
    logic compute_enable;
    logic skip_computation;
    logic shift_ready;
        
    assign score = out;
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

    assign min_ab = (last < band) ? last : band;
    assign min_abc = (min_ab < out) ? min_ab : out;
    
    assign distance_result = (inp > camera) ? (inp - camera) : (camera - inp);
    // assign distance_result = diff * diff; 
    
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            inp <= 0;
            i <= 0;
            j <= 0;
            compute_enable <= 0;
            skip_computation <= 1;
        end 
        else begin
            state <= next_state;
        end
    end

    assign dtw_calc_result = skip_computation ? {{4'b0000}, {(DATA_WIDTH - 4){1'b1}}} : (min_abc + distance_result); 
    
    // Control logic
    always @(posedge clk, negedge rst_n) begin
            case (state)
                IDLE: begin
                    i <= 0;
                    j <= 0;
                    compute_enable <= 0;
                    skip_computation <= 0;
                    if (ready)
                        skip_computation <= 0;
                        next_state = COMPUTE;
                end
                
                COMPUTE: begin
                    if (ready) begin
                        compute_enable <= 1;
                        
                        // Determine if current computation should be skipped (special cases)
                        // 1. Start of new row (adjust Sakoe-Chiba band)
                        // 2. Elements outside the matrix dimensions
                        skip_computation <= (j == 0) || 
                                           (i < BAND_RADIUS && j < BAND_RADIUS - i) ||
                                           (i >= SIZE - BAND_RADIUS && j > i + BAND_RADIUS - (SIZE - 1));

                        
                        // At the beginning of a new row, load the x value
                        if (j == 0) begin
                            inp <= refer;
                        end
                        
                        // Update computation progress
                        if (compute_enable) begin
                            // Check if we've completed the DTW calculation
                            if (i == SIZE-1 && j == SIZE-1) begin
                                next_state <= DONE;
                                compute_enable <= 0;
                            end
                            
                            // Update counters
                            if (j == SIZE-1) begin
                                j <= 0;
                                if (i == SIZE-1) begin
                                    i <= 0;
                                end else begin
                                    i <= i + 1;
                                end
                            end else begin
                                j <= j + 1;
                            end
                        end
                    end
                end
                
                DONE: begin
                    compute_enable <= 0;
                    next_state = IDLE;
                end
                default: next_state = IDLE;
            endcase
        end

endmodule