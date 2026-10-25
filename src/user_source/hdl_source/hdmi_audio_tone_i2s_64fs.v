// 内部 I2S 音频：图1~3 各播放一次对应语音；图4 保留
// “1 秒警报 -> 语音 -> 短滴 -> 屏幕倒计时归零后持续长鸣”。
// 图1~3和图4的语音内容、采样与音量保持不变。

module hdmi_audio_tone_i2s_64fs #(
    parameter integer HAZARD_POLICY_ENABLE = 0,
    parameter integer VOLUME_CONTROL_ENABLE = 0,
    parameter [31:0] PHASE_INC = 32'd39370534,        // 兼容旧顶层，内部不用
    parameter signed [23:0] AMP = 24'sd2000000,       // 兼容旧顶层，内部不用
    parameter signed [23:0] AMP_CALM  = 24'sd3355443, // 图1~3 音量 ≈ 满量程 40%
    parameter signed [23:0] AMP_ALERT = 24'sd4445962, // 图4 警报音量 ≈ 满量程 53%
    parameter [31:0] INC_LO = 32'd59055800,           // 低音 660Hz
    parameter [31:0] INC_HI = 32'd78741068,           // 高音 880Hz
    parameter integer HALF_CALM  = 19200,             // 图1~3 换音间隔 0.4s @48kHz
    parameter integer HALF_ALERT = 9600,              // 图4   换音间隔 0.2s @48kHz
    parameter integer FADE_LEN = 2048,                // 43ms@48kHz，上电淡入长度
    parameter integer ALARM_SAMPLES = 48000,          // 图4 警报时长 1s @48kHz
    parameter integer BEEP_HALF     = 4800,           // 图4 警报通断半周期 0.1s @48kHz
    parameter integer VOICE_DIV     = 6,              // 8kHz 升 48kHz，每样本重复次数
    parameter [1:0]   VOICE_INDEX   = 2'd3            // 播人声的图片编号
)(
    input  wire        I_mclk,      // 12.288MHz
    input  wire        I_rst,
    input  wire [1:0]  I_image_idx, // 当前显示图片编号 0~3
    input  wire        I_display_valid,
    input  wire        I_emergency_mode,
    input  wire        I_countdown_expired, // actual on-screen countdown == 0
    input  wire        I_wait_for_staff, // both exits unavailable: no evacuation narration
    input wire [1:0] I_volume_level,
    output reg         O_voice_done, // 当前图片语音已完整播放；切图/复位后清零
    output reg         O_i2s_BCLK,
    output reg         O_i2s_LRCK,
    output reg         O_i2s_DOUT
);

    // 半周期正弦表 128 项（0~π），相位最高位决定正负，等效 256 级/周期
    function signed [7:0] sine_tab;
        input [6:0] index;
        begin
            case (index)
                7'd0: sine_tab = 8'sd0;
                7'd1: sine_tab = 8'sd3;
                7'd2: sine_tab = 8'sd6;
                7'd3: sine_tab = 8'sd9;
                7'd4: sine_tab = 8'sd12;
                7'd5: sine_tab = 8'sd16;
                7'd6: sine_tab = 8'sd19;
                7'd7: sine_tab = 8'sd22;
                7'd8: sine_tab = 8'sd25;
                7'd9: sine_tab = 8'sd28;
                7'd10: sine_tab = 8'sd31;
                7'd11: sine_tab = 8'sd34;
                7'd12: sine_tab = 8'sd37;
                7'd13: sine_tab = 8'sd40;
                7'd14: sine_tab = 8'sd43;
                7'd15: sine_tab = 8'sd46;
                7'd16: sine_tab = 8'sd49;
                7'd17: sine_tab = 8'sd51;
                7'd18: sine_tab = 8'sd54;
                7'd19: sine_tab = 8'sd57;
                7'd20: sine_tab = 8'sd60;
                7'd21: sine_tab = 8'sd63;
                7'd22: sine_tab = 8'sd65;
                7'd23: sine_tab = 8'sd68;
                7'd24: sine_tab = 8'sd71;
                7'd25: sine_tab = 8'sd73;
                7'd26: sine_tab = 8'sd76;
                7'd27: sine_tab = 8'sd78;
                7'd28: sine_tab = 8'sd81;
                7'd29: sine_tab = 8'sd83;
                7'd30: sine_tab = 8'sd85;
                7'd31: sine_tab = 8'sd88;
                7'd32: sine_tab = 8'sd90;
                7'd33: sine_tab = 8'sd92;
                7'd34: sine_tab = 8'sd94;
                7'd35: sine_tab = 8'sd96;
                7'd36: sine_tab = 8'sd98;
                7'd37: sine_tab = 8'sd100;
                7'd38: sine_tab = 8'sd102;
                7'd39: sine_tab = 8'sd104;
                7'd40: sine_tab = 8'sd106;
                7'd41: sine_tab = 8'sd107;
                7'd42: sine_tab = 8'sd109;
                7'd43: sine_tab = 8'sd111;
                7'd44: sine_tab = 8'sd112;
                7'd45: sine_tab = 8'sd113;
                7'd46: sine_tab = 8'sd115;
                7'd47: sine_tab = 8'sd116;
                7'd48: sine_tab = 8'sd117;
                7'd49: sine_tab = 8'sd118;
                7'd50: sine_tab = 8'sd120;
                7'd51: sine_tab = 8'sd121;
                7'd52: sine_tab = 8'sd122;
                7'd53: sine_tab = 8'sd122;
                7'd54: sine_tab = 8'sd123;
                7'd55: sine_tab = 8'sd124;
                7'd56: sine_tab = 8'sd125;
                7'd57: sine_tab = 8'sd125;
                7'd58: sine_tab = 8'sd126;
                7'd59: sine_tab = 8'sd126;
                7'd60: sine_tab = 8'sd126;
                7'd61: sine_tab = 8'sd127;
                7'd62: sine_tab = 8'sd127;
                7'd63: sine_tab = 8'sd127;
                7'd64: sine_tab = 8'sd127;
                7'd65: sine_tab = 8'sd127;
                7'd66: sine_tab = 8'sd127;
                7'd67: sine_tab = 8'sd127;
                7'd68: sine_tab = 8'sd126;
                7'd69: sine_tab = 8'sd126;
                7'd70: sine_tab = 8'sd126;
                7'd71: sine_tab = 8'sd125;
                7'd72: sine_tab = 8'sd125;
                7'd73: sine_tab = 8'sd124;
                7'd74: sine_tab = 8'sd123;
                7'd75: sine_tab = 8'sd122;
                7'd76: sine_tab = 8'sd122;
                7'd77: sine_tab = 8'sd121;
                7'd78: sine_tab = 8'sd120;
                7'd79: sine_tab = 8'sd118;
                7'd80: sine_tab = 8'sd117;
                7'd81: sine_tab = 8'sd116;
                7'd82: sine_tab = 8'sd115;
                7'd83: sine_tab = 8'sd113;
                7'd84: sine_tab = 8'sd112;
                7'd85: sine_tab = 8'sd111;
                7'd86: sine_tab = 8'sd109;
                7'd87: sine_tab = 8'sd107;
                7'd88: sine_tab = 8'sd106;
                7'd89: sine_tab = 8'sd104;
                7'd90: sine_tab = 8'sd102;
                7'd91: sine_tab = 8'sd100;
                7'd92: sine_tab = 8'sd98;
                7'd93: sine_tab = 8'sd96;
                7'd94: sine_tab = 8'sd94;
                7'd95: sine_tab = 8'sd92;
                7'd96: sine_tab = 8'sd90;
                7'd97: sine_tab = 8'sd88;
                7'd98: sine_tab = 8'sd85;
                7'd99: sine_tab = 8'sd83;
                7'd100: sine_tab = 8'sd81;
                7'd101: sine_tab = 8'sd78;
                7'd102: sine_tab = 8'sd76;
                7'd103: sine_tab = 8'sd73;
                7'd104: sine_tab = 8'sd71;
                7'd105: sine_tab = 8'sd68;
                7'd106: sine_tab = 8'sd65;
                7'd107: sine_tab = 8'sd63;
                7'd108: sine_tab = 8'sd60;
                7'd109: sine_tab = 8'sd57;
                7'd110: sine_tab = 8'sd54;
                7'd111: sine_tab = 8'sd51;
                7'd112: sine_tab = 8'sd49;
                7'd113: sine_tab = 8'sd46;
                7'd114: sine_tab = 8'sd43;
                7'd115: sine_tab = 8'sd40;
                7'd116: sine_tab = 8'sd37;
                7'd117: sine_tab = 8'sd34;
                7'd118: sine_tab = 8'sd31;
                7'd119: sine_tab = 8'sd28;
                7'd120: sine_tab = 8'sd25;
                7'd121: sine_tab = 8'sd22;
                7'd122: sine_tab = 8'sd19;
                7'd123: sine_tab = 8'sd16;
                7'd124: sine_tab = 8'sd12;
                7'd125: sine_tab = 8'sd9;
                7'd126: sine_tab = 8'sd6;
                7'd127: sine_tab = 8'sd3;
                default: sine_tab = 8'sd0;
            endcase
        end
    endfunction

    // Slow control signals are synchronized into the 12.288 MHz audio domain.
    reg [1:0] idx_sync0, idx_sync1;
    reg valid_sync0, valid_sync1;
    reg emergency_sync0, emergency_sync1;
    reg countdown_sync0, countdown_sync1;
    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            idx_sync0 <= 2'd0; idx_sync1 <= 2'd0;
            valid_sync0 <= 1'b0; valid_sync1 <= 1'b0;
            emergency_sync0 <= 1'b0; emergency_sync1 <= 1'b0;
            countdown_sync0 <= 1'b0; countdown_sync1 <= 1'b0;
        end else begin
            idx_sync0 <= I_image_idx; idx_sync1 <= idx_sync0;
            valid_sync0 <= I_display_valid; valid_sync1 <= valid_sync0;
            emergency_sync0 <= I_emergency_mode; emergency_sync1 <= emergency_sync0;
            countdown_sync0 <= I_countdown_expired; countdown_sync1 <= countdown_sync0;
        end
    end

    function [14:0] voice_length;
        input [1:0] index;
        begin
            case (index)
                2'd0: voice_length = 15'd27587;
                2'd1: voice_length = 15'd23356;
                2'd2: voice_length = 15'd24033;
                default: voice_length = 15'd25048;
            endcase
        end
    endfunction

    function [15:0] ima_step;
        input [6:0] index;
        begin
            case(index)
                0:ima_step=7; 1:ima_step=8; 2:ima_step=9; 3:ima_step=10; 4:ima_step=11; 5:ima_step=12; 6:ima_step=13; 7:ima_step=14;
                8:ima_step=16; 9:ima_step=17; 10:ima_step=19; 11:ima_step=21; 12:ima_step=23; 13:ima_step=25; 14:ima_step=28; 15:ima_step=31;
                16:ima_step=34; 17:ima_step=37; 18:ima_step=41; 19:ima_step=45; 20:ima_step=50; 21:ima_step=55; 22:ima_step=60; 23:ima_step=66;
                24:ima_step=73; 25:ima_step=80; 26:ima_step=88; 27:ima_step=97; 28:ima_step=107; 29:ima_step=118; 30:ima_step=130; 31:ima_step=143;
                32:ima_step=157; 33:ima_step=173; 34:ima_step=190; 35:ima_step=209; 36:ima_step=230; 37:ima_step=253; 38:ima_step=279; 39:ima_step=307;
                40:ima_step=337; 41:ima_step=371; 42:ima_step=408; 43:ima_step=449; 44:ima_step=494; 45:ima_step=544; 46:ima_step=598; 47:ima_step=658;
                48:ima_step=724; 49:ima_step=796; 50:ima_step=876; 51:ima_step=963; 52:ima_step=1060; 53:ima_step=1166; 54:ima_step=1282; 55:ima_step=1411;
                56:ima_step=1552; 57:ima_step=1707; 58:ima_step=1878; 59:ima_step=2066; 60:ima_step=2272; 61:ima_step=2499; 62:ima_step=2749; 63:ima_step=3024;
                64:ima_step=3327; 65:ima_step=3660; 66:ima_step=4026; 67:ima_step=4428; 68:ima_step=4871; 69:ima_step=5358; 70:ima_step=5894; 71:ima_step=6484;
                72:ima_step=7132; 73:ima_step=7845; 74:ima_step=8630; 75:ima_step=9493; 76:ima_step=10442; 77:ima_step=11487; 78:ima_step=12635; 79:ima_step=13899;
                80:ima_step=15289; 81:ima_step=16818; 82:ima_step=18500; 83:ima_step=20350; 84:ima_step=22385; 85:ima_step=24623; 86:ima_step=27086; 87:ima_step=29794;
                default:ima_step=32767;
            endcase
        end
    endfunction

    function signed [4:0] ima_index_delta;
        input [2:0] code;
        begin
            case(code)
                3'd4: ima_index_delta=5'sd2;
                3'd5: ima_index_delta=5'sd4;
                3'd6: ima_index_delta=5'sd6;
                3'd7: ima_index_delta=5'sd8;
                default: ima_index_delta=-5'sd1;
            endcase
        end
    endfunction

    reg [5:0] S_bit_cnt;
    reg [63:0] S_shift_reg;
    reg signed [23:0] S_sample_word, S_sample_next;
    reg [31:0] S_phase_acc;
    reg [15:0] S_half_cnt, V_alarm_cnt, V_beep_cnt;
    reg S_tone_sel, S_sw_pend, V_beep_on;
    // Image-4 post-countdown siren only: 400 -> 800 -> 400 Hz, with
    // a complete up/down sweep every 4 s at the unchanged 48-kHz rate.
    // INC = f * 2^32 / 48000.
    localparam [31:0] FIRE_INC_MIN  = 32'd35791394;
    localparam [31:0] FIRE_INC_MAX  = 32'd71582788;
    localparam [31:0] FIRE_INC_STEP = 32'd4474;
    reg [31:0] S_siren_inc;
    reg [3:0] S_siren_step_count;
    reg S_siren_descending;
    wire sample_tick = (O_i2s_BCLK == 1'b1) && (S_bit_cnt == 6'd63) && (O_i2s_LRCK == 1'b1);

    wire [6:0] S_sine_idx = S_phase_acc[30:24];
    wire signed [7:0] S_sine_q = sine_tab(S_sine_idx);
    wire signed [7:0] S_sine = S_phase_acc[31] ? -S_sine_q : S_sine_q;
    wire signed [31:0] S_tone = S_sine * AMP_ALERT;
    wire signed [23:0] S_alarm_out = S_tone >>> 7;
    wire [31:0] S_inc_cur = S_tone_sel ? INC_HI : INC_LO;
    wire [31:0] S_inc_new = S_tone_sel ? INC_LO : INC_HI;
    wire [31:0] S_phase_nxt = S_phase_acc + S_inc_cur;
    wire S_zero_cross = S_phase_nxt[31] ^ S_phase_acc[31];
    wire S_do_switch = S_sw_pend & S_zero_cross;

    localparam [2:0] V_IDLE=3'd0, V_PREALARM=3'd1, V_VOICE=3'd2,
                     V_ALARM_LOOP=3'd3, V_DONE=3'd4;
    reg [2:0] V_state;
    reg [1:0] V_play_idx, V_last_idx;
    reg V_last_valid, V_last_emergency;
    reg [1:0] wait_sync;
    reg wait_last;
    wire wait_only = (HAZARD_POLICY_ENABLE != 0) && wait_sync[1] &&
                     valid_sync1 && emergency_sync1 && (idx_sync1 == VOICE_INDEX);
    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin wait_sync<=0; wait_last<=0; end
        else begin wait_sync<={wait_sync[0],I_wait_for_staff}; wait_last<=wait_only; end
    end
    reg [14:0] V_rom_addr;
    reg [3:0] V_rep_cnt;
    reg signed [15:0] V_predictor;
    reg [6:0] V_step_index;
    // The last ADPCM code must remain audible for all six 48 kHz frames
    // before voice_done is asserted.  Otherwise the controller can advance
    // one 8 kHz sample (125 us) before the narration is truly complete.
    reg V_finish_pending;
    wire [3:0] V_code;
    wire [7:0] V_pcm4_do;
    wire [7:0] V_pcm4_signed_byte = V_pcm4_do ^ 8'h80;
    wire [15:0] V_step = ima_step(V_step_index);
    wire [14:0] V_samples = voice_length(V_play_idx);
    wire V_voice_end = (V_rom_addr >= V_samples - 15'd1);
    wire V_rep_end = (V_rep_cnt >= VOICE_DIV[3:0] - 4'd1);
    wire V_alarm_end = (V_alarm_cnt >= ALARM_SAMPLES[15:0] - 16'd1);
    wire V_beep_end = (V_beep_cnt >= BEEP_HALF[15:0] - 16'd1);
    wire V_scene_changed = valid_sync1 && (!V_last_valid ||
                           (idx_sync1 != V_last_idx) ||
                           (emergency_sync1 != V_last_emergency) ||
                           (!wait_only && wait_last));
    wire signed [23:0] V_voice_out = {V_predictor,8'd0};
    wire signed [23:0] V_pcm4_out = {V_pcm4_signed_byte,16'd0};
    wire signed [23:0] V_selected_voice_out =
                           (V_play_idx == VOICE_INDEX) ? V_pcm4_out : V_voice_out;
    wire V_alarm_phase = (V_state == V_PREALARM) || (V_state == V_ALARM_LOOP);
    // Do not interrupt the opening alarm or narration, even if expiry has
    // already arrived. Only the post-voice image-4 alarm changes to long tone.
    wire V_long_alarm = valid_sync1 && emergency_sync1 &&
                       (V_play_idx == VOICE_INDEX) &&
                       (V_state == V_ALARM_LOOP) && countdown_sync1;
    // Original clips and ROMs are unchanged. Closed-exits status must never
    // audibly instruct people to use a blocked exit. Resume with full narration
    // after the waiting state clears, not from the middle of a hidden sentence.
    wire signed [23:0] V_audio_out = wait_only ? S_alarm_out :
                                     V_alarm_phase ? ((V_beep_on || V_long_alarm) ? S_alarm_out : 24'sd0) :
                                     (V_state == V_VOICE) ? V_selected_voice_out : 24'sd0;

    integer D_diff, D_pred, D_index;
    reg [1:0] volume_meta, volume_sync;
    always @(posedge I_mclk or posedge I_rst) begin
        if(I_rst) begin volume_meta<=3;volume_sync<=3;end
        else begin volume_meta<=I_volume_level;volume_sync<=volume_meta;end
    end
    // Emergency alerts retain at least 50%; no multipliers or new audio RAM.
    wire [1:0] effective_volume = (emergency_sync1 && volume_sync==0) ? 2'd1 : volume_sync;
    wire signed [23:0] volume_quarter = $signed(V_audio_out) >>> 2;
    wire signed [23:0] scaled_audio = (VOLUME_CONTROL_ENABLE == 0 || effective_volume==3) ? V_audio_out :
        effective_volume==0 ? volume_quarter : effective_volume==1 ? ($signed(V_audio_out) >>> 1) :
        ($signed(V_audio_out) - $signed(volume_quarter));

    voice_adpcm_rom u_voice_adpcm_rom(
        .clk(I_mclk), .voice_sel(V_play_idx), .addr(V_rom_addr), .dout(V_code)
    );

    // Image 4 keeps the previously proven 8-bit PCM voice.  Images 1-3 use
    // ADPCM so all four clips still fit in the available on-chip RAM.
    voice4_pcm_rom u_voice4_pcm_rom(
        .clk(I_mclk), .addr(V_rom_addr), .dout(V_pcm4_do)
    );

    // Scene sequencer and the shared IMA-ADPCM decoder.
    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            V_state <= V_IDLE; V_play_idx <= 2'd0; V_last_idx <= 2'd0;
            V_last_valid <= 1'b0; V_last_emergency <= 1'b0;
            V_rom_addr <= 15'd0; V_rep_cnt <= 4'd0;
            V_predictor <= 16'sd0; V_step_index <= 7'd0;
            V_finish_pending <= 1'b0;
            V_alarm_cnt <= 16'd0; V_beep_cnt <= 16'd0; V_beep_on <= 1'b1;
            O_voice_done <= 1'b0;
        end else if (!valid_sync1) begin
            V_state <= V_IDLE; V_last_valid <= 1'b0;
            V_rom_addr <= 15'd0; V_rep_cnt <= 4'd0;
            V_predictor <= 16'sd0; V_step_index <= 7'd0;
            V_finish_pending <= 1'b0;
            V_alarm_cnt <= 16'd0; V_beep_cnt <= 16'd0; V_beep_on <= 1'b1;
            O_voice_done <= 1'b0;
        end else if (V_scene_changed) begin
            V_last_valid <= 1'b1; V_last_idx <= idx_sync1;
            V_last_emergency <= emergency_sync1; V_play_idx <= idx_sync1;
            V_state <= (emergency_sync1 && (idx_sync1 == VOICE_INDEX)) ? V_PREALARM : V_VOICE;
            V_rom_addr <= 15'd0; V_rep_cnt <= 4'd0;
            V_predictor <= 16'sd0; V_step_index <= 7'd0;
            V_finish_pending <= 1'b0;
            V_alarm_cnt <= 16'd0; V_beep_cnt <= 16'd0; V_beep_on <= 1'b1;
            O_voice_done <= 1'b0;
        end else if (sample_tick) begin
            case (V_state)
                V_PREALARM: begin
                    if (V_alarm_end) begin
                        V_state <= V_VOICE; V_rom_addr <= 15'd0; V_rep_cnt <= 4'd0;
                        V_predictor <= 16'sd0; V_step_index <= 7'd0;
                        V_finish_pending <= 1'b0;
                    end else V_alarm_cnt <= V_alarm_cnt + 16'd1;
                    if (V_beep_end) begin V_beep_cnt <= 16'd0; V_beep_on <= ~V_beep_on; end
                    else V_beep_cnt <= V_beep_cnt + 16'd1;
                end
                V_VOICE: begin
                    if (V_rep_end) begin
                        V_rep_cnt <= 4'd0;
                        if (V_finish_pending) begin
                            // The final decoded sample has now completed its
                            // full 6x hold interval, so the image may advance.
                            V_finish_pending <= 1'b0;
                            O_voice_done <= 1'b1;
                            if (emergency_sync1 && (V_play_idx == VOICE_INDEX)) begin
                                V_state <= V_ALARM_LOOP; V_beep_cnt <= 16'd0; V_beep_on <= 1'b1;
                            end else V_state <= V_DONE;
                        end else if (V_play_idx == VOICE_INDEX) begin
                            // PCM data for image 4 is already the decoded
                            // sample at the current address.  Advance only
                            // after it has been held for six 48 kHz frames.
                            if (V_voice_end) begin
                                O_voice_done <= 1'b1;
                                if (emergency_sync1) begin
                                    V_state <= V_ALARM_LOOP;
                                    V_beep_cnt <= 16'd0;
                                    V_beep_on <= 1'b1;
                                end else V_state <= V_DONE;
                            end else V_rom_addr <= V_rom_addr + 15'd1;
                        end else begin
                            D_diff = V_step >>> 3;
                            if (V_code[2]) D_diff = D_diff + V_step;
                            if (V_code[1]) D_diff = D_diff + (V_step >>> 1);
                            if (V_code[0]) D_diff = D_diff + (V_step >>> 2);
                            D_pred = V_predictor;
                            if (V_code[3]) D_pred = D_pred - D_diff; else D_pred = D_pred + D_diff;
                            if (D_pred > 32767) D_pred = 32767;
                            if (D_pred < -32768) D_pred = -32768;
                        // Both operands must be signed.  With the old mixed
                        // signed/unsigned expression, an IMA delta of -1 could
                        // be zero-extended and interpreted as +31, driving the
                        // step index to 88 and turning speech into loud noise.
                        D_index = $signed({1'b0, V_step_index}) +
                                  $signed(ima_index_delta(V_code[2:0]));
                            if (D_index > 88) D_index = 88;
                            if (D_index < 0) D_index = 0;
                            V_predictor <= D_pred[15:0]; V_step_index <= D_index[6:0];
                            if (V_voice_end) V_finish_pending <= 1'b1;
                            else V_rom_addr <= V_rom_addr + 15'd1;
                        end
                    end else V_rep_cnt <= V_rep_cnt + 4'd1;
                end
                V_ALARM_LOOP: begin
                    if (V_beep_end) begin V_beep_cnt <= 16'd0; V_beep_on <= ~V_beep_on; end
                    else V_beep_cnt <= V_beep_cnt + 16'd1;
                end
                default: ;
            endcase
        end
    end

    // Alert oscillator changes pitch at a zero crossing to avoid clicks.
    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            S_phase_acc <= 32'd0; S_half_cnt <= 16'd0;
            S_tone_sel <= 1'b0; S_sw_pend <= 1'b0;
            S_siren_inc <= FIRE_INC_MIN;
            S_siren_step_count <= 4'd0;
            S_siren_descending <= 1'b0;
        end else if (sample_tick) begin
            if (V_long_alarm) begin
                // Low, slow continuous sweep at the SAME alarm volume.
                // Keep sine phase continuous; there are still no beep gaps.
                S_half_cnt <= 16'd0;
                S_tone_sel <= 1'b0;
                S_sw_pend <= 1'b0;
                S_phase_acc <= S_phase_acc + S_siren_inc;
                if (S_siren_step_count == 4'd11) begin
                    S_siren_step_count <= 4'd0;
                    if (!S_siren_descending) begin
                        if (S_siren_inc >= FIRE_INC_MAX - FIRE_INC_STEP) begin
                            S_siren_inc <= FIRE_INC_MAX;
                            S_siren_descending <= 1'b1;
                        end else S_siren_inc <= S_siren_inc + FIRE_INC_STEP;
                    end else begin
                        if (S_siren_inc <= FIRE_INC_MIN + FIRE_INC_STEP) begin
                            S_siren_inc <= FIRE_INC_MIN;
                            S_siren_descending <= 1'b0;
                        end else S_siren_inc <= S_siren_inc - FIRE_INC_STEP;
                    end
                end else S_siren_step_count <= S_siren_step_count + 1'b1;
            end else begin
            // Rearm only the new siren; the original opening alarm and short
            // beep oscillator below are kept byte-for-byte unchanged.
            S_siren_inc <= FIRE_INC_MIN;
            S_siren_step_count <= 4'd0;
            S_siren_descending <= 1'b0;
            if (S_half_cnt >= HALF_ALERT[15:0]-16'd1) begin S_half_cnt <= 16'd0; S_sw_pend <= 1'b1; end
            else S_half_cnt <= S_half_cnt + 16'd1;
            if (S_do_switch) begin S_tone_sel <= ~S_tone_sel; S_sw_pend <= 1'b0; end
            S_phase_acc <= S_do_switch ? (S_phase_acc + S_inc_new) : S_phase_nxt;
            end
        end
    end

    // 64-bit I2S frame, 24-bit sample in each 32-bit channel slot.
    always @(posedge I_mclk or posedge I_rst) begin
        if (I_rst) begin
            O_i2s_BCLK <= 1'b0; O_i2s_LRCK <= 1'b0; O_i2s_DOUT <= 1'b0;
            S_bit_cnt <= 6'd0; S_shift_reg <= 64'd0;
            S_sample_word <= 24'sd0; S_sample_next <= 24'sd0;
        end else begin
            O_i2s_BCLK <= ~O_i2s_BCLK;
            if (O_i2s_BCLK == 1'b1) begin
                O_i2s_DOUT <= S_shift_reg[63];
                S_shift_reg <= {S_shift_reg[62:0],1'b0};
                if (S_bit_cnt == 6'd63) begin
                    S_bit_cnt <= 6'd0;
                    if (O_i2s_LRCK == 1'b0) begin
                        O_i2s_LRCK <= 1'b1;
                        S_shift_reg <= {S_sample_word[23:0],40'd0};
                    end else begin
                        O_i2s_LRCK <= 1'b0;
                        S_sample_next <= scaled_audio;
                        S_sample_word <= S_sample_next;
                        S_shift_reg <= {S_sample_next[23:0],40'd0};
                    end
                end else S_bit_cnt <= S_bit_cnt + 6'd1;
            end
        end
    end

endmodule
