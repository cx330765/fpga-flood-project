// Emergency overlay aligned to the 640x480 evacuation-map BMP.
// Route A follows the solid main-exit path; route B follows the dotted backup
// path. The old generic full-width lines and repeated "EVAC" title are gone.
module emergency_overlay #(
    parameter integer SCREEN_W = 640,
    parameter integer SCREEN_H = 480,
    parameter integer COUNTDOWN_START = 30
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire        emergency_mode,
    input  wire        accessible_route, // compatibility name: 0=route A, 1=route B
    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    output reg         countdown_expired,
    output reg  [23:0] rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out
);

    reg [10:0] x_cnt;
    reg [9:0]  y_cnt;
    reg de_d, vs_d, emergency_d;
    reg [6:0] second_frame_count;
    reg [5:0] countdown;
    reg [4:0] flash_frame_count;
    reg       flash_on;
    reg [9:0] arrow_phase;

    wire frame_start = vs_in && !vs_d;
    wire route_b = accessible_route;
    // Read-only status for image-4 audio; the existing visible countdown and
    // all of its frame timing, reset and route behavior remain unchanged.
    // Register the decoded status before crossing clocks, avoiding glitches
    // from the multi-bit countdown comparator. This never drives the timer.
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) countdown_expired <= 1'b0;
        else countdown_expired <= emergency_mode && (countdown == 6'd0);
    end

    // Coordinates are aligned to the newest 04_evac_v2.bmp after it is scaled
    // to 640x480.  Both routes leave the same red current-position marker and
    // finish at the single outdoor assembly point.
    reg [10:0] marker_x;
    reg [9:0]  marker_y;
    reg [1:0]  marker_dir; // 0=right, 1=up, 2=down
    integer    route_pos;

    always @(*) begin
        marker_x   = 11'd254;
        marker_y   = 10'd345;
        marker_dir = 2'd1;
        route_pos  = arrow_phase;

        if (!route_b) begin
            // Route A: current point -> upper corridor -> exit A -> down to
            // the common outdoor assembly point. Total length: 618 pixels.
            if (route_pos >= 618)
                route_pos = route_pos - 618;
            if (route_pos < 169) begin
                marker_x   = 11'd254;
                marker_y   = 10'd345 - route_pos;
                marker_dir = 2'd1;
            end else if (route_pos < 414) begin
                marker_x   = 11'd254 + (route_pos - 169);
                marker_y   = 10'd176;
                marker_dir = 2'd0;
            end else if (route_pos < 494) begin
                marker_x   = 11'd499 + (route_pos - 414);
                marker_y   = 10'd176;
                marker_dir = 2'd0;
            end else begin
                marker_x   = 11'd579;
                marker_y   = 10'd176 + (route_pos - 494);
                marker_dir = 2'd2;
            end
        end else begin
            // Route B: shared start -> cyan accessible branch -> exit B ->
            // the same assembly point. Total length: 431 pixels.
            if (route_pos >= 431)
                route_pos = route_pos - 431;
            if (route_pos < 50) begin
                marker_x   = 11'd254;
                marker_y   = 10'd345 - route_pos;
                marker_dir = 2'd1;
            end else if (route_pos < 152) begin
                marker_x   = 11'd254 + (route_pos - 50);
                marker_y   = 10'd295;
                marker_dir = 2'd0;
            end else if (route_pos < 208) begin
                marker_x   = 11'd356;
                marker_y   = 10'd295 + (route_pos - 152);
                marker_dir = 2'd2;
            end else begin
                marker_x   = 11'd356 + (route_pos - 208);
                marker_y   = 10'd351;
                marker_dir = 2'd0;
            end
        end
    end

    function arrow_right;
        input [10:0] px;
        input [9:0]  py;
        input [10:0] center_x;
        input [9:0]  center_y;
        integer dx;
        integer dy;
        begin
            dx = px - center_x;
            if (py >= center_y) dy = py - center_y;
            else dy = center_y - py;
            arrow_right = ((dx >= -10 && dx <= 5 && dy <= 2) ||
                           (dx >= 0 && dx <= 10 && dy <= (10-dx)));
        end
    endfunction

    function arrow_up;
        input [10:0] px;
        input [9:0]  py;
        input [10:0] center_x;
        input [9:0]  center_y;
        integer dx;
        integer dy;
        integer adx;
        begin
            dx = px - center_x;
            dy = py - center_y;
            if (dx < 0) adx = -dx; else adx = dx;
            arrow_up = ((dy >= -5 && dy <= 10 && adx <= 2) ||
                        (dy >= -10 && dy <= 0 && adx <= (10+dy)));
        end
    endfunction

    function arrow_down;
        input [10:0] px;
        input [9:0]  py;
        input [10:0] center_x;
        input [9:0]  center_y;
        integer dx;
        integer dy;
        integer adx;
        begin
            dx = px - center_x;
            dy = py - center_y;
            if (dx < 0) adx = -dx; else adx = dx;
            arrow_down = ((dy >= -10 && dy <= 5 && adx <= 2) ||
                          (dy >= 0 && dy <= 10 && adx <= (10-dy)));
        end
    endfunction

    wire marker_arrow = (marker_dir == 2'd1) ?
                        arrow_up(x_cnt,y_cnt,marker_x,marker_y) :
                        (marker_dir == 2'd2) ?
                        arrow_down(x_cnt,y_cnt,marker_x,marker_y) :
                        arrow_right(x_cnt,y_cnt,marker_x,marker_y);
    wire arrow_pixel = de_in && marker_arrow;
    wire [23:0] arrow_color = route_b ? 24'h00E8FF : 24'hFFFF20;

    wire border_area = de_in &&
        (x_cnt < 4 || x_cnt >= SCREEN_W-4 || y_cnt < 4 || y_cnt >= SCREEN_H-4);

    // Emergency countdown in the black area at the upper-right of image 4.
    // Each 8x16 digit is enlarged 2x to 16x32 pixels below a Chinese title. The yellow
    // digits sit inside a thick red frame; route A/B remains distinguishable
    // by the yellow/cyan moving arrow.
    wire [3:0] count_tens = (countdown >= 30) ? 4'd3 :
                            (countdown >= 20) ? 4'd2 :
                            (countdown >= 10) ? 4'd1 : 4'd0;
    wire [5:0] tens_value = (count_tens == 4'd3) ? 6'd30 :
                            (count_tens == 4'd2) ? 6'd20 :
                            (count_tens == 4'd1) ? 6'd10 : 6'd0;
    wire [3:0] count_ones = countdown - tens_value;

    localparam integer COUNTDOWN_X = 568;
    localparam integer COUNTDOWN_Y = 108;
    localparam integer FRAME_X0    = 544;
    localparam integer FRAME_X1    = 636;
    localparam integer FRAME_Y0    = 84;
    localparam integer FRAME_Y1    = 144;
    wire countdown_border = de_in &&
        x_cnt >= FRAME_X0 && x_cnt < FRAME_X1 &&
        y_cnt >= FRAME_Y0 && y_cnt < FRAME_Y1 &&
        (x_cnt < FRAME_X0+4 || x_cnt >= FRAME_X1-4 ||
         y_cnt < FRAME_Y0+4 || y_cnt >= FRAME_Y1-4);
    wire tens_area = de_in && x_cnt >= COUNTDOWN_X && x_cnt < COUNTDOWN_X+16 &&
                     y_cnt >= COUNTDOWN_Y && y_cnt < COUNTDOWN_Y+32;
    wire ones_area = de_in && x_cnt >= COUNTDOWN_X+24 && x_cnt < COUNTDOWN_X+40 &&
                     y_cnt >= COUNTDOWN_Y && y_cnt < COUNTDOWN_Y+32;
    wire [2:0] count_col = tens_area ? ((x_cnt-COUNTDOWN_X)>>1) :
                                      ((x_cnt-(COUNTDOWN_X+24))>>1);
    wire [3:0] status_row = (y_cnt-COUNTDOWN_Y) >> 1;
    wire tens_bit, ones_bit;

    wire label_area=de_in && x_cnt>=548 && x_cnt<628 && y_cnt>=88 && y_cnt<104;
    wire [10:0] label_x=x_cnt-548;
    wire [9:0] label_y=y_cnt-88;
    reg [5:0] label_code;
    always @(*) begin
        label_code=6'd63;
        case(label_x[6:4])
            3'd0: label_code=6'd18;
            3'd1: label_code=6'd19;
            3'd2: label_code=6'd20;
            3'd3: label_code=6'd21;
            3'd4: label_code=6'd22;
            default: label_code=6'd63;
        endcase
    end
    wire label_bit;
    shelter_cn_font u_count_label(.code(label_code),.row(label_y[3:0]),.col(label_x[3:0]),.bit_on(label_bit));
    wire countdown_panel=de_in && x_cnt>=FRAME_X0 && x_cnt<FRAME_X1 && y_cnt>=FRAME_Y0 && y_cnt<FRAME_Y1;

    font_rom count_tens_rom(
        .character_code(count_tens), .row(status_row), .column(count_col), .font_bit(tens_bit));
    font_rom count_ones_rom(
        .character_code(count_ones), .row(status_row), .column(count_col), .font_bit(ones_bit));

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            x_cnt <= 0; y_cnt <= 0; de_d <= 0; vs_d <= 0;
        end else begin
            de_d <= de_in;
            vs_d <= vs_in;
            if (frame_start) begin
                x_cnt <= 0;
                y_cnt <= 0;
            end else begin
                if (de_in) x_cnt <= x_cnt + 1'b1;
                else x_cnt <= 0;
                if (de_d && !de_in) y_cnt <= y_cnt + 1'b1;
            end
        end
    end

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            emergency_d <= 1'b0;
            second_frame_count <= 0;
            countdown <= COUNTDOWN_START;
            flash_frame_count <= 0;
            flash_on <= 1'b1;
            arrow_phase <= 0;
        end else begin
            emergency_d <= emergency_mode;
            if (!emergency_mode || !emergency_d) begin
                second_frame_count <= 0;
                countdown <= COUNTDOWN_START;
                flash_frame_count <= 0;
                flash_on <= 1'b1;
                arrow_phase <= 0;
            end else if (frame_start) begin
                if (second_frame_count >= 7'd59) begin
                    second_frame_count <= 0;
                    if (countdown != 0) countdown <= countdown - 1'b1;
                end else second_frame_count <= second_frame_count + 1'b1;

                if (flash_frame_count >= 5'd14) begin
                    flash_frame_count <= 0;
                    flash_on <= ~flash_on;
                end else flash_frame_count <= flash_frame_count + 1'b1;

                if ((!route_b && arrow_phase >= 10'd613) ||
                    ( route_b && arrow_phase >= 10'd426))
                    arrow_phase <= 0;
                else
                    arrow_phase <= arrow_phase + 3'd5;
            end
        end
    end

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; hs_out <= 0; vs_out <= 0; de_out <= 0;
        end else begin
            hs_out <= hs_in;
            vs_out <= vs_in;
            de_out <= de_in;
            if (!de_in) rgb_out <= 24'h000000;
            else if (!emergency_mode) rgb_out <= rgb_in;
            else if (border_area) rgb_out <= flash_on ? 24'hFF2020 : 24'hFFFFFF;
            else if (label_area && label_bit) rgb_out <= 24'hFFFF00;
            else if (countdown_border) rgb_out <= 24'hFF2020;
            // Keep the referenced upper-right style.  At 10 seconds and below,
            // change from yellow to flashing red/white to make the deadline clear.
            else if ((tens_area && tens_bit) || (ones_area && ones_bit))
                rgb_out <= (countdown <= 6'd10) ?
                           (flash_on ? 24'hFF2020 : 24'hFFFFFF) : 24'hFFFF00;
            else if (countdown_panel) rgb_out <= 24'h081018;
            else if (arrow_pixel) rgb_out <= arrow_color;
            else rgb_out <= rgb_in;
        end
    end
endmodule
