
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // 实体 KEY2：短按切图，长按紧急模式
    input                       key2,           // 实体 KEY4：自动播放/紧急路线切换
    input                       key3,           // 实体 KEY3：长按菜单，菜单内短按增加
    input                       sw1,            // logical 1: exit A blocked
    input                       sw2,
    input                       sw3,
    input                       sw4,

    output [5:0]                seg_sel,
    output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;
// Change only this mask if the board's physical ON positions read low.
parameter [3:0] HAZARD_SWITCH_ACTIVE_LOW = 4'b0000;

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire sys_pll_clk0_unused;
wire sys_pll_lock;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;
wire video_pll_lock;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;

wire [3:0]  state_code;
wire [6:0]  seg_data_0;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;
wire [1:0]  current_image_index;
wire [15:0] current_source_width;
wire [15:0] current_source_height;
wire        auto_play_status;
wire        load_busy_status;
wire        fade_request_status;
wire        emergency_mode_status;
wire        accessible_route_status;
wire [3:0]  hazard_bits;
wire hazard_active, hazard_evacuation, hazard_both_blocked;
wire hazard_route_b, hazard_route_locked;
wire [2:0] hazard_reason;
reg hazard_wait_audio;
wire [3:0]  brightness_level_status;
wire [3:0]  contrast_level_status;
wire [3:0]  saturation_level_status;
wire        adjust_mode_status;
wire        saturation_mode_status;
wire        auto_brightness_status;
wire        time_set_mode_status;
wire        time_set_mode_control;
wire        key2_short_status, key2_long_status;
wire        key4_short_status, key4_long_status;
wire        ui_menu_active, ui_playback_pause;
wire [3:0]  ui_menu_item;
wire [9:0]  ui_menu_value;
wire [1:0] ui_volume_level, ui_subtitle_speed;
wire [2:0] ui_playback_order;
wire        ui_next_pulse, ui_emergency_pulse, ui_auto_route_pulse;
wire [3:0]  ui_brightness, ui_contrast, ui_saturation;
wire        ui_adjust_mode, ui_saturation_mode, ui_auto_brightness, ui_time_set;
wire [4:0]  ui_hour;
wire [5:0]  ui_minute, ui_second;
reg [1:0]  ui_fade_full_sync;
wire [4:0]  clock_hour_status;
wire [5:0]  clock_minute_status;
wire [5:0]  clock_second_status;
wire [4:0]  fade_level_debug;
wire        fade_black_ready_video;
reg  [1:0]  fade_black_sync_sd;
wire        fade_black_ready_sd;
wire [1:0]  shelter_edit_mode;
wire        shelter_edit_active;
wire [3:0]  shelter_people_hundreds;
wire [3:0]  shelter_people_tens;
wire [3:0]  shelter_people_ones;
wire [1:0]  shelter_material_state;
wire [1:0]  shelter_medical_state;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 音频发射相关
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_voice_done;
wire        emergency_countdown_expired;
reg  [1:0]  audio_done_sync_sd;
wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// Each clock domain gets asynchronous assertion and synchronous release.
// The picture/SDRAM/video path must not be reset by a momentary loss of the
// independent audio PLL lock; otherwise a harmless audio relock can erase the
// frame-buffer state and leave HDMI black or blue until another key reset.
wire rst_control;
wire rst_memory;
wire rst_video;
wire rst_audio;

// 保持你原来的 TF / SDRAM / video 时钟
sys_pll sys_pll_m0(
    .refclk     (clk),
    .extlock    (sys_pll_lock),
    .clk0_out   (sys_pll_clk0_unused),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .reset      (1'b0)
);

// The scaler's routed 100-MHz path did not meet timing.  Run the complete
// SD/BMP/scaler/write-FIFO domain from the board's stable 50-MHz clock.  SD SPI
// high speed becomes 12.5 MHz, which remains safely within card limits.
assign sd_card_clk = clk;

video_pll video_pll_m0(
    .refclk     (clk),
    .extlock    (video_pll_lock),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0)
);

