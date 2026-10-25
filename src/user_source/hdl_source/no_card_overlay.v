// Missing-card overlay. The message is steady; only the border changes shade.
module no_card_overlay #(
    parameter integer MSG_SCALE = 3,
    parameter integer BORDER_HALF_FRAMES = 60
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire        no_card,
    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    output reg  [23:0] rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out
);
    // Four complete 16x16 glyphs: U+65E0, T, F, U+5361 ("无TF卡").
    localparam integer MSG_W = 4 * 16 * MSG_SCALE;
    localparam integer MSG_H = 16 * MSG_SCALE;
    localparam integer X0 = (640 - MSG_W) / 2;
    localparam integer Y0 = (480 - MSG_H) / 2;
    localparam integer PAD = 16;
    localparam [23:0] COL_TEXT = 24'hFFFFFF;
    localparam [23:0] COL_BOX = 24'h101820;
    localparam [23:0] COL_EDGE_BRIGHT = 24'h38BBD0;
    localparam [23:0] COL_EDGE_DIM = 24'h205460;

    reg nc_sync0, nc_sync1, nc_frame;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin nc_sync0 <= 0; nc_sync1 <= 0; end
        else begin nc_sync0 <= no_card; nc_sync1 <= nc_sync0; end
    end

    reg [9:0] x_cnt, y_cnt;
    reg de_d, vs_d;
    wire frame_start = vs_in && !vs_d;
    wire line_start = de_in && !de_d;
    wire line_end = !de_in && de_d;
    // Current pixel is zero on the FIRST active sample; following samples use
    // the next-x register. Advance y at line END, so the first active line is 0.
    wire [9:0] pixel_x = line_start ? 10'd0 : x_cnt;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            x_cnt <= 0; y_cnt <= 0; de_d <= 0; vs_d <= 0; nc_frame <= 0;
        end else begin
            de_d <= de_in; vs_d <= vs_in;
            if (frame_start) begin
                x_cnt <= 0; y_cnt <= 0; nc_frame <= nc_sync1;
            end else begin
                if (de_in) x_cnt <= pixel_x + 10'd1;
                else x_cnt <= 0;
                if (line_end) y_cnt <= y_cnt + 10'd1;
            end
        end
    end

    // One increment per frame, not both VS edges. At ~60 fps the default is
    // one second per shade, a two-second full border cycle (~0.5 Hz).
    localparam integer BORDER_COUNT_BITS =
        (BORDER_HALF_FRAMES <= 1) ? 1 : $clog2(BORDER_HALF_FRAMES);
    reg [BORDER_COUNT_BITS-1:0] border_count;
    reg border_dim;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin border_count <= 0; border_dim <= 0; end
        else if (frame_start) begin
            if (!nc_sync1 || !nc_frame) begin border_count <= 0; border_dim <= 0; end
            else if (border_count == BORDER_HALF_FRAMES - 1) begin
                border_count <= 0; border_dim <= ~border_dim;
            end else border_count <= border_count + 1'b1;
        end
    end

    wire in_text_x = pixel_x >= X0 && pixel_x < X0 + MSG_W;
    wire in_text_y = y_cnt >= Y0 && y_cnt < Y0 + MSG_H;
    wire box_area = nc_frame && de_in &&
        pixel_x >= X0-PAD && pixel_x < X0+MSG_W+PAD &&
        y_cnt >= Y0-PAD && y_cnt < Y0+MSG_H+PAD;
    wire perimeter = box_area &&
        (pixel_x < X0-PAD+2 || pixel_x >= X0+MSG_W+PAD-2 ||
         y_cnt < Y0-PAD+2 || y_cnt >= Y0+MSG_H+PAD-2);

    // Cursors avoid constant dividers. All 16 font rows are traversed, rather
    // than feeding an 8-row cursor into the old vertically doubled ASCII ROM.
    localparam integer SUB_BITS = (MSG_SCALE <= 1) ? 1 : $clog2(MSG_SCALE);
    reg [SUB_BITS-1:0] gsub, rsub;
    reg [3:0] gcol, grow;
    reg [1:0] gchar;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin gsub <= 0; gcol <= 0; gchar <= 0; end
        else if (frame_start || !de_in || !in_text_x) begin
            gsub <= 0; gcol <= 0; gchar <= 0;
        end else if (gsub == MSG_SCALE - 1) begin
            gsub <= 0;
            if (gcol == 15) begin
                gcol <= 0;
                if (gchar < 3) gchar <= gchar + 1'b1;
            end else gcol <= gcol + 1'b1;
        end else gsub <= gsub + 1'b1;
    end
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin rsub <= 0; grow <= 0; end
        else if (frame_start) begin rsub <= 0; grow <= 0; end
        else if (line_end) begin
            if (!in_text_y) begin rsub <= 0; grow <= 0; end
            else if (rsub == MSG_SCALE - 1) begin
                rsub <= 0;
                if (grow < 15) grow <= grow + 1'b1;
            end else rsub <= rsub + 1'b1;
        end
    end

    function [15:0] message_row;
        input [1:0] character;
        input [3:0] row;
        begin
            case ({character,row})
                6'd0: message_row = 16'h7FFE;
