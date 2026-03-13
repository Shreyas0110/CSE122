/*
 * DVD Screensaver - Bouncing DVD logo on VGA display
 * Connects to vga_timer module
 * 640x480 VGA @ 25MHz pixel clock
 */

`default_nettype none

// ──────────────────────────────────────────────
//  DVD Logo Bitmap  (40 wide × 20 tall, 1‑bit)
//  Flat case statement — synthesis-friendly ROM
// ──────────────────────────────────────────────
module dvd_logo_rom (
    input  logic [5:0] col,   // 0‑39
    input  logic [4:0] row,   // 0‑19
    output logic       pixel
);
    // Rows 0-11: bordered box with D V D letters
    // Rows 12-19: blank (black)
    //
    // ████████████████████████████████████████  row 0
    // █                                      █  row 1
    // █ ██████    ██    ██  ██████           █  row 2
    // █ ██   ██   ██    ██  ██   ██          █  row 3
    // █ ██    ██   ██  ██   ██    ██         █  row 4
    // █ ██    ██    ████    ██    ██         █  row 5-7
    // █ ██   ██      ██     ██   ██          █  row 8
    // █ ██████       ██     ██████           █  row 9
    // █                                      █  row 10
    // ████████████████████████████████████████  row 11

    logic [39:0] row_bits;

    always_comb begin
        case (row)
            5'd0:  row_bits = 40'b1111111111111111111111111111111111111111;
            5'd1:  row_bits = 40'b1000000000000000000000000000000000000001;
            5'd2:  row_bits = 40'b1011111100001100001100111111000000000001;
            5'd3:  row_bits = 40'b1011000110001100001100110001100000000001;
            5'd4:  row_bits = 40'b1011000011000110011000110000110000000001;
            5'd5:  row_bits = 40'b1011000011000110011000110000110000000001;
            5'd6:  row_bits = 40'b1011000011000011110000110000110000000001;
            5'd7:  row_bits = 40'b1011000011000011110000110000110000000001;
            5'd8:  row_bits = 40'b1011000110000001100000110001100000000001;
            5'd9:  row_bits = 40'b1011111100000001100000111111000000000001;
            5'd10: row_bits = 40'b1000000000000000000000000000000000000001;
            5'd11: row_bits = 40'b1111111111111111111111111111111111111111;
            default: row_bits = 40'b0;
        endcase
        pixel = row_bits[39 - col];
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