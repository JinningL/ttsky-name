# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start FIR test")

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

    # y[n] = floor((x[n] + x[n-1] + x[n-2] + x[n-3]) / 4)
    # Keep a software model of the 4-sample delay line.
    samples = [4, 8, 12, 16, 0, 0]
    hist = [0, 0, 0, 0]

    for sample in samples:
        dut.ui_in.value = sample
        await RisingEdge(dut.clk)
        # For gate-level sim, allow propagation through many unit-delay gates.
        await FallingEdge(dut.clk)

        hist = [sample, hist[0], hist[1], hist[2]]
        exp = sum(hist) >> 2
        got = int(dut.uo_out.value)
        assert got == exp, f"sample={sample}, expected={exp}, got={got}"
