
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter integer EXTERNAL_UI       = 0,
    parameter integer HAZARD_POLICY_ENABLE = 0,
    parameter integer PLAYBACK_ORDER_ENABLE = 0,
    parameter integer FAST_FIRST_IMAGE_ENABLE = 0,
    parameter integer LOAD_TIMEOUT_CYCLES = 500_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input                       key_auto_allowed,
    input                       clock_set_active,
    input                       ui_next_pulse,
    input                       ui_emergency_pulse,
    input                       ui_auto_route_pulse,
    input                       hazard_active,
    input                       hazard_evacuation,
    input                       hazard_route_locked,
    input                       hazard_route_b,
    input [2:0]                 ui_playback_order,
    output                      key2_short_status,
    output                      key2_long_status,
    output                      key4_short_status,
    output                      key4_long_status,
    input                       voice_done,
    output [3:0]                state_code,
    output                      scan_no_image,      // 扫描完成但0张有效图
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,

    input                       write_finish_toggle,
    input                       fade_black_ready,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO,

    output [1:0]                current_image_index,
    output [15:0]               current_source_width,
    output [15:0]               current_source_height,
    output                      auto_play_status,
    output                      load_busy_status,
    output                      fade_request_status,
    output                      emergency_mode_status,
    output                      accessible_route_status
);

function integer counter_bits;
    input integer maximum;
    integer value;
    begin
        counter_bits = 1;
        value = maximum;
        while (value > 1) begin
            counter_bits = counter_bits + 1;
            value = value >> 1;
        end
    end
endfunction

wire key_next_short_press;
wire key_next_long_press;
wire key_auto_press;
wire key_auto_long_press;
assign key2_short_status = key_next_short_press;
assign key2_long_status  = key_next_long_press;
assign key4_short_status = key_auto_press;
assign key4_long_status  = key_auto_long_press;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire [15:0]      bmp_source_width;
wire [15:0]      bmp_source_height;
wire             scaler_start;
wire             scaler_write_en;
wire [23:0]      scaler_write_data;
wire             scaler_frame_done;
wire             scaler_busy;
wire             scaler_overrun_error;
wire             native_dimensions;
wire             selected_frame_done;
wire             sd_init_done;
wire             bmp_ready;
wire             scan_done;
wire             scan_paused;
localparam integer RESCAN_CYCLES = (CLK_FREQ_HZ >= 2) ? CLK_FREQ_HZ / 2 : 1;
localparam integer RESCAN_BITS = counter_bits(RESCAN_CYCLES - 1);
wire             scan_found_valid;
wire [31:0]      scan_found_sector;
wire [2:0]       scan_found_total;

reg              scan_start_pulse;
reg              scan_resume_pulse;
reg              load_start_pulse;
reg [31:0]       load_sector;
reg              scan_kicked;
reg [RESCAN_BITS-1:0] rescan_cnt;    // Exactly sized for the 0.5s threshold.
reg              first_image_committed;
reg              auto_play_en;
localparam integer AUTO_COUNT_BITS = counter_bits((CLK_FREQ_HZ * 6) - 1);
reg [AUTO_COUNT_BITS-1:0] auto_cnt;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              next_req_pending;
reg              force_req_pending;
reg [1:0]        force_target_idx;
reg              force_target_emergency;
reg              active_force_load;
reg              load_busy;
reg              fade_request;
localparam integer LOAD_COUNT_BITS = counter_bits(LOAD_TIMEOUT_CYCLES);
reg [LOAD_COUNT_BITS-1:0] load_timeout_cnt;
reg              emergency_mode;
reg              accessible_route;
reg              saved_auto_play;
reg [1:0]        saved_img_idx;
// Policy owns a separate snapshot: never destroy manual-emergency return data.
reg              policy_session;
reg [1:0]        policy_saved_img;
reg              policy_saved_mode, policy_saved_route, policy_saved_auto;
reg              policy_load, policy_load_mode;
wire policy_active = (HAZARD_POLICY_ENABLE != 0) && hazard_active;
wire policy_owned = policy_active || policy_session;
wire policy_mode = policy_active ? hazard_evacuation : policy_saved_mode;
wire [1:0] policy_image = policy_active ?
    (hazard_evacuation ? 2'd3 : 2'd2) : policy_saved_img;
