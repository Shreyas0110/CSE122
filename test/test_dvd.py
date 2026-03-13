# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

"""
DVD Screensaver VGA Testbench
- Drives the tt_um_example module through cocotb
- Captures raw VGA pixel data frame-by-frame
- Saves frames as PNG images
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import os
import struct
import zlib

# ── VGA constants ──────────────────────────────────────────────
H_VISIBLE      = 640
V_VISIBLE      = 480
H_TOTAL        = 800
V_TOTAL        = 525
PIXEL_CLOCK_NS = 40   # 25 MHz → 40 ns per pixel

# ── Safe integer read (handles X/Z in gate-level sim) ─────────
def read_int(signal):
    """Return integer value of a signal, or None if it contains X/Z."""
    try:
        return signal.value.to_unsigned()
    except ValueError:
        return None

# ── Tiny Tapeout VGA PMOD pin mapping (from uo_out) ───────────
# uo_out[0]=R1  uo_out[1]=G0  uo_out[2]=B1  uo_out[3]=hsync
# uo_out[4]=vsync  uo_out[5]=R0  uo_out[6]=G1  uo_out[7]=B0
def decode_uo_out(val):
    r = ((val >> 0) & 1) << 1 | ((val >> 5) & 1)   # R[1:0]
    g = ((val >> 6) & 1) << 1 | ((val >> 1) & 1)   # G[1:0]
    b = ((val >> 2) & 1) << 1 | ((val >> 7) & 1)   # B[1:0]
    hsync = (val >> 3) & 1
    vsync = (val >> 4) & 1
    return r * 85, g * 85, b * 85, hsync, vsync  # scale 2-bit → 8-bit


# ── Minimal PNG writer (no Pillow needed) ─────────────────────
def _png_chunk(chunk_type, data):
    c = chunk_type + data
    crc = zlib.crc32(c) & 0xFFFFFFFF
    return struct.pack('>I', len(data)) + c + struct.pack('>I', crc)

def save_png(path, pixels, width, height):
    """pixels: flat list of (r,g,b) tuples, row-major"""
    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter type None
        for x in range(width):
            r, g, b = pixels[y * width + x]
            raw += bytes([r, g, b])
    compressed = zlib.compress(raw, 6)
    png  = b'\x89PNG\r\n\x1a\n'
    png += _png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    png += _png_chunk(b'IDAT', compressed)
    png += _png_chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


# ── Frame capture helper ───────────────────────────────────────
async def capture_frame(dut):
    """Sync to vsync pulse then capture one full visible frame."""
    # Wait for vsync to go low — skip cycles where signal is still X/Z
    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.clk)
        val = read_int(dut.uo_out)
        if val is not None and not ((val >> 4) & 1):
            break

    # Wait for vsync to go high again (end of vsync pulse)
    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.clk)
        val = read_int(dut.uo_out)
        if val is not None and ((val >> 4) & 1):
            break

    pixels = [(0, 0, 0)] * (H_VISIBLE * V_VISIBLE)
    x, y = 0, 0
    hsync_prev, vsync_prev = 1, 1

    for _ in range(H_TOTAL * V_TOTAL + 100):
        await RisingEdge(dut.clk)
        val = read_int(dut.uo_out)
        if val is None:
            x += 1
            continue  # skip X/Z cycles, treat as invisible

        r8, g8, b8, hsync, vsync = decode_uo_out(val)

        # Track raster position
        if hsync_prev == 1 and hsync == 0:   # hsync falling edge → new line
            x = 0
            if vsync_prev == 0 and vsync == 1:
                y = 0
        if hsync_prev == 0 and hsync == 1:   # hsync rising edge → increment line
            y += 1

        if hsync == 1 and vsync == 1 and x < H_VISIBLE and y < V_VISIBLE:
            pixels[y * H_VISIBLE + x] = (r8, g8, b8)

        x += 1
        hsync_prev = hsync
        vsync_prev = vsync

        if y >= V_VISIBLE and vsync == 0:
            break

    return pixels


# ══════════════════════════════════════════════════════════════
#  Main test
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_dvd_screensaver(dut):
    dut._log.info("=== DVD Screensaver VGA Testbench ===")

    OUTPUT_DIR = os.environ.get("SIM_OUTPUT_DIR", "vga_output")
    NUM_FRAMES = int(os.environ.get("VGA_FRAMES", "8"))
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # ── Clock: 25 MHz → 40 ns period ──────────────────────────
    clock = Clock(dut.clk, PIXEL_CLOCK_NS, unit="ns")
    cocotb.start_soon(clock.start())

    # ── Drive power pins if present (gate-level sim) ──────────
    if hasattr(dut, 'VPWR'):
        dut.VPWR.value = 1
        dut.VGND.value = 0
        dut._log.info("Power pins driven (GL sim)")

    # ── Reset ──────────────────────────────────────────────────
    dut._log.info("Applying reset")
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value  = 1
    dut._log.info("Reset released")

    # ── Wait for signals to come out of X/Z ───────────────────
    # Gate-level sim needs extra cycles for all flops to initialise
    dut._log.info("Waiting for signals to resolve from X/Z...")
    for _ in range(H_TOTAL * V_TOTAL):  # up to one full frame
        await RisingEdge(dut.clk)
        if read_int(dut.uo_out) is not None:
            break
    else:
        raise AssertionError("uo_out never resolved from X/Z after reset")

    val = read_int(dut.uo_out)
    dut._log.info(f"uo_out resolved = 0x{val:02X}")

    # ── Wait for first vsync ───────────────────────────────────
    dut._log.info("Waiting for first vsync...")
    for _ in range(H_TOTAL * V_TOTAL * 2):
        await RisingEdge(dut.clk)
        val = read_int(dut.uo_out)
        if val is not None and not ((val >> 4) & 1):
            break
    else:
        raise AssertionError("Timed out waiting for vsync")
    dut._log.info("vsync detected — starting frame capture")

    # ── Capture frames and save PNGs ──────────────────────────
    for frame_idx in range(NUM_FRAMES):
        dut._log.info(f"Capturing frame {frame_idx + 1}/{NUM_FRAMES}...")
        pixels = await capture_frame(dut)

        non_black = sum(1 for r, g, b in pixels if r or g or b)
        dut._log.info(f"  Frame {frame_idx}: {non_black} lit pixels "
                      f"({100 * non_black // (H_VISIBLE * V_VISIBLE)}% coverage)")

        if frame_idx > 0:
            assert non_black > 0, \
                f"Frame {frame_idx} is entirely black — logo not rendering!"

        path = os.path.join(OUTPUT_DIR, f"frame_{frame_idx:03d}.png")
        save_png(path, pixels, H_VISIBLE, V_VISIBLE)
        dut._log.info(f"  Saved {path}")

    # ── Check sync pulse widths ────────────────────────────────
    dut._log.info("Checking sync pulse widths...")

    hsync_low_count = 0
    total_cycles    = H_TOTAL * 3   # sample 3 lines

    for _ in range(total_cycles):
        await RisingEdge(dut.clk)
        val = read_int(dut.uo_out)
        if val is not None and not ((val >> 3) & 1):
            hsync_low_count += 1

    # hsync pulse = 96 px/line; over 3 lines → ~288 low cycles
    assert 80 < hsync_low_count < 400, \
        f"hsync pulse width unexpected: {hsync_low_count} cycles in {total_cycles}"
    dut._log.info(f"  hsync low cycles (3 lines): {hsync_low_count} ✓")

    dut._log.info(f"Frames saved to: {OUTPUT_DIR}/")
    dut._log.info("=== All tests passed ✓ ===")