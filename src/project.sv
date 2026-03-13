/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none
 
// ──────────────────────────────────────────────────────────────
//  DVD Logo ROM  (40 wide × 12 tall active, rows 12-19 = black)
//  case-per-row style — most synthesis-friendly ROM description
// ──────────────────────────────────────────────────────────────
module dvd_logo_rom (
    input  logic [5:0] col,   // 0-39
    input  logic [4:0] row,   // 0-19
    output logic       pixel
);
    // ████████████████████████████████████████  row 0
    // █                                      █  row 1
    // █ ██████    ██    ██  ██████           █  row 2
    // █ ██   ██   ██    ██  ██   ██          █  row 3
    // █ ██    ██   ██  ██   ██    ██         █  row 4-7
    // █ ██   ██      ██     ██   ██          █  row 8
    // █ ██████       ██     ██████           █  row 9
    // █                                      █  row 10
    // ████████████████████████████████████████  row 11
 
    logic [39:0] row_bits;
 
    always_comb begin
        case (row)
            5'd0:    row_bits = 40'b1111111111111111111111111111111111111111;
            5'd1:    row_bits = 40'b1000000000000000000000000000000000000001;
            5'd2:    row_bits = 40'b1011111100001100001100111111000000000001;
            5'd3:    row_bits = 40'b1011000110001100001100110001100000000001;
            5'd4:    row_bits = 40'b1011000011000110011000110000110000000001;
            5'd5:    row_bits = 40'b1011000011000110011000110000110000000001;
            5'd6:    row_bits = 40'b1011000011000011110000110000110000000001;
            5'd7:    row_bits = 40'b1011000011000011110000110000110000000001;
            5'd8:    row_bits = 40'b1011000110000001100000110001100000000001;
            5'd9:    row_bits = 40'b1011111100000001100000111111000000000001;
            5'd10:   row_bits = 40'b1000000000000000000000000000000000000001;
            5'd11:   row_bits = 40'b1111111111111111111111111111111111111111;
            default: row_bits = 40'b0000000000000000000000000000000000000000;
        endcase
        pixel = (col < 6'd40) ? row_bits[39 - col] : 1'b0;
    end
endmodule
 
 
// ──────────────────────────────────────────────────────────────
//  Colour palette — 8 colours, cycles on each wall bounce
// ──────────────────────────────────────────────────────────────
module colour_palette (
    input  logic [2:0] idx,
    output logic [1:0] r,
    output logic [1:0] g,
    output logic [1:0] b
);
    always_comb begin
        case (idx)
            3'd0: begin r = 2'b11; g = 2'b00; b = 2'b00; end // red
            3'd1: begin r = 2'b00; g = 2'b11; b = 2'b00; end // green
            3'd2: begin r = 2'b00; g = 2'b00; b = 2'b11; end // blue
            3'd3: begin r = 2'b11; g = 2'b11; b = 2'b00; end // yellow
            3'd4: begin r = 2'b11; g = 2'b00; b = 2'b11; end // magenta
            3'd5: begin r = 2'b00; g = 2'b11; b = 2'b11; end // cyan
            3'd6: begin r = 2'b11; g = 2'b10; b = 2'b00; end // orange
            3'd7: begin r = 2'b10; g = 2'b00; b = 2'b11; end // purple
            default: begin r = 2'b11; g = 2'b11; b = 2'b11; end
        endcase
    end
endmodule
 
 
// ──────────────────────────────────────────────────────────────
//  Top-level: tt_um_example
// ──────────────────────────────────────────────────────────────
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
 
    // ── VGA timer ─────────────────────────────────────────────
    logic        hsync, vsync, visible;
    logic [9:0]  px, py;
 
    vga_timer vga_timer_inst (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .hsync_o      (hsync),
        .vsync_o      (vsync),
        .visible_o    (visible),
        .position_x_o (px),
        .position_y_o (py)
    );
 
    // ── Logo dimensions ────────────────────────────────────────
    localparam [9:0] LOGO_W = 10'd40;
    localparam [9:0] LOGO_H = 10'd20;
    localparam [9:0] SPEED  = 10'd2;
    localparam [9:0] MAX_X  = 10'd600;  // 640 - 40
    localparam [9:0] MAX_Y  = 10'd460;  // 480 - 20
 
    // ── Screensaver state registers ────────────────────────────
    logic [9:0] logo_x, logo_y;
    logic       dir_x,  dir_y;
    logic [2:0] colour_idx;
 
    // ── End-of-frame pulse (registered to avoid combinational glitch) ──
    logic vsync_d1, vsync_d2, frame_pulse;
 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            vsync_d1 <= 1'b1;
            vsync_d2 <= 1'b1;
        end else begin
            vsync_d1 <= vsync;
            vsync_d2 <= vsync_d1;
        end
    end
    // Pulse one cycle after vsync falls (registered, glitch-free)
    assign frame_pulse = vsync_d2 & ~vsync_d1;
 
    // ── Bounce logic ───────────────────────────────────────────
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            logo_x     <= 10'd100;
            logo_y     <= 10'd80;
            dir_x      <= 1'b0;
            dir_y      <= 1'b0;
            colour_idx <= 3'd0;
        end else if (frame_pulse) begin
 
            // X axis
            if (!dir_x) begin
                if (logo_x + SPEED >= MAX_X) begin
                    logo_x     <= MAX_X;
                    dir_x      <= 1'b1;
                    colour_idx <= colour_idx + 3'd1;
                end else begin
                    logo_x <= logo_x + SPEED;
                end
            end else begin
                if (logo_x <= SPEED) begin
                    logo_x     <= 10'd0;
                    dir_x      <= 1'b0;
                    colour_idx <= colour_idx + 3'd1;
                end else begin
                    logo_x <= logo_x - SPEED;
                end
            end
 
            // Y axis
            if (!dir_y) begin
                if (logo_y + SPEED >= MAX_Y) begin
                    logo_y     <= MAX_Y;
                    dir_y      <= 1'b1;
                    colour_idx <= colour_idx + 3'd1;
                end else begin
                    logo_y <= logo_y + SPEED;
                end
            end else begin
                if (logo_y <= SPEED) begin
                    logo_y     <= 10'd0;
                    dir_y      <= 1'b0;
                    colour_idx <= colour_idx + 3'd1;
                end else begin
                    logo_y <= logo_y - SPEED;
                end
            end
        end
    end
 
    // ── Pixel-in-logo bounds check ─────────────────────────────
    logic in_logo_x, in_logo_y;
    assign in_logo_x = (px >= logo_x) && (px < logo_x + LOGO_W);
    assign in_logo_y = (py >= logo_y) && (py < logo_y + LOGO_H);
 
    // Clamp relative coords to 0 when outside logo to prevent
    // wrap-around values from being optimized into the ROM address
    logic [5:0] rel_x;
    logic [4:0] rel_y;
    assign rel_x = in_logo_x ? 6'(px - logo_x) : 6'd0;
    assign rel_y = in_logo_y ? 5'(py - logo_y) : 5'd0;
 
    // ── ROM and palette lookups ────────────────────────────────
    logic        logo_pixel;
    logic [1:0]  r_col, g_col, b_col;
 
    dvd_logo_rom logo_rom (
        .col   (rel_x),
        .row   (rel_y),
        .pixel (logo_pixel)
    );
 
    colour_palette palette (
        .idx (colour_idx),
        .r   (r_col),
        .g   (g_col),
        .b   (b_col)
    );
 
    // ── Final RGB mux ──────────────────────────────────────────
    logic [1:0] r_out, g_out, b_out;
    logic       show_pixel;
 
    assign show_pixel = visible & in_logo_x & in_logo_y & logo_pixel;
 
    assign r_out = show_pixel ? r_col : 2'b00;
    assign g_out = show_pixel ? g_col : 2'b00;
    assign b_out = show_pixel ? b_col : 2'b00;
 
    // ── VGA output — Tiny Tapeout PMOD pinout ─────────────────
    // uo_out[0]=R1  uo_out[1]=G0  uo_out[2]=B1  uo_out[3]=hsync
    // uo_out[4]=vsync  uo_out[5]=R0  uo_out[6]=G1  uo_out[7]=B0
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
 
    // Explicitly tie off unused inputs so the synthesizer
    // doesn't optimize away logic reachable through them
    wire _unused;
    assign _unused = ena ^ ui_in[0] ^ uio_in[0];
 
endmodule


// This file is from CSE 100 Summer 2024
// Honestly, I have no memory of what I contributed to this file

// vs what was given as base code
// Copyright (c) 2024 Ethan Sifferman.
// All rights reserved. Distribution Prohibited.

// https://vesa.org/vesa-standards/
// http://tinyvga.com/vga-timing
module vga_timer (
    // possible ports list:
    input  logic       clk_i,
    input  logic       rst_ni,
    output logic       hsync_o,
    output logic       vsync_o,
    output logic       visible_o,
    output logic [9:0] position_x_o,
    output logic [9:0] position_y_o
);

logic [9:0] hsync_timer_o;
logic [9:0] vsync_timer_o;
logic is799;

always_comb begin
    if (hsync_timer_o == 10'd799) begin
        is799 = 1;
    end else begin
        is799 = 0;
    end
end

always_ff @(posedge clk_i) begin
    if (!rst_ni)
        hsync_timer_o<= 10'b0;
    else
        hsync_timer_o <= (is799) ? 10'b0 : hsync_timer_o + 1;
end

assign position_x_o = hsync_timer_o[9:0] ;

// END HSYNC

logic is524;

always_comb begin
    if (vsync_timer_o == 10'd524) begin
        is524 = 1;
    end else begin
        is524 = 0;
    end
end

always_ff @(posedge clk_i) begin
    if (~rst_ni)
        vsync_timer_o<= 10'b0;
    else begin
        if(is799) begin
            if(is524)
                vsync_timer_o <= 0;
            else
                vsync_timer_o <= vsync_timer_o +1;
        end
        else
            vsync_timer_o <= vsync_timer_o;
    end
end

always_comb begin
    if (hsync_timer_o < 10'd640 && vsync_timer_o < 480) begin
        visible_o = 1;
    end else begin
        visible_o = 0;
    end
    if (hsync_timer_o > 10'd655 && hsync_timer_o < 752) begin
        hsync_o = 0;
    end else begin
        hsync_o = 1;
    end
    if (vsync_timer_o > 10'd489 && vsync_timer_o < 492) begin
        vsync_o = 0;
    end else begin
        vsync_o = 1;
    end
end

assign position_y_o = vsync_timer_o[9:0];

endmodule
