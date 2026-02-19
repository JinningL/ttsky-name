`default_nettype none

module fir_core #(
    parameter signed C0 = 1,
    parameter signed C1 = 0,
    parameter signed C2 = 0,
    parameter signed C3 = 0
)(
    input  wire signed [7:0] x0,
    input  wire signed [7:0] x1,
    input  wire signed [7:0] x2,
    input  wire signed [7:0] x3,
    output wire signed [15:0] y
);

    wire signed [15:0] m0;
    wire signed [15:0] m1;
    wire signed [15:0] m2;
    wire signed [15:0] m3;

    assign m0 = x0 * C0;
    assign m1 = x1 * C1;
    assign m2 = x2 * C2;
    assign m3 = x3 * C3;

    assign y = m0 + m1 + m2 + m3;

endmodule