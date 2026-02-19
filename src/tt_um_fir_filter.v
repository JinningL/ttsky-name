`default_nettype none

module tt_um_fir_filter (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // -----------------------
    // Mode select
    // ui_in[1:0] = mode
    // ui_in[7:2] = sample input
    // -----------------------
    wire [1:0] mode;
    assign mode = ui_in[1:0];

    wire [7:0] sample;
    assign sample = {2'b00, ui_in[7:2]};  // 6bit -> 8bit

    // -----------------------
    // Delay line outputs
    // -----------------------
    wire [7:0] x0, x1, x2, x3;

    delay_line delay_inst (
        .clk(clk),
        .rst_n(rst_n),
        .sample_in(sample),
        .x0(x0),
        .x1(x1),
        .x2(x2),
        .x3(x3)
    );

    // -----------------------
    // Filters
    // -----------------------

    // 0: bypass
    wire [15:0] y_bypass;
    assign y_bypass = {8'b0, x0};

    // 1: moving average
    wire [15:0] y_avg;
    fir_core #(.C0(1), .C1(1), .C2(1), .C3(1)) avg_filter (
        .x0(x0), .x1(x1), .x2(x2), .x3(x3),
        .y(y_avg)
    );

    // 2: stronger low-pass
    wire [15:0] y_low;
    fir_core #(.C0(4), .C1(2), .C2(1), .C3(1)) low_filter (
        .x0(x0), .x1(x1), .x2(x2), .x3(x3),
        .y(y_low)
    );

    // 3: high-pass (edge detector)
    wire [15:0] y_high;
    fir_core #(.C0(1), .C1(-1), .C2(0), .C3(0)) high_filter (
        .x0(x0), .x1(x1), .x2(x2), .x3(x3),
        .y(y_high)
    );

    // -----------------------
    // Mode selector (REGISTERED!)
    // -----------------------
    reg [15:0] y_selected;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            y_selected <= 0;
        else begin
            case(mode)
                2'b00: y_selected <= y_bypass;
                2'b01: y_selected <= y_avg;
                2'b10: y_selected <= y_low;
                2'b11: y_selected <= y_high;
            endcase
        end
    end

    // output
    assign uo_out = y_selected[15:8]; // scale down

    // unused pins
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, uio_in, 1'b0};

endmodule