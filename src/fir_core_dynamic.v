`default_nettype none

module fir_core_dynamic (
    input  wire signed [7:0]  x0,
    input  wire signed [7:0]  x1,
    input  wire signed [7:0]  x2,
    input  wire signed [7:0]  x3,
    input  wire signed [7:0]  h0,  // Runtime coefficient
    input  wire signed [7:0]  h1,  // Runtime coefficient
    input  wire signed [7:0]  h2,  // Runtime coefficient
    input  wire signed [7:0]  h3,  // Runtime coefficient
    output wire signed [15:0] y
);

    // Multiply-accumulate: y[n] = h0*x[n] + h1*x[n-1] + h2*x[n-2] + h3*x[n-3]
    wire signed [15:0] m0, m1, m2, m3;
    
    assign m0 = x0 * h0;
    assign m1 = x1 * h1;
    assign m2 = x2 * h2;
    assign m3 = x3 * h3;
    
    assign y = m0 + m1 + m2 + m3;

endmodule