// 复用你 I2S->HDMI 工程里的 PLL，只取 12.288MHz 音频主时钟
PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (1'b0),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);

reset_sync u_reset_control (
    .clk         (clk),
    .async_reset (~rst_n | ~sys_pll_lock),
    .reset_out   (rst_control)
);

reset_sync u_reset_memory (
    .clk         (ext_mem_clk),
    .async_reset (~rst_n | ~sys_pll_lock),
    .reset_out   (rst_memory)
);

reset_sync u_reset_video (
    .clk         (video_clk),
    .async_reset (~rst_n | ~video_pll_lock),
    .reset_out   (rst_video)
);

// Only the audio generator follows audio_pll_lock.  Loss of audio lock can
// mute/restart the tone without disturbing the image player.
reset_sync u_reset_audio (
    .clk         (audio_mclk),
    .async_reset (~rst_n | ~audio_pll_lock),
    .reset_out   (rst_audio)
);

// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_memory) begin
    if (rst_memory)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// The picture buffer is changed only after fade-out reaches black.  This
// level is synchronized back to the SD-control clock domain for a clean
// double-buffer commit handshake.
// Initial display release must coincide with the normal read-frame restart,
// so the read FIFO is refreshed from the now complete first buffer in blanking.
// Ordinary transitions retain the original black-level handshake unchanged.
assign fade_black_ready_video = (fade_level_debug == 5'd0) &&
                               (display_valid || video_read_req);
assign fade_black_ready_sd    = fade_black_sync_sd[1];
always @(posedge sd_card_clk or posedge rst_control) begin
    if (rst_control)
        fade_black_sync_sd <= 2'b00;
    else
        fade_black_sync_sd <= {fade_black_sync_sd[0], fade_black_ready_video};
end

// ===================== 实时安置点信息交互 =====================
// Physical KEY1 remains reset. Physical KEY2=key1, KEY3=key3, KEY4=key2.
// SW1=A blocked; SW2=B blocked; SW3=medical need; SW4=secondary danger.
always @(posedge clk or posedge rst_control) begin
    if (rst_control) hazard_wait_audio <= 1'b0;
    else hazard_wait_audio <= hazard_both_blocked;
end
hazard_policy #(.CLK_FREQ_HZ(50_000_000), .DEBOUNCE_MS(20),
    .SWITCH_ACTIVE_LOW(HAZARD_SWITCH_ACTIVE_LOW)) u_hazard_policy (
    .clk(clk), .reset(rst_control), .switches({sw4,sw3,sw2,sw1}),
    .hazards(hazard_bits), .active(hazard_active), .evacuation(hazard_evacuation),
    .all_exits_blocked(hazard_both_blocked), .route_b(hazard_route_b),
    .route_locked(hazard_route_locked), .reason(hazard_reason));
// Menu entry waits for a fully faded-in frame, not just load_busy=0.
always @(posedge clk or posedge rst_control) begin
    if (rst_control) ui_fade_full_sync <= 0;
    else ui_fade_full_sync <= {ui_fade_full_sync[0], (fade_level_debug == 5'd16)};
end
ui_controller #(
    .CLK_FREQ_HZ(50_000_000), .DEBOUNCE_MS(20), .HAZARD_POLICY_ENABLE(1), .GROUPED_MENU_ENABLE(1)
) u_ui_controller (
    .clk(clk), .reset(rst_control),
    .key2_n(key1), .key3_n(key3), .key4_n(key2),
    .emergency_mode(emergency_mode_status),
    .hazard_active(hazard_active),
    .player_ready(display_valid && !load_busy_status && !fade_request_status && ui_fade_full_sync[1]),
    .next_image_pulse(ui_next_pulse), .emergency_toggle_pulse(ui_emergency_pulse),
    .auto_or_route_pulse(ui_auto_route_pulse), .playback_pause(ui_playback_pause),
    .menu_active(ui_menu_active), .menu_item(ui_menu_item), .menu_value(ui_menu_value),
    .volume_level(ui_volume_level), .subtitle_speed(ui_subtitle_speed), .playback_order(ui_playback_order),
    .brightness_level(ui_brightness), .contrast_level(ui_contrast), .saturation_level(ui_saturation),
    .auto_brightness(ui_auto_brightness), .adjust_mode(ui_adjust_mode),
    .saturation_mode(ui_saturation_mode), .time_set_mode(ui_time_set),
    .clock_hour(ui_hour), .clock_minute(ui_minute), .clock_second(ui_second),
    .status_edit_mode(shelter_edit_mode),
    .people_hundreds(shelter_people_hundreds),
    .people_tens(shelter_people_tens), .people_ones(shelter_people_ones),
    .material_state(shelter_material_state), .medical_state(shelter_medical_state)
);

// Audio completion crosses back as a stable level. It remains asserted until
// the image index changes, so a two-flop synchronizer cannot miss it.
always @(posedge sd_card_clk or posedge rst_control) begin
    if (rst_control)
        audio_done_sync_sd <= 2'b00;
    else
        audio_done_sync_sd <= {audio_done_sync_sd[0], audio_voice_done};
end

// ===================== TF 多图扫描与缓存（双缓冲） =====================
// ===================== 鲁棒性：无TF卡/无有效图片提示 =====================
wire [23:0] nocar_rgb;
wire        nocar_hs, nocar_vs, nocar_de;
wire        no_card_sd;

sd_card_bmp #(
    .EXTERNAL_UI       (1),
    .HAZARD_POLICY_ENABLE(1),
    .PLAYBACK_ORDER_ENABLE(1),
    .FAST_FIRST_IMAGE_ENABLE(1),
    .CLK_FREQ_HZ       (50_000_000),
    .LOAD_TIMEOUT_CYCLES(250_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_control),
    .key_next          (1'b1),
    .key_auto          (1'b1),
    .key_auto_allowed  (1'b1),
    .clock_set_active  (ui_playback_pause),
    .ui_next_pulse     (ui_next_pulse),
    .ui_emergency_pulse(ui_emergency_pulse),
    .ui_auto_route_pulse(ui_auto_route_pulse),
    .hazard_active(hazard_active), .hazard_evacuation(hazard_evacuation),
    .hazard_route_locked(hazard_route_locked), .hazard_route_b(hazard_route_b),
    .ui_playback_order(ui_playback_order),
    .key2_short_status (key2_short_status),
    .key2_long_status  (key2_long_status),
    .key4_short_status (key4_short_status),
    .key4_long_status  (key4_long_status),
    .voice_done        (audio_done_sync_sd[1]),
    .state_code        (state_code),
    .bmp_width         (16'd1280),
    .bmp_height        (16'd960),
    .display_valid     (display_valid),

    .write_finish_toggle(frame_write_toggle_mem),
    .fade_black_ready  (fade_black_ready_sd),
    .scan_no_image       (no_card_sd),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso),

    .current_image_index(current_image_index),
    .current_source_width(current_source_width),
    .current_source_height(current_source_height),
    .auto_play_status   (auto_play_status),
    .load_busy_status   (load_busy_status),
    .fade_request_status(fade_request_status),
    .emergency_mode_status(emergency_mode_status),
    .accessible_route_status(accessible_route_status)
);

seg_decoder seg_decoder_m0(
    .bin_data          (state_code),
    .seg_data          (seg_data_0)
);

seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (rst_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ({1'b1,7'b1111_111}),
    .seg_data_1        ({1'b1,7'b1111_111}),
    .seg_data_2        ({1'b1,7'b1111_111}),
    .seg_data_3        ({1'b1,7'b1111_111}),
    .seg_data_4        ({1'b1,7'b1111_111}),
    .seg_data_5        ({1'b1,seg_data_0})
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
assign vout_data = display_valid ? vout_data_raw : 24'd0;

frame_read_write #(
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (rst_memory),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (disp_buf_idx),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (FRAME_PIXELS),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_memory),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// ===================== 音频：内部 I2S 测试音 =====================
hdmi_audio_tone_i2s_64fs #(
    .VOLUME_CONTROL_ENABLE(1),
    .HAZARD_POLICY_ENABLE(1),
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (rst_audio),
    .I_image_idx (current_image_index),
    .I_display_valid(display_valid),
    .I_emergency_mode(emergency_mode_status),
    .I_countdown_expired(emergency_countdown_expired),
    .I_wait_for_staff(hazard_wait_audio),
    .I_volume_level(ui_volume_level),
    .O_voice_done(audio_voice_done),
    .O_i2s_BCLK  (audio_i2s_bclk),
    .O_i2s_LRCK  (audio_i2s_lrck),
    .O_i2s_DOUT  (audio_i2s_dout)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (rst_video),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid),
    .O_audio_left_data  (audio_left_data),
    .O_audio_right_data (audio_right_data)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

// ===================== C ext: soft clock + adjust + OSD + ticker + fade =====================
wire [23:0] effect_rgb;
wire effect_hs;
wire effect_vs;
wire effect_de;
wire [23:0] spectrum_rgb;
wire spectrum_hs;
wire spectrum_vs;
wire spectrum_de;
wire [23:0] shelter_rgb;
wire shelter_hs;
wire shelter_vs;
wire shelter_de;
wire [23:0] hazard_rgb;
wire hazard_hs, hazard_vs, hazard_de;
video_effects_top #(
    .GROUPED_MENU_ENABLE(1),
    .CONTROL_CLK_FREQ_HZ(50_000_000),
    .KEY_DEBOUNCE_MS    (20),
    .SCREEN_WIDTH       (640),
    .SCROLL_TEXT_Y      (432),
    .SCROLL_START_X     (640),
    .SCROLL_SPEED_DIV   (2),
    // Two frames per level: about 0.53 s down and 0.53 s up at 60 Hz.
    .FADE_STEP_FRAMES   (2),
    .CLOCK_DEFAULT_HOUR (5'd12),
    .CLOCK_DEFAULT_MINUTE(6'd0),
    .CLOCK_DEFAULT_SECOND(6'd0)
) u_video_effects_top (
    .pixel_clk               (video_clk),
    .control_clk             (clk),
    .reset_pixel             (rst_video),
    .reset_control           (rst_control),
    .rgb_in                  (vout_data),
    .hs_in                   (hs),
    .vs_in                   (vs),
    .de_in                   (de),
    .ui_brightness          (ui_brightness),
    .ui_contrast            (ui_contrast),
    .ui_saturation          (ui_saturation),
    .ui_adjust_mode         (ui_adjust_mode),
    .ui_saturation_mode     (ui_saturation_mode),
    .ui_auto_brightness     (ui_auto_brightness),
    .ui_time_set            (ui_time_set),
    .ui_hour                (ui_hour),
    .ui_minute              (ui_minute),
    .ui_second              (ui_second),
    .ui_menu_active         (ui_menu_active),
    .ui_menu_item           (ui_menu_item),
    .ui_menu_value          (ui_menu_value),
    .ui_subtitle_speed      (ui_subtitle_speed),
    .image_index             (current_image_index),
    .source_width            (current_source_width),
    .source_height           (current_source_height),
    .auto_play_status        (auto_play_status),
    .load_busy_status        (load_busy_status),
    .fade_request_status     (fade_request_status),
    .emergency_mode_status   (emergency_mode_status),
    .accessible_route_status (accessible_route_status),
    .scroll_enable           (1'b1),
    .fade_enable             (1'b1),
    .rgb_out                 (effect_rgb),
    .hs_out                  (effect_hs),
    .vs_out                  (effect_vs),
    .de_out                  (effect_de),
    .brightness_level_status (brightness_level_status),
    .contrast_level_status   (contrast_level_status),
    .saturation_level_status (saturation_level_status),
    .adjust_mode_status      (adjust_mode_status),
    .saturation_mode_status  (saturation_mode_status),
    .auto_brightness_status  (auto_brightness_status),
    .time_set_mode_status    (time_set_mode_status),
    .time_set_mode_control   (time_set_mode_control),
    .emergency_countdown_expired(emergency_countdown_expired),
    .clock_hour_status       (clock_hour_status),
    .clock_minute_status     (clock_minute_status),
    .clock_second_status     (clock_second_status),
    .fade_level_debug        (fade_level_debug)
);

// ===================== 扩展5：HDMI音频实时频谱 =====================
// 直接观察I2S接收器已经送给HDMI的左声道PCM，不更换原有提示音。
// 16个频段位于左上角OSD右侧，避免遮挡时钟、参数和底部字幕。
spectrum_overlay #(
    .BIN_COUNT   (16),
    .WINDOW_LEN  (512),
    .MAG_SHIFT   (8),
    .SPEC_X      (108),
    .SPEC_Y      (8),
    .SPEC_H      (78),
    .BAR_W       (5),
    .BAR_GAP     (2),
    .SPEC_SHIFT  (5)
) u_spectrum_overlay (
    .pixel_clk   (video_clk),
    .reset       (rst_video),
    .rgb_in      (effect_rgb),
    .hs_in       (effect_hs),
    .vs_in       (effect_vs),
    .de_in       (effect_de),
    .audio_valid (audio_valid),
    .audio_pcm   (audio_left_data),
    .rgb_out     (spectrum_rgb),
    .hs_out      (spectrum_hs),
    .vs_out      (spectrum_vs),
    .de_out      (spectrum_de)
);

// Real-time people/material/medical status. Hidden during emergency countdown.
shelter_status_overlay u_shelter_status_overlay (
    .pixel_clk(video_clk), .reset(rst_video),
    .enable(!emergency_mode_status), .edit_mode(shelter_edit_mode),
    .people_hundreds(shelter_people_hundreds),
    .people_tens(shelter_people_tens), .people_ones(shelter_people_ones),
    .material_state(shelter_material_state), .medical_state(shelter_medical_state),
    .rgb_in(spectrum_rgb), .hs_in(spectrum_hs), .vs_in(spectrum_vs), .de_in(spectrum_de),
    .rgb_out(shelter_rgb), .hs_out(shelter_hs), .vs_out(shelter_vs), .de_out(shelter_de)
);
// ===================== RGB/DE 转 AXIS 视频 =====================
// Synchronize qualified switch states and latch them at frame boundaries.
// This final overlay vetoes unsafe static/dynamic route arrows as well.
hazard_overlay u_hazard_overlay (
    .pixel_clk(video_clk), .reset(rst_video),
    .hazards_control(hazard_bits), .emergency_control(emergency_mode_status),
    .route_b_control(accessible_route_status),
    .rgb_in(shelter_rgb), .hs_in(shelter_hs), .vs_in(shelter_vs), .de_in(shelter_de),
    .rgb_out(hazard_rgb), .hs_out(hazard_hs), .vs_out(hazard_vs), .de_out(hazard_de));
// ===================== 鲁棒性：无TF卡/无有效图片提示 =====================

no_card_overlay u_no_card_overlay (
    .pixel_clk (video_clk),
    .reset     (rst_video),
    .no_card   (no_card_sd),
    .rgb_in    (hazard_rgb),
    .hs_in     (hazard_hs),
    .vs_in     (hazard_vs),
    .de_in     (hazard_de),
    .rgb_out   (nocar_rgb),
    .hs_out    (nocar_hs),
    .vs_out    (nocar_vs),
    .de_out    (nocar_de)
);

video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_video),
.I_vs (nocar_vs),
.I_de (nocar_de),
.I_rgb (nocar_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_video),
    .O_pulse (edid_trig)
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_video),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_video),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule

// Active-high reset conditioner. Assertion is immediate; deassertion is held
// for four local clock edges so no state machine leaves reset between edges.
module reset_sync (
    input  wire clk,
    input  wire async_reset,
    output wire reset_out
);
    reg [3:0] release_pipe;

    always @(posedge clk or posedge async_reset) begin
        if (async_reset)
            release_pipe <= 4'b1111;
        else
            release_pipe <= {release_pipe[2:0], 1'b0};
    end

    assign reset_out = release_pipe[3];
endmodule
