module LUT #(parameter ITERATIONS = 20 )(
    input  logic [4:0] k,            // iteration index input
    output logic [7:0] LUT_k          // angle output in degrees
);

    logic [7:0] atan_table [0:ITERATIONS-1];    // Array to store the arctangent values in degrees
    assign LUT_k = atan_table[k];               // Table output
    
    // Initialize the table with pre-calculated arctangent values in degrees
    // atan_table[i] = atan(2^(-i)) in degrees
    initial begin
        // Converting atan(2^(-i)) from radians to degrees: angle_degrees = angle_radians * (180/π)
        atan_table[0]  = 8'd45;    // atan(2^0)  = atan(1)     = 45.0000°
        atan_table[1]  = 8'd26;    // atan(2^-1) = atan(0.5)   = 26.5651°
        atan_table[2]  = 8'd14;    // atan(2^-2) = atan(0.25)  = 14.0362°
        atan_table[3]  = 8'd7;     // atan(2^-3) = atan(0.125) = 7.1250°
        atan_table[4]  = 8'd4;     // atan(2^-4) = 3.5763°
        atan_table[5]  = 8'd2;     // atan(2^-5) = 1.7899°
        atan_table[6]  = 8'd1;     // atan(2^-6) = 0.8952°
        atan_table[7]  = 8'd0;     // atan(2^-7) = 0.4476° (rounded to 0 in 8-bit)
        atan_table[8]  = 8'd0;     // atan(2^-8) = 0.2238° (rounded to 0 in 8-bit)
        atan_table[9]  = 8'd0;     // atan(2^-9) = 0.1119° (rounded to 0 in 8-bit)
        atan_table[10] = 8'd0;     // atan(2^-10) = 0.0560° (rounded to 0 in 8-bit)
        atan_table[11] = 8'd0;     // atan(2^-11) = 0.0280° (rounded to 0 in 8-bit)
        atan_table[12] = 8'd0;     // atan(2^-12) = 0.0140° (rounded to 0 in 8-bit)
        atan_table[13] = 8'd0;     // atan(2^-13) = 0.0070° (rounded to 0 in 8-bit)
        atan_table[14] = 8'd0;     // atan(2^-14) = 0.0035° (rounded to 0 in 8-bit)
        atan_table[15] = 8'd0;     // atan(2^-15) = 0.0017° (rounded to 0 in 8-bit)
        atan_table[16] = 8'd0;     // atan(2^-16) = 0.0009° (rounded to 0 in 8-bit)
        atan_table[17] = 8'd0;     // atan(2^-17) = 0.0004° (rounded to 0 in 8-bit)
        atan_table[18] = 8'd0;     // atan(2^-18) = 0.0002° (rounded to 0 in 8-bit)
        atan_table[19] = 8'd0;     // atan(2^-19) = 0.0001° (rounded to 0 in 8-bit)
    end
    
endmodule