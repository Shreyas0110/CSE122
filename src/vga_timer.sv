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
