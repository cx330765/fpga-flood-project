module video_osd_baseline #(
    parameter PANEL_X = 8,
    parameter PANEL_Y = 8,
    parameter PANEL_W = 88,
    parameter PANEL_H = 84
)(
    input wire pixel_clk, input wire reset,
    input wire [23:0] rgb_in, input wire hs_in, input wire vs_in, input wire de_in,
    input wire [1:0] image_index,
    input wire [15:0] source_width, input wire [15:0] source_height,
    input wire auto_play_status, input wire load_busy_status,
    input wire [3:0] brightness_level, input wire [3:0] contrast_level,
    input wire [3:0] saturation_level,
    input wire adjust_mode, input wire saturation_mode, input wire osd_enable,
    input wire auto_brightness_mode, input wire time_set_mode,
    input wire [4:0] clock_hour,
    input wire [5:0] clock_minute, input wire [5:0] clock_second,
    output reg [23:0] rgb_out, output reg hs_out, output reg vs_out, output reg de_out
);
    // Five 16-pixel rows are packed tightly into an 84-pixel panel.  The old
    // 98-pixel panel covered too much of the source image at the top-left.
    localparam TIME_Y = PANEL_Y + 2;
    localparam IMAGE_Y = PANEL_Y + 18;
    localparam BRIGHT_Y = PANEL_Y + 34;
    localparam CONTRAST_Y = PANEL_Y + 50;
    localparam RESOLUTION_Y = PANEL_Y + 66;
    localparam LABEL_X = PANEL_X + 6;
    localparam TENS_X = PANEL_X + 26;
    localparam ONES_X = PANEL_X + 36;
    localparam AUTO_X = PANEL_X + 54;
    localparam TIME_X = PANEL_X + 6;

    reg [10:0] x_cnt;
    reg [9:0] y_cnt;
    reg de_d, vs_d;
    reg [3:0] brightness_tens, brightness_ones;
    reg [3:0] contrast_tens, contrast_ones;
    reg [3:0] saturation_tens, saturation_ones;
    reg brightness_tens_valid, contrast_tens_valid, saturation_tens_valid;
    reg [23:0] border_color;
    reg [3:0] time_digit_code;
    reg [3:0] resolution_digit_code;
    reg [7:0] resolution_ascii_code;

    wire [3:0] image_digit = {2'b00, image_index} + 4'd1;
    wire [3:0] hour_tens = clock_hour / 10;
    wire [3:0] hour_ones = clock_hour % 10;
    wire [3:0] minute_tens = clock_minute / 10;
    wire [3:0] minute_ones = clock_minute % 10;
    wire [3:0] second_tens = clock_second / 10;
    wire [3:0] second_ones = clock_second % 10;
    wire [3:0] width_thousands = source_width / 1000;
    wire [3:0] width_hundreds = (source_width % 1000) / 100;
    wire [3:0] width_tens = (source_width % 100) / 10;
    wire [3:0] width_ones = source_width % 10;
    wire [3:0] height_hundreds = source_height / 100;
    wire [3:0] height_tens = (source_height % 100) / 10;
    wire [3:0] height_ones = source_height % 10;

    wire panel_area = osd_enable && de_in && x_cnt >= PANEL_X &&
        x_cnt < PANEL_X + PANEL_W && y_cnt >= PANEL_Y && y_cnt < PANEL_Y + PANEL_H;
    wire border_area = panel_area && (x_cnt < PANEL_X + 2 ||
        x_cnt >= PANEL_X + PANEL_W - 2 || y_cnt < PANEL_Y + 2 ||
        y_cnt >= PANEL_Y + PANEL_H - 2);

    wire time_area = panel_area && x_cnt >= TIME_X && x_cnt < TIME_X + 64 &&
        y_cnt >= TIME_Y && y_cnt < TIME_Y + 16;
    wire [2:0] time_character_index = (x_cnt - TIME_X) >> 3;
    wire [2:0] time_font_column = x_cnt - TIME_X;
    wire [3:0] time_font_row = y_cnt - TIME_Y;
    wire time_is_colon = (time_character_index == 3'd2 || time_character_index == 3'd5);
    wire selected_time_field = time_set_mode &&
        ((!adjust_mode && time_character_index < 2) ||
         (adjust_mode && time_character_index >= 3 && time_character_index < 5));

    wire image_label_area = panel_area && x_cnt >= LABEL_X && x_cnt < LABEL_X + 8 &&
        y_cnt >= IMAGE_Y && y_cnt < IMAGE_Y + 16;
    wire bright_label_area = panel_area && x_cnt >= LABEL_X && x_cnt < LABEL_X + 8 &&
        y_cnt >= BRIGHT_Y && y_cnt < BRIGHT_Y + 16;
    wire contrast_label_area = panel_area && x_cnt >= LABEL_X && x_cnt < LABEL_X + 8 &&
        y_cnt >= CONTRAST_Y && y_cnt < CONTRAST_Y + 16;
    wire image_digit_area = panel_area && x_cnt >= ONES_X && x_cnt < ONES_X + 8 &&
        y_cnt >= IMAGE_Y && y_cnt < IMAGE_Y + 16;
    wire bright_tens_area = panel_area && brightness_tens_valid &&
        x_cnt >= TENS_X && x_cnt < TENS_X + 8 && y_cnt >= BRIGHT_Y && y_cnt < BRIGHT_Y + 16;
    wire bright_ones_area = panel_area && x_cnt >= ONES_X && x_cnt < ONES_X + 8 &&
        y_cnt >= BRIGHT_Y && y_cnt < BRIGHT_Y + 16;
    wire contrast_tens_area = panel_area && contrast_tens_valid &&
        x_cnt >= TENS_X && x_cnt < TENS_X + 8 && y_cnt >= CONTRAST_Y && y_cnt < CONTRAST_Y + 16;
    wire contrast_ones_area = panel_area && x_cnt >= ONES_X && x_cnt < ONES_X + 8 &&
        y_cnt >= CONTRAST_Y && y_cnt < CONTRAST_Y + 16;
    wire auto_label_area = panel_area && auto_brightness_mode &&
        x_cnt >= AUTO_X && x_cnt < AUTO_X + 8 && y_cnt >= BRIGHT_Y && y_cnt < BRIGHT_Y + 16;
    wire saturation_label_area = panel_area && saturation_mode &&
        x_cnt >= LABEL_X && x_cnt < LABEL_X + 8 &&
        y_cnt >= RESOLUTION_Y && y_cnt < RESOLUTION_Y + 16;
    wire saturation_tens_area = panel_area && saturation_mode && saturation_tens_valid &&
        x_cnt >= TENS_X && x_cnt < TENS_X + 8 &&
        y_cnt >= RESOLUTION_Y && y_cnt < RESOLUTION_Y + 16;
    wire saturation_ones_area = panel_area && saturation_mode &&
        x_cnt >= ONES_X && x_cnt < ONES_X + 8 &&
        y_cnt >= RESOLUTION_Y && y_cnt < RESOLUTION_Y + 16;

    // Resolution row: R0640x480 / R1024x768. It reports the original BMP dimensions;
    // HDMI output remains fixed at 640x480 after the bilinear scaler.
    wire resolution_area = panel_area && !saturation_mode &&
        x_cnt >= LABEL_X && x_cnt < LABEL_X + 72 &&
        y_cnt >= RESOLUTION_Y && y_cnt < RESOLUTION_Y + 16;
    wire [3:0] resolution_character_index = (x_cnt - LABEL_X) >> 3;
    wire [2:0] resolution_font_column = x_cnt - LABEL_X;
    wire [3:0] resolution_font_row = y_cnt - RESOLUTION_Y;
    wire resolution_is_digit = (resolution_character_index != 4'd0) &&
                               (resolution_character_index != 4'd5);

    wire time_set_marker = panel_area && time_set_mode &&
        x_cnt >= PANEL_X + 2 && x_cnt < PANEL_X + 5 && y_cnt >= TIME_Y && y_cnt < TIME_Y + 16;
    wire bright_selected_area = panel_area && !time_set_mode && !saturation_mode && !adjust_mode &&
        x_cnt >= PANEL_X + 2 && x_cnt < PANEL_X + 5 && y_cnt >= BRIGHT_Y && y_cnt < BRIGHT_Y + 16;
    wire contrast_selected_area = panel_area && !time_set_mode && adjust_mode &&
        x_cnt >= PANEL_X + 2 && x_cnt < PANEL_X + 5 && y_cnt >= CONTRAST_Y && y_cnt < CONTRAST_Y + 16;
    wire saturation_selected_area = panel_area && !time_set_mode && saturation_mode &&
        x_cnt >= PANEL_X + 2 && x_cnt < PANEL_X + 5 &&
        y_cnt >= RESOLUTION_Y && y_cnt < RESOLUTION_Y + 16;

    wire time_digit_bit, time_colon_bit;
    wire image_label_bit, bright_label_bit, contrast_label_bit, auto_label_bit;
    wire image_digit_bit, bright_tens_bit, bright_ones_bit;
    wire contrast_tens_bit, contrast_ones_bit;
    wire saturation_label_bit, saturation_tens_bit, saturation_ones_bit;
    wire resolution_digit_bit, resolution_ascii_bit;

    always @(*) begin
        brightness_tens_valid = (brightness_level >= 10);
        brightness_tens = brightness_tens_valid ? 4'd1 : 4'd0;
        brightness_ones = brightness_tens_valid ? brightness_level - 10 : brightness_level;
        contrast_tens_valid = (contrast_level >= 10);
        contrast_tens = contrast_tens_valid ? 4'd1 : 4'd0;
        contrast_ones = contrast_tens_valid ? contrast_level - 10 : contrast_level;
        saturation_tens_valid = (saturation_level >= 10);
        saturation_tens = saturation_tens_valid ? 4'd1 : 4'd0;
        saturation_ones = saturation_tens_valid ? saturation_level - 10 : saturation_level;

        case (time_character_index)
            3'd0: time_digit_code = hour_tens;
            3'd1: time_digit_code = hour_ones;
            3'd3: time_digit_code = minute_tens;
            3'd4: time_digit_code = minute_ones;
            3'd6: time_digit_code = second_tens;
            3'd7: time_digit_code = second_ones;
            default: time_digit_code = 0;
        endcase

        case (resolution_character_index)
            4'd1: resolution_digit_code = width_thousands;
            4'd2: resolution_digit_code = width_hundreds;
            4'd3: resolution_digit_code = width_tens;
            4'd4: resolution_digit_code = width_ones;
            4'd6: resolution_digit_code = height_hundreds;
            4'd7: resolution_digit_code = height_tens;
            4'd8: resolution_digit_code = height_ones;
            default: resolution_digit_code = 4'd0;
        endcase
        resolution_ascii_code = (resolution_character_index == 4'd0) ? 8'h52 : 8'h78;

        if (saturation_mode) border_color = 24'hFF40FF;
        else if (time_set_mode) border_color = 24'hFFFF00;
        else if (load_busy_status) border_color = 24'hFF4020;
        else if (auto_play_status) border_color = 24'h00FF40;
        else border_color = 24'h2080FF;
    end

    font_rom time_digit_rom(.character_code(time_digit_code), .row(time_font_row), .column(time_font_column), .font_bit(time_digit_bit));
    font_rom_ascii time_colon_rom(.character_code(8'h3A), .row(time_font_row), .column(time_font_column), .font_bit(time_colon_bit));
    font_rom_ascii image_label_rom(.character_code(8'h49), .row(y_cnt-IMAGE_Y), .column(x_cnt-LABEL_X), .font_bit(image_label_bit));
    font_rom_ascii bright_label_rom(.character_code(8'h42), .row(y_cnt-BRIGHT_Y), .column(x_cnt-LABEL_X), .font_bit(bright_label_bit));
    font_rom_ascii contrast_label_rom(.character_code(8'h43), .row(y_cnt-CONTRAST_Y), .column(x_cnt-LABEL_X), .font_bit(contrast_label_bit));
    font_rom_ascii auto_label_rom(.character_code(8'h41), .row(y_cnt-BRIGHT_Y), .column(x_cnt-AUTO_X), .font_bit(auto_label_bit));
    font_rom image_digit_rom(.character_code(image_digit), .row(y_cnt-IMAGE_Y), .column(x_cnt-ONES_X), .font_bit(image_digit_bit));
    font_rom bright_tens_rom(.character_code(brightness_tens), .row(y_cnt-BRIGHT_Y), .column(x_cnt-TENS_X), .font_bit(bright_tens_bit));
    font_rom bright_ones_rom(.character_code(brightness_ones), .row(y_cnt-BRIGHT_Y), .column(x_cnt-ONES_X), .font_bit(bright_ones_bit));
    font_rom contrast_tens_rom(.character_code(contrast_tens), .row(y_cnt-CONTRAST_Y), .column(x_cnt-TENS_X), .font_bit(contrast_tens_bit));
    font_rom contrast_ones_rom(.character_code(contrast_ones), .row(y_cnt-CONTRAST_Y), .column(x_cnt-ONES_X), .font_bit(contrast_ones_bit));
    font_rom_ascii saturation_label_rom(.character_code(8'h53), .row(y_cnt-RESOLUTION_Y), .column(x_cnt-LABEL_X), .font_bit(saturation_label_bit));
    font_rom saturation_tens_rom(.character_code(saturation_tens), .row(y_cnt-RESOLUTION_Y), .column(x_cnt-TENS_X), .font_bit(saturation_tens_bit));
    font_rom saturation_ones_rom(.character_code(saturation_ones), .row(y_cnt-RESOLUTION_Y), .column(x_cnt-ONES_X), .font_bit(saturation_ones_bit));
    font_rom resolution_digit_rom(.character_code(resolution_digit_code), .row(resolution_font_row), .column(resolution_font_column), .font_bit(resolution_digit_bit));
    font_rom_ascii resolution_ascii_rom(.character_code(resolution_ascii_code), .row(resolution_font_row), .column(resolution_font_column), .font_bit(resolution_ascii_bit));

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin x_cnt <= 0; y_cnt <= 0; de_d <= 0; vs_d <= 0; end
        else begin
            de_d <= de_in; vs_d <= vs_in;
            if (vs_in && !vs_d) begin x_cnt <= 0; y_cnt <= 0; end
            else begin
                if (de_in) x_cnt <= x_cnt + 1'b1; else x_cnt <= 0;
                if (de_d && !de_in) y_cnt <= y_cnt + 1'b1;
            end
        end
    end

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin rgb_out <= 0; hs_out <= 0; vs_out <= 0; de_out <= 0; end
        else begin
            hs_out <= hs_in; vs_out <= vs_in; de_out <= de_in;
            if (!de_in) rgb_out <= 24'h000000;
            else if (border_area) rgb_out <= border_color;
            else if (time_set_marker || bright_selected_area || contrast_selected_area ||
                     saturation_selected_area) rgb_out <= 24'hFFFF00;
            else if (time_area && (time_is_colon ? time_colon_bit : time_digit_bit))
                rgb_out <= selected_time_field ? 24'hFFFF00 : 24'h00FFFF;
            else if ((image_label_area && image_label_bit) ||
                     (bright_label_area && bright_label_bit) ||
                     (contrast_label_area && contrast_label_bit)) rgb_out <= 24'hFFFFFF;
            else if (auto_label_area && auto_label_bit) rgb_out <= 24'h00FF40;
            else if ((image_digit_area && image_digit_bit) ||
                     (bright_tens_area && bright_tens_bit) || (bright_ones_area && bright_ones_bit) ||
                     (contrast_tens_area && contrast_tens_bit) || (contrast_ones_area && contrast_ones_bit))
                rgb_out <= 24'h00FFFF;
            else if (saturation_label_area && saturation_label_bit)
                rgb_out <= 24'hFFFFFF;
            else if ((saturation_tens_area && saturation_tens_bit) ||
                     (saturation_ones_area && saturation_ones_bit))
                rgb_out <= 24'hFF80FF;
            else if (resolution_area && (resolution_is_digit ? resolution_digit_bit : resolution_ascii_bit))
                rgb_out <= 24'hFFFF00;
            else if (panel_area) rgb_out <= 24'h001020;
            else rgb_out <= rgb_in;
        end
    end
endmodule
