`default_nettype none

module delay_line(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] sample_in,
    output reg  [7:0] x0,
    output reg  [7:0] x1,
    output reg  [7:0] x2,
    output reg  [7:0] x3
);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x0 <= 0;
            x1 <= 0;
            x2 <= 0;
            x3 <= 0;
        end
        else begin
            x3 <= x2;
            x2 <= x1;
            x1 <= x0;
            x0 <= sample_in;
        end
    end

endmodule