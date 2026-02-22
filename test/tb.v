`default_nettype none

module tb;
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

`ifdef USE_POWER_PINS
    // Keep gate-level power pins in a defined state.
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif

    tt_um_fir_filter dut (.*);

endmodule
