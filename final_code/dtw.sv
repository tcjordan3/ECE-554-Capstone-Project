module dtw #(
    parameter DATA_WIDTH   = 10,
    parameter OVERFLOW = 30,         
    parameter SIZE         = 600,             
    parameter BAND_RADIUS  = 4,        
    parameter BAND_SIZE    = 4
)(
    input  wire                     clk,
    input  wire                     rst_n, 
    input  wire [DATA_WIDTH-1:0]    refer,  
    input  wire [DATA_WIDTH-1:0]    camera,  
    output reg  [OVERFLOW-1:0]    score,
    output reg                      ready_refer,
    output reg                      ready_camera,
    input  wire                     ready,
    output reg                      done
);

    logic [$clog2(SIZE):0] i, j, count;

    logic [OVERFLOW-1:0] inp;
    logic [OVERFLOW-1:0] last;   // w(i,j-1)
    logic [OVERFLOW-1:0] band;   // w(i-1,j)
    logic [OVERFLOW-1:0] out;    // w(i-1,j-1)      
    logic [OVERFLOW-1:0] dtw_calc_result;
    logic [OVERFLOW-1:0] min_ab, min_abc;
    logic [OVERFLOW-1:0] distance_result, refer_out;

    logic skip_computation;
    logic first;
    logic read_refer;
    logic refer_full;
    logic inc_done;
    logic write_fifo;
    logic shift;
    logic shift_ready;

    logic nxt_first;
    logic nxt_skip_computation;
    logic nxt_read_refer;
    logic nxt_ready_camera;
    logic nxt_ready_refer;
    logic nxt_done;
    logic [OVERFLOW-1:0] nxt_score;
    logic nxt_inc_done;
    logic nxt_shift;
    logic [OVERFLOW-1:0] nxt_inp;


    logic [$clog2(SIZE):0] next_i, next_j, next_count;

 
    assign shift_ready = ready && (!skip_computation) && read_refer;

    shift_register_dtw #(
        .WIDTH(OVERFLOW),
        .R(BAND_SIZE)
    ) shift_reg (
        .in(dtw_calc_result),
        .clk(clk),
        .rst_n(rst_n),
        .last(last),   
        .band(band),    
        .out(out),
        .ready(shift_ready & (!first))
    );

    shift_register #(
        .DEPTH(BAND_RADIUS),
        .DATA_WIDTH(OVERFLOW)
    ) fifo (
        .clk(clk),
        .rst_n(rst_n),
        .rden(read_refer),
        .wren(write_fifo),
        .i_data(refer),
        .o_data(refer_out),
        .readytoread(refer_full),
        .empty(),
        .shift(shift)
    );

    // Compute minimums and distance
    assign min_ab   = (last < band) ? last : band;
    assign min_abc  = (min_ab == {{4'b0000}, {(DATA_WIDTH - 4){1'b1}}}) ? '0 : (min_ab < out) ? min_ab : out;
    assign distance_result = (inp > refer_out) ? (inp - refer_out) : (refer_out - inp);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_fifo <= 0;
        end
        else begin
            write_fifo <= ready_refer;
        end
    end

    // DTW calculation result logic:
    assign dtw_calc_result = (first) ? '0: 
                             (skip_computation ? {{4'b0000}, {(DATA_WIDTH - 4){1'b1}}} : 
                              (min_abc + distance_result)); 


    typedef enum  reg[1:0] {IDLE, INCR, COMPUTE, DONE} state_t;
    state_t state, next_state;


    //simple size counter
    logic [10:0] size_counter; 
    logic inc_size_counter;

    always_comb begin
        next_state        = state;
        next_i            = i;
        next_j            = j;
        next_count        = count;
        inc_size_counter  = 0;
        first = nxt_first;
        skip_computation = nxt_skip_computation;
        read_refer = nxt_read_refer;
        ready_camera =  nxt_ready_camera;
        ready_refer = nxt_ready_refer;
        done = nxt_done;
        score = nxt_score;
        inc_done = nxt_inc_done;
        shift = nxt_shift;
        inp = nxt_inp;

        case (state)
            IDLE: begin
                next_i            = 0;
                next_j            = 0;
                next_count        = 0;
                first        = 1;
                skip_computation = 0;
                read_refer   = 0;
                inc_size_counter = 0;
                ready_camera = 0;
                ready_refer  = 0;
                done         = 0;
                score        = 0;
                inc_done = 0;
                shift = 0;
                if (ready) begin
                    ready_refer = 1;
                end
                    if (refer_full) begin
                        skip_computation = 0;
                        next_state = INCR;
                        read_refer = 1;
                        ready_camera = 1;
                        ready_refer  = 0;
                    end
            end

            INCR: begin
                if (ready) begin
                    ready_camera = 0;
                    ready_refer  = 0;
                    first = 0;
                    shift = 0;
                    if ((i != 0) || (j != 0))
                        first = 0;

                    // Set skip_computation if in first row (except [0,0]) or first column
                    skip_computation = ((i == 0) && (j != 0)) ||
                                            ((j == 0) && (i != 0));

                    // At beginning of new row, load camera value
                    inp = camera;

                    // Check if we've completed the DTW matrix
                    if ((i == SIZE - 1) && (j == SIZE - 1)) begin
                        inc_done = 1;
                    end
                    else begin
                        if (j == SIZE - 1) begin
                            next_j = 0;
                            if (i == SIZE - 1)
                                next_i = 0;
                        end
                    end
                    next_count = 1;
                    next_state = COMPUTE;
                    if (j >= (SIZE - BAND_RADIUS + 2) || (i == BAND_RADIUS - 3)) begin
                            ready_refer = 0;
                        end
                        else ready_refer = 1;
                end
            end

            COMPUTE: begin
                // Signal to read from the refer FIFO in this state.
                read_refer = 1;
                ready_refer = 0;
                if((i < BAND_RADIUS - 1) && (count == (i + 1))) begin
                    shift = 1;
                    next_j = j + 1;
                        next_i = i + 1;
                        next_count = '0;
                        next_state = INCR;
                        ready_camera = 1;
                end
                else if (count == (BAND_RADIUS -1) || ((i < BAND_RADIUS - 1) && (count == (i + 1)))) begin
                    if(inc_done) begin
                        next_state = DONE;
                        inc_size_counter = 1; 
                        skip_computation = 1;
                    end
                    else begin
                        next_j = j + 1;
                        next_i = i + 1;
                        next_count = '0;
                        next_state = INCR;
                        ready_camera = 1;
                    end
                end
                else begin
                    next_count = count + 1;
                end
            end

            DONE: begin
                done = 1;
                // Remain in DONE 
                next_state = DONE;         
                score = out;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if(~rst_n)
            size_counter <= 0;
        else if(inc_size_counter)
            size_counter <= size_counter + 1; 

    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            i               <= 0;
            j               <= 0;
            count           <= 0;
            nxt_first <= 0;
            nxt_skip_computation <= 0;
            nxt_read_refer <= 0;
            nxt_ready_camera <= 0;
            nxt_ready_refer <= 0;
            nxt_done <= 0;
            nxt_score <= 0;
            nxt_inc_done <= 0;
            nxt_shift <= 0;
            nxt_inp <= 0;
        end
        else begin
            state           <= next_state;
            i               <= next_i;
            j               <= next_j;
            count           <= next_count;
            nxt_first <= first;
            nxt_skip_computation <= skip_computation;
            nxt_read_refer <= read_refer;
            nxt_ready_camera <= ready_camera;
            nxt_ready_refer <= ready_refer;
            nxt_done <= done;
            nxt_score <= score;
            nxt_inc_done <= inc_done;
            nxt_shift <= shift;
            nxt_inp <= inp;
        end
    end

endmodule