wire policy_target_available = policy_image < img_found_count;
reg [15:0]       pending_source_width;
reg [15:0]       pending_source_height;
reg [15:0]       displayed_source_width;
reg [15:0]       displayed_source_height;

// bmp_ready 先表示“源文件读取/送 FIFO 完成”；真正切显示要等 write_finish_toggle 同步后
reg              source_done_seen;
reg              write_done_seen;
reg              native_mode;
reg [18:0]       native_pixel_count;
reg              native_frame_done;

// 同步 mem_clk 域的 write_finish_toggle
reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_min_elapsed;
wire auto_voice_timeout;
wire auto_advance;
wire [1:0] next_from_current;

// Native 640x480 BMPs do not need to traverse the bilinear datapath.  This
// keeps ordinary slide switching fast and leaves the scaler only for extension
// 3 test images with a different resolution.
assign native_dimensions = (bmp_source_width == 16'd640) &&
                           (bmp_source_height == 16'd480);
assign selected_frame_done = native_mode ? native_frame_done : scaler_frame_done;
// Never pass a known-corrupt scaled frame into the SDRAM write FIFO.  The
// partially written inactive buffer is simply discarded by the controller.
assign write_en   = native_mode ? bmp_data_wr_en :
                    (scaler_write_en && !scaler_overrun_error);
assign write_data = native_mode ? {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0} :
                                  {scaler_write_data[23:16], scaler_write_data[15:8], scaler_write_data[7:0], 8'b0};
// Keep each committed picture visible for at least three seconds and never
// leave it before its narration is complete.  Six seconds is a fail-safe for
// an unlocked audio PLL or a broken completion crossing, so autoplay cannot
// become permanently stuck.
assign auto_min_elapsed  = (auto_cnt >= ((CLK_FREQ_HZ * 3) - 1));
assign auto_voice_timeout = (auto_cnt >= ((CLK_FREQ_HZ * 6) - 1));
assign auto_advance = (auto_min_elapsed && voice_done) || auto_voice_timeout;
// All six permutations are cyclic; image 3 stays emergency-only.
wire reverse_order = (ui_playback_order==1 || ui_playback_order==2 || ui_playback_order==5);
wire [1:0] order_first = ui_playback_order<=1 ? 2'd0 : ui_playback_order<=3 ? 2'd1 : 2'd2;
reg [2:0] order_observed;
reg order_restart_pending;
always @(posedge clk or posedge rst) begin
    if(rst) begin order_observed<=0;order_restart_pending<=0;end
    else if(!sd_init_done) begin order_observed<=0;order_restart_pending<=0;end
    else if(PLAYBACK_ORDER_ENABLE != 0) begin
        if(ui_playback_order != order_observed) begin
            order_observed<=ui_playback_order;order_restart_pending<=1;
        end else if(order_restart_pending && !clock_set_active && !policy_owned &&
                    !load_busy && display_valid && img_idx==order_first)
            order_restart_pending<=0;
    end
end
assign next_from_current = (PLAYBACK_ORDER_ENABLE != 0 && img_found_count>=3) ?
    (order_restart_pending ? order_first :
     reverse_order ? (img_idx==0 ? 2'd2 : img_idx==2 ? 2'd1 : 2'd0) :
                     (img_idx==0 ? 2'd1 : img_idx==1 ? 2'd2 : 2'd0)) :
    next_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
assign current_image_index = img_idx;
assign current_source_width = displayed_source_width;
assign current_source_height = displayed_source_height;
assign auto_play_status    = auto_play_en;
assign load_busy_status    = load_busy;
assign fade_request_status = fade_request;
assign emergency_mode_status   = emergency_mode;
assign accessible_route_status = accessible_route;

generate if (EXTERNAL_UI != 0) begin : external_ui
    assign key_next_short_press = ui_next_pulse;
    assign key_next_long_press = ui_emergency_pulse;
    assign key_auto_press = ui_auto_route_pulse;
    assign key_auto_long_press = 1'b0;
end else begin : legacy_ui
key_short_long_press #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20),
    .LONG_PRESS_MS(1500)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_next),
    .short_pulse(key_next_short_press),
    .long_pulse (key_next_long_press)
);

key_short_long_press #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20),
    .LONG_PRESS_MS(1500)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in  (key_auto),
    .short_pulse(key_auto_press),
    .long_pulse (key_auto_long_press)
);
end endgenerate

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            // Image 3 is reserved for emergency mode.  Normal manual and
            // automatic playback always loop over images 0, 1 and 2.
            default: next_index_limited = (cur >= 2'd2) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 // 首图固定写 buffer0
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wrfin_tgl_sync        <= 3'b000;
        scan_start_pulse      <= 1'b0;
        scan_resume_pulse     <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_sector           <= 32'd0;
        scan_kicked           <= 1'b0;
        rescan_cnt           <= 32'd0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        auto_cnt              <= 32'd0;
        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        img_sector0           <= 32'd0;
        img_sector1           <= 32'd0;
        img_sector2           <= 32'd0;
        img_sector3           <= 32'd0;
        next_req_pending      <= 1'b0;
        force_req_pending     <= 1'b0;
        force_target_idx      <= 2'd0;
        force_target_emergency <= 1'b0;
        active_force_load     <= 1'b0;
        load_busy             <= 1'b0;
        fade_request          <= 1'b0;
        load_timeout_cnt      <= 32'd0;
        emergency_mode        <= 1'b0;
        accessible_route      <= 1'b0;
        saved_auto_play       <= 1'b0;
        saved_img_idx         <= 2'd0;
        policy_session <= 0; policy_saved_img <= 0;
        policy_saved_mode <= 0; policy_saved_route <= 0; policy_saved_auto <= 0;
        policy_load <= 0; policy_load_mode <= 0;
        source_done_seen      <= 1'b0;
        write_done_seen       <= 1'b0;
        display_valid         <= 1'b0;
        pending_source_width  <= 16'd640;
        pending_source_height <= 16'd480;
        displayed_source_width  <= 16'd640;
        displayed_source_height <= 16'd480;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        scan_resume_pulse <= 1'b0;
        load_start_pulse <= 1'b0;

        if (!sd_init_done) begin
            scan_kicked           <= 1'b0;
            scan_resume_pulse     <= 1'b0;
            rescan_cnt           <= 32'd0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            auto_cnt              <= 32'd0;
            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            write_buf_idx         <= 2'd0;
            disp_buf_idx          <= 2'd0;
            img_sector0           <= 32'd0;
            img_sector1           <= 32'd0;
            img_sector2           <= 32'd0;
            img_sector3           <= 32'd0;
            next_req_pending      <= 1'b0;
            force_req_pending     <= 1'b0;
            force_target_idx      <= 2'd0;
            force_target_emergency <= 1'b0;
            active_force_load     <= 1'b0;
            load_busy             <= 1'b0;
            fade_request          <= 1'b0;
            load_timeout_cnt      <= 32'd0;
            emergency_mode        <= 1'b0;
            accessible_route      <= 1'b0;
            saved_auto_play       <= 1'b0;
            saved_img_idx         <= 2'd0;
            policy_session <= 0; policy_load <= 0;
            policy_saved_img <= 0; policy_saved_mode <= 0;
            policy_saved_route <= 0; policy_saved_auto <= 0; policy_load_mode <= 0;
            source_done_seen      <= 1'b0;
            write_done_seen       <= 1'b0;
            display_valid         <= 1'b0;
            pending_source_width  <= 16'd640;
            pending_source_height <= 16'd480;
            displayed_source_width  <= 16'd640;
            displayed_source_height <= 16'd480;
        end else begin
            // Capture the committed scene at the FIRST qualified hazard, even
            // when an ordinary inactive-buffer write is already in progress.
            if (policy_active && display_valid && !policy_session) begin
                policy_session <= 1'b1;
                policy_saved_img <= img_idx;
                policy_saved_mode <= emergency_mode;
                policy_saved_route <= accessible_route;
                policy_saved_auto <= (active_force_load && force_target_emergency) ?
                                     saved_auto_play : auto_play_en;
            end
            if (scaler_start) begin
                pending_source_width  <= bmp_source_width;
                pending_source_height <= bmp_source_height;
            end
            // 扫描阶段缓存前 4 张图的起始 sector
            if (scan_found_valid) begin
                case (img_found_count)
                    3'd0: img_sector0 <= scan_found_sector;
                    3'd1: img_sector1 <= scan_found_sector;
                    3'd2: img_sector2 <= scan_found_sector;
                    3'd3: img_sector3 <= scan_found_sector;
                    default: ;
                endcase

                if (img_found_count < 3'd4)
                    img_found_count <= img_found_count + 3'd1;
            end

            // 缩放器输出完整 640x480 帧后才算源图处理完成。bmp_ready 只表示
            // SD 文件已经读完，缩放器此时可能仍在补齐最后几行。
            if (load_busy && selected_frame_done)
                source_done_seen <= 1'b1;

            // Keep the memory-write completion as a level until the picture
            // is safely committed.  This avoids losing a one-cycle pulse when
            // the BMP reader and SDRAM writer finish on different cycles.
            if (load_busy && write_finish_pulse)
                write_done_seen <= 1'b1;

            // Loading and fading are deliberately separated.  Keep showing
            // the old buffer while the next BMP is read and written.  Start
            // fade-out only after both completion indications have arrived.
            if (load_busy) begin
                if (load_timeout_cnt < LOAD_TIMEOUT_CYCLES)
                    load_timeout_cnt <= load_timeout_cnt + 32'd1;

                // Nothing valid is on screen yet. Fade the already black
                // startup picture while loading, not after loading finishes.
                if (FAST_FIRST_IMAGE_ENABLE && !display_valid)
                    fade_request <= 1'b1;

                // A three-line scaler overrun means source rows were replaced
                // before interpolation consumed them.  Keep the old display
                // buffer and abort this attempt instead of committing a torn
                // or unrelated frame.
                if (!native_mode && scaler_overrun_error) begin
                    load_busy        <= 1'b0;
                    fade_request     <= 1'b0;
                    load_timeout_cnt <= 32'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    auto_cnt         <= 32'd0;
                    if (active_force_load && force_target_emergency)
                        auto_play_en <= saved_auto_play;
                    active_force_load <= 1'b0;
                    policy_load <= 1'b0;
                end else begin
                    if ((source_done_seen || selected_frame_done) &&
                        (write_done_seen || write_finish_pulse))
                        fade_request <= 1'b1;

                    // At black, switch buffers and immediately release the fade
                    // request so the new picture fades back in. Emergency mode
                    // changes only here, after its dedicated picture is valid.
                    if (fade_request && fade_black_ready &&
                        (source_done_seen || selected_frame_done) &&
                        (write_done_seen || write_finish_pulse)) begin
                        load_busy             <= 1'b0;
                        fade_request          <= 1'b0;
                        load_timeout_cnt      <= 32'd0;
                        source_done_seen      <= 1'b0;
                        write_done_seen       <= 1'b0;
                        disp_buf_idx          <= pending_buf_idx;
                        img_idx               <= load_idx;
                        display_valid         <= 1'b1;
                        first_image_committed <= 1'b1;
                        displayed_source_width  <= pending_source_width;
                        displayed_source_height <= pending_source_height;
                        if (policy_load) begin
                            emergency_mode <= policy_load_mode;
                            policy_load <= 1'b0;
                        end
                        if (active_force_load) begin
                            emergency_mode   <= force_target_emergency;
                            accessible_route <= 1'b0;
                            if (!force_target_emergency && !policy_owned)
                                auto_play_en <= saved_auto_play;
                            active_force_load <= 1'b0;
                        end
                    end
                    // A lost writer/fade handshake must never leave the display
                    // permanently black.  Abort this attempt and retain the old
                    // display buffer; a later manual/automatic request may retry.
                    else if (load_timeout_cnt >= LOAD_TIMEOUT_CYCLES) begin
                        load_busy        <= 1'b0;
                        fade_request     <= 1'b0;
                        load_timeout_cnt <= 32'd0;
                        source_done_seen <= 1'b0;
                        write_done_seen  <= 1'b0;
                        auto_cnt         <= 32'd0;
                        if (active_force_load && force_target_emergency)
                            auto_play_en <= saved_auto_play;
                        active_force_load <= 1'b0;
                        policy_load <= 1'b0;
                    end
                end
            end

            // 上电后自动发起一次“扫描前 4 张 BMP”
            if (!scan_kicked && bmp_ready) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;
                auto_play_en          <= 1'b0;
                auto_cnt              <= 32'd0;
                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;
                next_req_pending      <= 1'b0;
                force_req_pending     <= 1'b0;
                force_target_idx      <= 2'd0;
                force_target_emergency <= 1'b0;
                active_force_load     <= 1'b0;
                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                fade_request          <= 1'b0;
                load_timeout_cnt      <= 32'd0;
                emergency_mode        <= 1'b0;
                accessible_route      <= 1'b0;
                saved_auto_play       <= 1'b0;
                saved_img_idx         <= 2'd0;
                source_done_seen      <= 1'b0;
                write_done_seen       <= 1'b0;
            end else begin
                // Resume after the first full frame commits; no concurrent SD
                // scan/load ownership and no duplicate discovery of image one.
                if (FAST_FIRST_IMAGE_ENABLE && scan_paused &&
                    first_image_committed && bmp_ready && !load_busy && !scan_resume_pulse)
                    scan_resume_pulse <= 1'b1;

                // Empty discovery automatically retries at RESCAN_CYCLES.
                if (scan_done && (img_found_count == 3'd0)) begin
                    if (rescan_cnt == RESCAN_CYCLES - 1) begin
                        rescan_cnt  <= 32'd0;
                        scan_kicked <= 1'b0;
                    end else rescan_cnt <= rescan_cnt + 32'd1;
                end else rescan_cnt <= 32'd0;

                // KEY2 keeps its original auto-play function in normal mode,
                // but selects the normal/accessibility route in emergency mode.
                if (!policy_owned && key_auto_press && key_auto_allowed && !clock_set_active &&
                    !key_next_long_press &&
                    ((scan_done && (img_found_count > 3'd1)) ||
                     (FAST_FIRST_IMAGE_ENABLE && first_image_committed && !scan_done)) &&
                    !force_req_pending && !active_force_load) begin
                    if (emergency_mode) begin
                        accessible_route <= ~accessible_route;
                    end else begin
                        auto_play_en <= ~auto_play_en;
                        auto_cnt     <= 32'd0;
                    end
                end

                // A short KEY1 press is emitted on release, so it is mutually
                // exclusive with a 1.5-second long press.  Image 3 never enters
                // the normal 0->1->2->0 sequence.
                if (clock_set_active)
                    next_req_pending <= 1'b0;
                if (!policy_owned && key_next_short_press && !clock_set_active &&
                    !key_auto_long_press && !emergency_mode &&
                    (scan_done || (FAST_FIRST_IMAGE_ENABLE && first_image_committed)) &&
                    !force_req_pending && !active_force_load &&
                    (img_found_count > 3'd0)) begin
                    next_req_pending <= 1'b1;
                end

                // Long KEY1 toggles emergency mode only from a stable idle
                // picture. The visible mode changes later, together with the
                // committed emergency/normal buffer at the black boundary.
                if (!policy_owned && key_next_long_press && display_valid &&
                    first_image_committed && !load_busy && !force_req_pending &&
                    !active_force_load &&
                    ((scan_done && (img_found_count >= 3'd4)) ||
                     (FAST_FIRST_IMAGE_ENABLE && !scan_done))) begin
                    next_req_pending  <= 1'b0;
                    force_req_pending <= 1'b1;
                    auto_cnt          <= 32'd0;

                    if (!emergency_mode) begin
                        accessible_route <= 1'b0;
                        saved_img_idx    <= img_idx;
                        saved_auto_play  <= auto_play_en;
                        auto_play_en     <= 1'b0;
                        force_target_idx <= 2'd3;
                        force_target_emergency <= 1'b1;
                    end else begin
                        accessible_route <= 1'b0;
                        auto_play_en     <= 1'b0;
                        force_target_idx <= saved_img_idx;
                        force_target_emergency <= 1'b0;
                    end
                end

                // Automatic playback is completely paused in emergency mode.
                if (!policy_owned && scan_done && auto_play_en && !clock_set_active &&
                    !key_auto_long_press && !emergency_mode && display_valid &&
                    !load_busy && first_image_committed && (img_found_count > 3'd1)) begin
                    if (!auto_voice_timeout)
                        auto_cnt <= auto_cnt + 32'd1;
                    else
                        auto_cnt <= auto_cnt;
                end else begin
                    auto_cnt <= 32'd0;
                end

                // 首图自动加载到 buffer0
                if ((scan_done || (FAST_FIRST_IMAGE_ENABLE && scan_paused)) &&
                    !first_image_committed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    load_idx         <= 2'd0;
                    load_sector      <= img_sector0;
                    pending_buf_idx  <= 2'd0;
                    write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    fade_request     <= 1'b0;
                    load_timeout_cnt <= 32'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    active_force_load <= 1'b0;
                end
                // Emergency entry/exit has priority over ordinary manual and
                // automatic requests.  Image 3 is the dedicated emergency BMP;
                // exit restores the image saved at entry.
                // Finish the current write transaction first. Policy then
                // reconciles the LAST desired scene instead of queuing stale
                // toggles. Changing only severity/route never reloads page 4.
                else if (policy_session && scan_done && bmp_ready && display_valid && !load_busy &&
                         policy_target_available &&
                         ((img_idx != policy_image) || (emergency_mode != policy_mode))) begin
                    load_idx <= policy_image;
                    load_sector <= sector_lut(policy_image);
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1; load_busy <= 1'b1;
                    fade_request <= 1'b0; load_timeout_cnt <= 0;
                    source_done_seen <= 0; write_done_seen <= 0;
                    next_req_pending <= 0; force_req_pending <= 0;
                    auto_cnt <= 0; active_force_load <= 0;
                    policy_load <= 1'b1; policy_load_mode <= policy_mode;
                end
                else if (!policy_owned && scan_done && bmp_ready && display_valid && !load_busy &&
                         force_req_pending &&
                         (!force_target_emergency || img_found_count >= 3'd4)) begin
                    load_idx          <= force_target_idx;
                    load_sector       <= sector_lut(force_target_idx);
                    pending_buf_idx   <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx     <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse  <= 1'b1;
                    load_busy         <= 1'b1;
                    fade_request      <= 1'b0;
                    load_timeout_cnt  <= 32'd0;
                    source_done_seen  <= 1'b0;
                    write_done_seen   <= 1'b0;
                    force_req_pending <= 1'b0;
                    next_req_pending  <= 1'b0;
                    auto_cnt          <= 32'd0;
                    active_force_load <= 1'b1;
                end
                // 手动下一张优先：写到“非当前显示”的另一块 buffer
                else if (!policy_owned && scan_done && bmp_ready && display_valid && !load_busy &&
                         !emergency_mode && !clock_set_active && !key_auto_long_press &&
                         !key_next_long_press &&
                         (next_req_pending || key_next_short_press) &&
                         (img_found_count != 3'd0)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    fade_request     <= 1'b0;
                    load_timeout_cnt <= 32'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    active_force_load <= 1'b0;
                end
                // 自动播放下一张：同样写到“非当前显示”的另一块 buffer
                else if (!policy_owned && scan_done && bmp_ready && display_valid && !load_busy &&
                         !emergency_mode && !clock_set_active && !key_auto_long_press &&
                         !key_next_long_press &&
                         auto_play_en && auto_advance &&
                         !key_auto_press && !key_next_short_press &&
                         (img_found_count > 3'd1)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    fade_request     <= 1'b0;
                    load_timeout_cnt <= 32'd0;
                    source_done_seen <= 1'b0;
                    write_done_seen  <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                    active_force_load <= 1'b0;
                end
                // Discovery may end with fewer than four valid files. Never
                // load sector zero as a substitute for a missing emergency BMP.
                if (FAST_FIRST_IMAGE_ENABLE && scan_done && !scan_found_valid && img_found_count < 3'd4 &&
                    force_req_pending && force_target_emergency && !policy_owned) begin
                    force_req_pending <= 1'b0;
                    auto_play_en <= saved_auto_play;
                end

                // Clear stale ordinary requests as soon as policy takes over.
                // Never abort BMP/FIFO/SDRAM in mid-frame merely for a switch.
                if (policy_owned) begin
                    auto_play_en <= 0; auto_cnt <= 0;
                    next_req_pending <= 0; force_req_pending <= 0;
                    if (policy_active && emergency_mode) begin
                        if (hazard_route_locked) accessible_route <= hazard_route_b;
                        else if (key_auto_press && !clock_set_active && !load_busy)
                            accessible_route <= ~accessible_route;
                    end
                    if (!policy_active && policy_session && !load_busy &&
                        img_idx == policy_saved_img && emergency_mode == policy_saved_mode) begin
                        policy_session <= 0;
                        auto_play_en <= policy_saved_auto;
                        accessible_route <= policy_saved_route;
                    end
                end
            end
        end
    end
end

// Startup keeps a 1s grace period. Loss of an already initialized card is
// reported immediately after the local SD controller detects the failure.
localparam integer SD_INIT_TIMEOUT = CLK_FREQ_HZ;
localparam integer SD_INIT_BITS = counter_bits(SD_INIT_TIMEOUT - 1);
reg [SD_INIT_BITS-1:0] sd_init_cnt;
reg        sd_was_ready;
reg        sd_absent;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sd_init_cnt <= 32'd0;
        sd_absent   <= 1'b0;
        sd_was_ready <= 1'b0;
    end else if (sd_init_done) begin
        sd_init_cnt <= 32'd0;
        sd_absent   <= 1'b0;
        sd_was_ready <= 1'b1;
    end else if (sd_was_ready || sd_init_cnt == SD_INIT_TIMEOUT - 1) begin
        sd_absent <= 1'b1;
    end else begin
        sd_init_cnt <= sd_init_cnt + 32'd1;
    end
end

assign scan_no_image = sd_absent || (scan_done && (img_found_count == 3'd0));
bmp_read #(.FAST_FIRST_IMAGE_ENABLE(FAST_FIRST_IMAGE_ENABLE)) bmp_read_m0(
    .clk                    (clk),
    .rst                    (rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_resume            (scan_resume_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .scan_done              (scan_done),
    .scan_paused            (scan_paused),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_sector            (load_sector),

    .sd_init_done           (sd_init_done),
    .state_code             (state_code),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (write_req),
    .write_req_ack          (write_req_ack),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data),
    .source_width           (bmp_source_width),
    .source_height          (bmp_source_height),
    .scale_start            (scaler_start)
);

bilinear_scaler_stream #(
    .OUT_WIDTH        (640),
    .OUT_HEIGHT       (480),
    .MAX_INPUT_WIDTH  (1280)
) bilinear_scaler_stream_m0 (
    .clk              (clk),
    .rst              (rst),
    .frame_start      (scaler_start && !native_dimensions),
    .source_width     (bmp_source_width),
    .source_height    (bmp_source_height),
    .in_valid         (bmp_data_wr_en && !native_mode),
    .in_pixel         (bmp_data),
    .out_valid        (scaler_write_en),
    .out_pixel        (scaler_write_data),
    .frame_done       (scaler_frame_done),
    .busy             (scaler_busy),
    .overrun_error    (scaler_overrun_error)
);

// Generate the equivalent completion pulse for the native-size bypass.
// 640 x 480 = 307200 pixels; the last accepted pixel completes the frame.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        native_mode        <= 1'b0;
        native_pixel_count <= 19'd0;
        native_frame_done  <= 1'b0;
    end else begin
        native_frame_done <= 1'b0;
        if (scaler_start) begin
            native_mode        <= native_dimensions;
            native_pixel_count <= 19'd0;
        end else if (native_mode && bmp_data_wr_en) begin
            if (native_pixel_count == 19'd307199) begin
                native_pixel_count <= 19'd0;
                native_frame_done  <= 1'b1;
            end else begin
                native_pixel_count <= native_pixel_count + 19'd1;
            end
        end
    end
end

sd_card_top #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

// Active-low key decoder with mutually exclusive short/long events.
// A short event is reported only after release.  A long event is reported
// once when the stable pressed duration reaches LONG_PRESS_MS; releasing a
// long press does not generate an additional short event.
module key_short_long_press #(
    parameter integer CLK_FREQ_HZ  = 100_000_000,
    parameter integer DEBOUNCE_MS  = 20,
    parameter integer LONG_PRESS_MS = 1500
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  short_pulse,
    output reg  long_pulse
);

localparam integer DEBOUNCE_RAW = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
localparam integer LONG_RAW     = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
localparam integer DEBOUNCE_CYCLES = (DEBOUNCE_RAW < 1) ? 1 : DEBOUNCE_RAW;
localparam integer LONG_PRESS_CYCLES = (LONG_RAW < 1) ? 1 : LONG_RAW;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] debounce_cnt;
reg [31:0] hold_cnt;
reg long_reported;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        debounce_cnt  <= 32'd0;
        hold_cnt      <= 32'd0;
        long_reported <= 1'b0;
        short_pulse   <= 1'b0;
        long_pulse    <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        short_pulse  <= 1'b0;
        long_pulse   <= 1'b0;

        if (button_sync1 != button_stable) begin
            if (debounce_cnt >= DEBOUNCE_CYCLES - 1) begin
                button_stable <= button_sync1;
                debounce_cnt  <= 32'd0;

                if (!button_sync1) begin
                    hold_cnt      <= 32'd0;
                    long_reported <= 1'b0;
                end else begin
                    if (!long_reported)
                        short_pulse <= 1'b1;
                    hold_cnt <= 32'd0;
                end
            end else begin
                debounce_cnt <= debounce_cnt + 32'd1;
            end
        end else begin
            debounce_cnt <= 32'd0;
            if (!button_stable && !long_reported) begin
                if (hold_cnt >= LONG_PRESS_CYCLES - 1) begin
                    long_pulse    <= 1'b1;
                    long_reported <= 1'b1;
                end else begin
                    hold_cnt <= hold_cnt + 32'd1;
                end
            end
        end
    end
end

endmodule
