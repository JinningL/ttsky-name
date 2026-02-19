<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a 4-tap FIR low-pass filter on 8-bit input samples.

On each rising edge of `clk`, the input sample is shifted into a 4-stage delay line:
- `x0 = x[n]`
- `x1 = x[n-1]`
- `x2 = x[n-2]`
- `x3 = x[n-3]`

The FIR core computes:

`sum = x0 + x1 + x2 + x3`

Then outputs:

`y = sum >> 2`

So the design acts as a moving-average filter that smooths high-frequency noise.

## How to test

1. Apply reset: set `rst_n = 0` for a few clock cycles, then set `rst_n = 1`.
2. Drive `ui_in[7:0]` with 8-bit input samples.
3. Observe `uo_out[7:0]`.
4. Verify output equals the average of the latest 4 samples.

Example sequence after reset release:
- input: `4, 8, 12, 16`
- output progression: `1, 3, 6, 10`

## External hardware

No external hardware is required.
