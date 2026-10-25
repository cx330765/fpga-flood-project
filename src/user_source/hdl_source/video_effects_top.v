module video_effects_top #(
    parameter integer GROUPED_MENU_ENABLE = 0,
    parameter integer CONTROL_CLK_FREQ_HZ = 50_000_000,
    parameter integer KEY_DEBOUNCE_MS    = 20,
    parameter integer SCREEN_WIDTH       = 640,
    parameter integer SCROLL_TEXT_Y      = 432,
    parameter integer SCROLL_START_X     = 640,
    parameter integer SCROLL_SPEED_DIV   = 2,
    parameter integer FADE_STEP_FRAMES   = 2,
    parameter [4:0] CLOCK_DEFAULT_HOUR   = 5'd12,
    parameter [5:0] CLOCK_DEFAULT_MINUTE = 6'd0,
    parameter [5:0] CLOCK_DEFAULT_SECOND = 6'd0
)(
    input  wire        pixel_clk,
    input  wire        control_clk,
    input  wire        reset_pixel,
    input  wire        reset_control,

    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,

    input wire [3:0] ui_brightness, ui_contrast, ui_saturation,
    input wire ui_adjust_mode, ui_saturation_mode, ui_auto_brightness, ui_time_set,
    input wire [4:0] ui_hour,
    input wire [5:0] ui_minute, ui_second,
    input wire ui_menu_active,
    input wire [3:0] ui_menu_item,
    input wire [9:0] ui_menu_value,
    input wire [1:0] ui_subtitle_speed,
    input  wire [1:0]  image_index,
    input  wire [15:0] source_width,
    input  wire [15:0] source_height,
    input  wire        auto_play_status,
    input  wire        load_busy_status,
    input  wire        fade_request_status,
    input  wire        emergency_mode_status,
    input  wire        accessible_route_status,
    input  wire        scroll_enable,
    input  wire        fade_enable,

    output wire [23:0] rgb_out,
    output wire        hs_out,
    output wire        vs_out,
    output wire        de_out,
    output wire [3:0]  brightness_level_status,
    output wire [3:0]  contrast_level_status,
    output wire [3:0]  saturation_level_status,
    output wire        adjust_mode_status,
    output wire        saturation_mode_status,
    output wire        auto_brightness_status,
    output wire        time_set_mode_status,
    output wire        time_set_mode_control,
    output wire [4:0]  clock_hour_status,
    output wire [5:0]  clock_minute_status,
    output wire [5:0]  clock_second_status,
    output wire [4:0]  fade_level_debug,
    output wire        emergency_countdown_expired
);

    reg [1:0] image_index_sync0;
    reg [1:0] image_index_sync1;
    reg [15:0] source_width_sync0;
    reg [15:0] source_width_sync1;
    reg [15:0] source_height_sync0;
    reg [15:0] source_height_sync1;
    reg       auto_sync0;
    reg       auto_sync1;
    reg       busy_sync0;
    reg       busy_sync1;
    reg       fade_request_sync0;
    reg       fade_request_sync1;
    reg       emergency_sync0;
    reg       emergency_mode;
    reg       accessible_sync0;
    reg       accessible_route;

    wire [3:0] brightness_raw, contrast_raw, saturation_raw;
    wire adjust_mode_raw, saturation_mode_raw, osd_enable_raw;
    wire auto_brightness_raw, time_set_mode_raw;
    wire [4:0] clock_hour_raw;
    wire [5:0] clock_minute_raw, clock_second_raw;
    reg menu_meta, menu_sync;
    reg [3:0] menu_item_meta, menu_item_sync;
    reg [9:0] menu_value_meta, menu_value_sync;
    reg [1:0] speed_meta, speed_sync;

    reg [3:0] brightness_sync0, brightness_level;
    reg [3:0] contrast_sync0, contrast_level;
    reg [3:0] saturation_sync0, saturation_level;
    reg adjust_sync0, adjust_mode;
    reg saturation_mode_sync0, saturation_mode;
    reg osd_sync0, osd_enable;
    reg auto_brightness_sync0, auto_brightness_mode;
    reg time_set_sync0, time_set_mode;
    reg [4:0] hour_sync0, clock_hour;
    reg [5:0] minute_sync0, clock_minute;
    reg [5:0] second_sync0, clock_second;

    wire [23:0] fade_rgb;
    wire        fade_hs;
    wire        fade_vs;
    wire        fade_de;

    wire [23:0] adjust_rgb;
    wire        adjust_hs;
    wire        adjust_vs;
    wire        adjust_de;

    wire [23:0] osd_rgb;
    wire        osd_hs;
    wire        osd_vs;
    wire        osd_de;
    wire [23:0] scroll_rgb;
    wire        scroll_hs;
    wire        scroll_vs;
    wire        scroll_de;

    assign brightness_level_status = brightness_level;
    assign contrast_level_status   = contrast_level;
    assign saturation_level_status = saturation_level;
    assign adjust_mode_status      = adjust_mode;
    assign saturation_mode_status  = saturation_mode;
    assign auto_brightness_status  = auto_brightness_mode;
    assign time_set_mode_status    = time_set_mode;
    // Use the original control-domain level for key arbitration, not its
    // delayed pixel-domain copy used for displaying the setting indicator.
    assign time_set_mode_control   = time_set_mode_raw;
    assign clock_hour_status       = clock_hour;
    assign clock_minute_status     = clock_minute;
    assign clock_second_status     = clock_second;

    // State signals originate in the SD-card clock domain and remain stable
    // for many video frames. Two registers make them safe for the pixel domain.
    always @(posedge pixel_clk or posedge reset_pixel) begin
        if (reset_pixel) begin
            image_index_sync0 <= 2'd0;
            image_index_sync1 <= 2'd0;
            source_width_sync0 <= 16'd640;
            source_width_sync1 <= 16'd640;
            source_height_sync0 <= 16'd480;
            source_height_sync1 <= 16'd480;
            auto_sync0        <= 1'b0;
            auto_sync1        <= 1'b0;
            busy_sync0        <= 1'b0;
            busy_sync1        <= 1'b0;
            fade_request_sync0 <= 1'b0;
            fade_request_sync1 <= 1'b0;
            emergency_sync0 <= 1'b0;
            emergency_mode <= 1'b0;
            accessible_sync0 <= 1'b0;
            accessible_route <= 1'b0;
        end
        else begin
            image_index_sync0 <= image_index;
            image_index_sync1 <= image_index_sync0;
            source_width_sync0 <= source_width;
            source_width_sync1 <= source_width_sync0;
            source_height_sync0 <= source_height;
            source_height_sync1 <= source_height_sync0;
            auto_sync0        <= auto_play_status;
            auto_sync1        <= auto_sync0;
            busy_sync0        <= load_busy_status;
            busy_sync1        <= busy_sync0;
            fade_request_sync0 <= fade_request_status;
            fade_request_sync1 <= fade_request_sync0;
            emergency_sync0 <= emergency_mode_status;
            emergency_mode <= emergency_sync0;
            accessible_sync0 <= accessible_route_status;
            accessible_route <= accessible_sync0;
        end
    end

    // Control values change very slowly. Two pixel-clock registers safely
    // transfer them from the 50 MHz control domain into the video domain.
    always @(posedge pixel_clk or posedge reset_pixel) begin
        if (reset_pixel) begin
            brightness_sync0 <= 4'd8; brightness_level <= 4'd8;
            contrast_sync0 <= 4'd8; contrast_level <= 4'd8;
            saturation_sync0 <= 4'd8; saturation_level <= 4'd8;
            adjust_sync0 <= 0; adjust_mode <= 0;
            saturation_mode_sync0 <= 0; saturation_mode <= 0;
            osd_sync0 <= 1; osd_enable <= 1;
            auto_brightness_sync0 <= 0; auto_brightness_mode <= 0;
            time_set_sync0 <= 0; time_set_mode <= 0;
            hour_sync0 <= CLOCK_DEFAULT_HOUR; clock_hour <= CLOCK_DEFAULT_HOUR;
            minute_sync0 <= CLOCK_DEFAULT_MINUTE; clock_minute <= CLOCK_DEFAULT_MINUTE;
            second_sync0 <= CLOCK_DEFAULT_SECOND; clock_second <= CLOCK_DEFAULT_SECOND;
            menu_meta <= 0; menu_sync <= 0;
            menu_item_meta <= 0; menu_item_sync <= 0;
            menu_value_meta <= 0; menu_value_sync <= 0;
            speed_meta<=1;speed_sync<=1;
        end
        else begin
            brightness_sync0 <= brightness_raw; brightness_level <= brightness_sync0;
            contrast_sync0 <= contrast_raw; contrast_level <= contrast_sync0;
            saturation_sync0 <= saturation_raw; saturation_level <= saturation_sync0;
            adjust_sync0 <= adjust_mode_raw; adjust_mode <= adjust_sync0;
            saturation_mode_sync0 <= saturation_mode_raw; saturation_mode <= saturation_mode_sync0;
            osd_sync0 <= osd_enable_raw; osd_enable <= osd_sync0;
            auto_brightness_sync0 <= auto_brightness_raw; auto_brightness_mode <= auto_brightness_sync0;
            time_set_sync0 <= time_set_mode_raw; time_set_mode <= time_set_sync0;
            hour_sync0 <= clock_hour_raw; clock_hour <= hour_sync0;
            minute_sync0 <= clock_minute_raw; clock_minute <= minute_sync0;
            second_sync0 <= clock_second_raw; clock_second <= second_sync0;
            menu_meta <= ui_menu_active; menu_sync <= menu_meta;
            menu_item_meta <= ui_menu_item; menu_item_sync <= menu_item_meta;
            menu_value_meta <= ui_menu_value; menu_value_sync <= menu_value_meta;
            speed_meta<=ui_subtitle_speed;speed_sync<=speed_meta;
        end
    end

    // All parameters now come from the single control-domain UI owner.
    assign brightness_raw = ui_brightness;
    assign contrast_raw = ui_contrast;
    assign saturation_raw = ui_saturation;
    assign adjust_mode_raw = ui_adjust_mode;
    assign saturation_mode_raw = ui_saturation_mode;
    assign osd_enable_raw = 1'b1;
    assign auto_brightness_raw = ui_auto_brightness;
    assign time_set_mode_raw = ui_time_set;
    assign clock_hour_raw = ui_hour;
    assign clock_minute_raw = ui_minute;
    assign clock_second_raw = ui_second;

    // Fade only the picture. OSD and banner remain crisp and readable.
    video_fade_smooth #(
        .STEP_FRAMES (FADE_STEP_FRAMES)
    ) fade_stage (
        .pixel_clk  (pixel_clk),
        .reset      (reset_pixel),
        .enable     (fade_enable),
        .load_busy  (fade_request_sync1),
        .rgb_in     (rgb_in),
        .hs_in      (hs_in),
        .vs_in      (vs_in),
        .de_in      (de_in),
        .rgb_out    (fade_rgb),
        .hs_out     (fade_hs),
        .vs_out     (fade_vs),
        .de_out     (fade_de),
        .fade_level (fade_level_debug)
    );

    video_adjust adjust_stage (
        .pixel_clk        (pixel_clk),
        .reset            (reset_pixel),
        .rgb_in           (fade_rgb),
        .hs_in            (fade_hs),
        .vs_in            (fade_vs),
        .de_in            (fade_de),
        .brightness_level (brightness_level),
        .contrast_level   (contrast_level),
        .saturation_level (saturation_level),
        .rgb_out          (adjust_rgb),
        .hs_out           (adjust_hs),
        .vs_out           (adjust_vs),
        .de_out           (adjust_de)
    );

    video_osd #(.GROUPED_MENU_ENABLE(GROUPED_MENU_ENABLE)) osd_stage (
        .pixel_clk        (pixel_clk),
        .reset            (reset_pixel),
        .rgb_in           (adjust_rgb),
        .hs_in            (adjust_hs),
        .vs_in            (adjust_vs),
        .de_in            (adjust_de),
        .image_index      (image_index_sync1),
        .source_width     (source_width_sync1),
        .source_height    (source_height_sync1),
        .auto_play_status (auto_sync1),
        .load_busy_status (busy_sync1),
        .brightness_level (brightness_level),
        .contrast_level   (contrast_level),
        .saturation_level (saturation_level),
        .adjust_mode      (adjust_mode),
        .saturation_mode  (saturation_mode),
        .osd_enable       (osd_enable),
        .auto_brightness_mode(auto_brightness_mode),
        .time_set_mode    (time_set_mode),
        .menu_active      (menu_sync),
        .menu_item        (menu_item_sync),
        .menu_value       (menu_value_sync),
        .clock_hour       (clock_hour),
        .clock_minute     (clock_minute),
        .clock_second     (clock_second),
        .rgb_out          (osd_rgb),
        .hs_out           (osd_hs),
        .vs_out           (osd_vs),
        .de_out           (osd_de)
    );

    scroll_text #(
        .RUNTIME_SPEED_ENABLE(GROUPED_MENU_ENABLE),
        .SCREEN_WIDTH (SCREEN_WIDTH),
        .TEXT_Y       (SCROLL_TEXT_Y),
        .START_X      (SCROLL_START_X),
        .SPEED_DIV    (SCROLL_SPEED_DIV)
    ) scroll_stage (
        .speed_level(speed_sync),
        .pixel_clk     (pixel_clk),
        .reset         (reset_pixel),
        .rgb_in        (osd_rgb),
        .hs_in         (osd_hs),
        .vs_in         (osd_vs),
        .de_in         (osd_de),
        // Keep the original scrolling caption in both normal and emergency
        // modes.  The separate shelter-status panel is hidden by the top
        // level during emergency mode.
        .scroll_enable (scroll_enable),
        .status_panel_visible (!emergency_mode),
        .rgb_out       (scroll_rgb),
        .hs_out        (scroll_hs),
        .vs_out        (scroll_vs),
        .de_out        (scroll_de)
    );

    emergency_overlay emergency_stage (
        .pixel_clk       (pixel_clk),
        .reset           (reset_pixel),
        .emergency_mode  (emergency_mode),
        .accessible_route(accessible_route),
        .rgb_in          (scroll_rgb),
        .hs_in           (scroll_hs),
        .vs_in           (scroll_vs),
        .de_in           (scroll_de),
        .countdown_expired(emergency_countdown_expired),
        .rgb_out         (rgb_out),
        .hs_out          (hs_out),
        .vs_out          (vs_out),
        .de_out          (de_out)
    );

endmodule
