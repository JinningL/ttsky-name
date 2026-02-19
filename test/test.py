# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge


def filt_value(mode, hist):
    x0, x1, x2, x3 = hist
    if mode == 0b00:
        y = x0
    elif mode == 0b01:
        y = x0 + x1 + x2 + x3
    elif mode == 0b10:
        y = 4 * x0 + 2 * x1 + x2 + x3
    else:
        y = x0 - x1
    return y & 0xFFFF


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start FIR mode test")

    # 100 kHz clock
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Software model of delay line state before each rising edge:
    # hist = [x0, x1, x2, x3]
    hist = [0, 0, 0, 0]

    # ui_in format in RTL:
    # ui_in[1:0] = mode, ui_in[7:2] = sample(6-bit)
    stimuli = [
        (0b00, 16),  # bypass
        (0b00, 32),  # bypass
        (0b01, 48),  # avg
        (0b01, 12),  # avg
        (0b10, 63),  # stronger low-pass
        (0b10, 1),   # stronger low-pass
        (0b11, 0),   # high-pass
        (0b11, 63),  # high-pass
        (0b11, 0),   # high-pass (negative case)
    ]

    for mode, sample in stimuli:
        ui = ((sample & 0x3F) << 2) | (mode & 0x3)
        dut.ui_in.value = ui

        y16 = filt_value(mode, hist)
        exp_uo = (y16 >> 8) & 0xFF

        await RisingEdge(dut.clk)
        # For gate-level sim, allow propagation through many unit-delay gates.
        await FallingEdge(dut.clk)

        got = int(dut.uo_out.value)
        assert got == exp_uo, (
            f"mode={mode:02b}, sample={sample}, hist={hist}, "
            f"expected={exp_uo}, got={got}"
        )

        # Delay line captures current sample at this edge.
        hist = [sample & 0x3F, hist[0], hist[1], hist[2]]
