/*
 * DVD Screensaver - Bouncing DVD logo on VGA display
 * Connects to vga_timer module
 * 640x480 VGA @ 25MHz pixel clock
 */

`default_nettype none

// ──────────────────────────────────────────────
//  DVD Logo Bitmap  (40 wide × 20 tall, 1‑bit)
//  Simple pixel‑art "DVD" text block
// ──────────────────────────────────────────────
module dvd_logo_rom (
    input  logic [5:0] col,   // 0‑39
    input  logic [4:0] row,   // 0‑19
    output logic       pixel
);
    // Each row is 40 bits stored as two 20‑bit halves (MSB = leftmost pixel)
    logic [39:0] bitmap [0:19];

    always_comb begin
        // Row 0
        bitmap[ 0] = 40'b1111111111111111111111111111111111111111;
        bitmap[ 1] = 40'b1000000000000000000000000000000000000001;
        bitmap[ 2] = 40'b1011111100001100001100111111000000000001;
        bitmap[ 3] = 40'b1011000110001100001100110001100000000001;
        bitmap[ 4] = 40'b1011000011000110011000110000110000000001;
        bitmap[ 5] = 40'b1011000011000110011000110000110000000001;
        bitmap[ 6] = 40'b1011000011000011110000110000110000000001;
        bitmap[ 7] = 40'b1011000011000011110000110000110000000001;
        bitmap[ 8] = 40'b1011000110000001100000110001100000000001;
        bitmap[ 9] = 40'b1011111100000001100000111111000000000001;
        bitmap[10] = 40'b1000000000000000000000000000000000000001;
        bitmap[11] = 40'b1111111111111111111111111111111111111111;
        bitmap[12] = 40'b0000000000000000000000000000000000000000;
        bitmap[13] = 40'b0000000000000000000000000000000000000000;
        bitmap[14] = 40'b0000000000000000000000000000000000000000;
        bitmap[15] = 40'b0000000000000000000000000000000000000000;
        bitmap[16] = 40'b0000000000000000000000000000000000000000;
        bitmap[17] = 40'b0000000000000000000000000000000000000000;
        bitmap[18] = 40'b0000000000000000000000000000000000000000;
        bitmap[19] = 40'b0000000000000000000000000000000000000000;

        pixel = bitmap[row][39 - col];

        pixel = bitmap[row][39 - col];
    end
endmodule


// ──────────────────────────────────────────────
//  Colour palette – cycles on each corner bounce
// ──────────────────────────────────────────────
module colour_palette (
    input  logic [2:0] idx,
    output logic [1:0] r,
    output logic [1:0] g,
    output logic [1:0] b
);
    always_comb begin
        case (idx)
            3'd0: begin r=2'b11; g=2'b00; b=2'b00; end // red
            3'd1: begin r=2'b00; g=2'b11; b=2'b00; end // green
            3'd2: begin r=2'b00; g=2'b00; b=2'b11; end // blue
            3'd3: begin r=2'b11; g=2'b11; b=2'b00; end // yellow
            3'd4: begin r=2'b11; g=2'b00; b=2'b11; end // magenta
            3'd5: begin r=2'b00; g=2'b11; b=2'b11; end // cyan
            3'd6: begin r=2'b11; g=2'b10; b=2'b00; end // orange
            3'd7: begin r=2'b10; g=2'b00; b=2'b11; end // purple
        endcase
    end
endmodule