6'd1: message_row = 16'h0380;
6'd2: message_row = 16'h0380;
6'd3: message_row = 16'h0380;
6'd4: message_row = 16'hFFFF;
6'd5: message_row = 16'hFFFF;
6'd6: message_row = 16'h0300;
6'd7: message_row = 16'h03C0;
6'd8: message_row = 16'h07C0;
6'd9: message_row = 16'h0EC0;
6'd10: message_row = 16'h0EC6;
6'd11: message_row = 16'h3CC7;
6'd12: message_row = 16'h78E7;
6'd13: message_row = 16'h70FE;
6'd14: message_row = 16'h207C;
6'd15: message_row = 16'h0000;
6'd16: message_row = 16'h0000;
6'd17: message_row = 16'h0000;
6'd18: message_row = 16'h1FF8;
6'd19: message_row = 16'h1FF8;
6'd20: message_row = 16'h0180;
6'd21: message_row = 16'h0180;
6'd22: message_row = 16'h0180;
6'd23: message_row = 16'h0180;
6'd24: message_row = 16'h0180;
6'd25: message_row = 16'h0180;
6'd26: message_row = 16'h0180;
6'd27: message_row = 16'h0180;
6'd28: message_row = 16'h0180;
6'd29: message_row = 16'h0180;
6'd30: message_row = 16'h0000;
6'd31: message_row = 16'h0000;
6'd32: message_row = 16'h0000;
6'd33: message_row = 16'h0000;
6'd34: message_row = 16'h0FE0;
6'd35: message_row = 16'h0FE0;
6'd36: message_row = 16'h0E00;
6'd37: message_row = 16'h0E00;
6'd38: message_row = 16'h0E00;
6'd39: message_row = 16'h0FE0;
6'd40: message_row = 16'h0FE0;
6'd41: message_row = 16'h0E00;
6'd42: message_row = 16'h0E00;
6'd43: message_row = 16'h0E00;
6'd44: message_row = 16'h0E00;
6'd45: message_row = 16'h0E00;
6'd46: message_row = 16'h0000;
6'd47: message_row = 16'h0000;
6'd48: message_row = 16'h0380;
6'd49: message_row = 16'h0380;
6'd50: message_row = 16'h03FE;
6'd51: message_row = 16'h03FE;
6'd52: message_row = 16'h0380;
6'd53: message_row = 16'h0380;
6'd54: message_row = 16'hFFFF;
6'd55: message_row = 16'hFFFF;
6'd56: message_row = 16'h0380;
6'd57: message_row = 16'h03E0;
6'd58: message_row = 16'h03F8;
6'd59: message_row = 16'h03BC;
6'd60: message_row = 16'h039E;
6'd61: message_row = 16'h0384;
6'd62: message_row = 16'h0380;
6'd63: message_row = 16'h0380;
                default: message_row = 16'h0000;
            endcase
        end
    endfunction
    wire [15:0] glyph_row = message_row(gchar,grow);
    wire text_pixel = box_area && in_text_x && in_text_y && glyph_row[15-gcol];

    // Keep the original one-pixel RGB/HS/VS/DE latency and direct bypass.
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin rgb_out <= 0; hs_out <= 0; vs_out <= 0; de_out <= 0; end
        else begin
            hs_out <= hs_in; vs_out <= vs_in; de_out <= de_in;
            if (text_pixel) rgb_out <= COL_TEXT;
            else if (perimeter) rgb_out <= border_dim ? COL_EDGE_DIM : COL_EDGE_BRIGHT;
            else if (box_area) rgb_out <= COL_BOX;
            else rgb_out <= rgb_in;
        end
    end
endmodule
