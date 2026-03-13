/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
 
    // ── VGA wires ──────────────────────────────
    logic        hsync, vsync, visible;
    logic [9:0]  px, py;           // current pixel position
 
    vga_timer vga_timer_inst (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .hsync_o     (hsync),
        .vsync_o     (vsync),
        .visible_o   (visible),
        .position_x_o(px),
        .position_y_o(py)
    );
 
    // ── DVD logo dimensions ────────────────────
    localparam LOGO_W = 40;
    localparam LOGO_H = 20;
 
    // ── Screensaver state (updated once per frame) ──
    // Position stored as 10‑bit (fits 0‑639 / 0‑479)
    logic [9:0]  logo_x, logo_y;       // top‑left corner
    logic        dir_x, dir_y;         // 0 = positive, 1 = negative
    logic [2:0]  colour_idx;
 
    // Speed: 2 pixels per frame
    localparam SPEED = 10'd2;
 
    // Screen bounds: x in [0 .. 640-LOGO_W-1], y in [0 .. 480-LOGO_H-1]
    localparam MAX_X = 10'd600;   // 640 - LOGO_W (40)
    localparam MAX_Y = 10'd460;   // 480 - LOGO_H (20)
 
    // End‑of‑frame pulse: fires when py transitions from 479 → 0
    // We detect vsync falling edge (active low during blanking)
    logic vsync_prev;
    logic frame_pulse;
 
    always_ff @(posedge clk) begin
        if (!rst_n) vsync_prev <= 1'b1;
        else        vsync_prev <= vsync;
    end
    // vsync goes LOW at end of active video → rising edge of ~vsync
    assign frame_pulse = vsync_prev & ~vsync;
 
    // ── Bounce logic ──────────────────────────
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            logo_x     <= 10'd100;
            logo_y     <= 10'd80;
            dir_x      <= 1'b0;   // moving right
            dir_y      <= 1'b0;   // moving down
            colour_idx <= 3'd0;
        end else if (frame_pulse) begin
            // --- X axis ---
            if (!dir_x) begin
                if (logo_x + SPEED >= MAX_X) begin
                    logo_x  <= MAX_X;
                    dir_x   <= 1'b1;
                    colour_idx <= colour_idx + 1'b1;
                end else begin
                    logo_x <= logo_x + SPEED;
                end
            end else begin
                if (logo_x <= SPEED) begin
                    logo_x  <= 10'd0;
                    dir_x   <= 1'b0;
                    colour_idx <= colour_idx + 1'b1;
                end else begin
                    logo_x <= logo_x - SPEED;
                end
            end
 
            // --- Y axis ---
            if (!dir_y) begin
                if (logo_y + SPEED >= MAX_Y) begin
                    logo_y  <= MAX_Y;
                    dir_y   <= 1'b1;
                    colour_idx <= colour_idx + 1'b1;
                end else begin
                    logo_y <= logo_y + SPEED;
                end
            end else begin
                if (logo_y <= SPEED) begin
                    logo_y  <= 10'd0;
                    dir_y   <= 1'b0;
                    colour_idx <= colour_idx + 1'b1;
                end else begin
                    logo_y <= logo_y - SPEED;
                end
            end
        end
    end
 
    // ── Pixel‑in‑logo test ────────────────────
    logic        in_logo_x, in_logo_y;
    logic [5:0]  rel_x;
    logic [4:0]  rel_y;
    logic        logo_pixel;
    logic [1:0]  r_col, g_col, b_col;
 
    assign in_logo_x = (px >= logo_x) && (px < logo_x + LOGO_W);
    assign in_logo_y = (py >= logo_y) && (py < logo_y + LOGO_H);
 
    // Only compute relative coords when inside logo bounds to prevent
    // wrap-around values misleading the synthesizer into optimizing the ROM away
    assign rel_x = in_logo_x ? 6'(px - logo_x) : 6'd0;
    assign rel_y = in_logo_y ? 5'(py - logo_y) : 5'd0;
 
    dvd_logo_rom logo_rom (
        .col  (rel_x[5:0]),
        .row  (rel_y[4:0]),
        .pixel(logo_pixel)
    );
 
    colour_palette palette (
        .idx(colour_idx),
        .r(r_col), .g(g_col), .b(b_col)
    );
 
    // ── Final RGB output ──────────────────────
    logic [1:0] r_out, g_out, b_out;
 
    always_comb begin
        if (visible && in_logo_x && in_logo_y && logo_pixel) begin
            r_out = r_col;
            g_out = g_col;
            b_out = b_col;
        end else begin
            r_out = 2'b00;   // black background
            g_out = 2'b00;
            b_out = 2'b00;
        end
    end
 
    // ── VGA output pin mapping ─────────────────
    // Tiny Tapeout VGA PMOD pinout:
    //  uo_out[0]  = R[1]   uo_out[4] = vsync
    //  uo_out[1]  = G[0]   uo_out[5] = R[0]
    //  uo_out[2]  = B[1]   uo_out[6] = G[1]
    //  uo_out[3]  = hsync  uo_out[7] = B[0]
    assign uo_out[0] = r_out[1];
    assign uo_out[1] = g_out[0];
    assign uo_out[2] = b_out[1];
    assign uo_out[3] = hsync;
    assign uo_out[4] = vsync;
    assign uo_out[5] = r_out[0];
    assign uo_out[6] = g_out[1];
    assign uo_out[7] = b_out[0];
 
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
 
    wire _unused = &{ena, ui_in, uio_in, 1'b0};
 
endmodule