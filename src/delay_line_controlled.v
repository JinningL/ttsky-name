`default_nettype none

module delay_line_controlled (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_en,    // NEW: only shift when enabled
    input  wire [7:0]  sample_in,
    output reg  [7:0]  x0,
    output reg  [7:0]  x1,
    output reg  [7:0]  x2,
    output reg  [7:0]  x3
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x0 <= 8'b0;
            x1 <= 8'b0;
            x2 <= 8'b0;
            x3 <= 8'b0;
        end
        else if (sample_en) begin  // Only shift when sampling (not during register writes)
            x3 <= x2;
            x2 <= x1;
            x1 <= x0;
            x0 <= sample_in;
        end
        // else: hold values during register write operations
    end

endmodule
