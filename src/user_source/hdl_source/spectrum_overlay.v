// 扩展5：音频频谱柱状图叠加。只实现赛题需要的实时频谱显示，
// 不修改原有声音、不按图片编号闪烁，避免与应急画面和转场效果互相干扰。

module spectrum_overlay #(
    parameter BIN_COUNT   = 16,
    parameter WINDOW_LEN  = 512,
    parameter MAG_SHIFT   = 8,
    parameter SPEC_X      = 108,
    parameter SPEC_Y      = 8,
    parameter SPEC_H      = 78,
    parameter BAR_W       = 5,
    parameter BAR_GAP     = 2,
    parameter SPEC_SHIFT  = 5,
    parameter BG_PAD      = 2,
    parameter LOW_PCT     = 33,
    parameter RED_PCT     = 85,
    parameter PEAK_DECAY  = 30,
    parameter [23:0] COLOR_LOW   = 24'h00C9A7,
    parameter [23:0] COLOR_MID   = 24'hFFC75F,
    parameter [23:0] COLOR_HIGH  = 24'hFF6F91,
    parameter [23:0] COLOR_PEAK  = 24'hFFFFFF,
    parameter [23:0] COLOR_BG    = 24'h001020,
    parameter [23:0] COLOR_BORDER = 24'h2080FF
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    input  wire        audio_valid,
    input  wire [23:0] audio_pcm,
    output reg  [23:0] rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out
);
    localparam PITCH    = BAR_W + BAR_GAP;
    localparam TOTAL_W  = BIN_COUNT * PITCH - BAR_GAP;
    localparam BAR_BOT  = SPEC_Y + SPEC_H - 1;
    localparam BG_X0    = SPEC_X - BG_PAD;
    localparam BG_Y0    = SPEC_Y - BG_PAD;
    localparam BG_X1    = SPEC_X + TOTAL_W + BG_PAD;
    localparam BG_Y1    = SPEC_Y + SPEC_H + BG_PAD;

    wire [BIN_COUNT*16-1:0] spec_energy;

    audio_spectrum #(
        .BIN_COUNT (BIN_COUNT),
        .WINDOW_LEN(WINDOW_LEN),
        .MAG_SHIFT (MAG_SHIFT)
    ) dsp_core (
        .pixel_clk  (pixel_clk),
        .reset      (reset),
        .audio_valid(audio_valid),
        .audio_pcm  (audio_pcm),
        .spec_energy(spec_energy),
        .spec_valid ()
    );

    // 能量右移 SPEC_SHIFT 得柱高，上限 SPEC_H
    function [15:0] bin_height;
        input [15:0] energy;
        reg [15:0] h;
        begin
            h = energy >> SPEC_SHIFT;
            bin_height = (h > SPEC_H) ? SPEC_H : h;
        end
    endfunction

    reg [10:0] x_cnt;
    reg [9:0]  y_cnt;
    reg de_d, vs_d;

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin x_cnt <= 0; y_cnt <= 0; de_d <= 0; vs_d <= 0; end
        else begin
            de_d <= de_in;
            vs_d <= vs_in;
            if (vs_in && !vs_d) begin x_cnt <= 0; y_cnt <= 0; end
            else begin
                if (de_in) x_cnt <= x_cnt + 1'b1; else x_cnt <= 0;
                if (de_d && !de_in) y_cnt <= y_cnt + 1'b1;
            end
        end
    end

    wire [10:0] rel_x = x_cnt - SPEC_X;

    // 柱序号：rel_x 落在第几根柱的节距内
    reg [4:0] bar_index;
    integer k;
    always @(*) begin
        bar_index = 5'd0;
        for (k = 0; k < BIN_COUNT; k = k + 1)
            if (rel_x >= k * PITCH) bar_index = k;
    end

    wire [10:0] bar_offset = rel_x - bar_index * PITCH;
    wire in_region = de_in && x_cnt >= SPEC_X && x_cnt < SPEC_X + TOTAL_W &&
        y_cnt >= SPEC_Y && y_cnt < SPEC_Y + SPEC_H;
    wire in_bar = in_region && bar_offset < BAR_W;
    wire [7:0] pix_level = BAR_BOT - y_cnt;

    wire [15:0] bar_h = bin_height(spec_energy[bar_index*16 +: 16]);
    wire bar_lit = in_bar && pix_level < bar_h;

    // 柱色按柱高分档：低于 LOW_PCT 绿，低于 RED_PCT 黄，再高才是红
    wire [23:0] bar_color = (bar_h * 100 < SPEC_H * LOW_PCT) ? COLOR_LOW  :
                            (bar_h * 100 < SPEC_H * RED_PCT) ? COLOR_MID  : COLOR_HIGH;

    // 频谱区深色底，四周外扩 BG_PAD，带 1px 边框
    wire in_bg = de_in && x_cnt >= BG_X0 && x_cnt < BG_X1 &&
        y_cnt >= BG_Y0 && y_cnt < BG_Y1;
    wire bg_border = in_bg && (x_cnt == BG_X0 || x_cnt == BG_X1 - 1 ||
        y_cnt == BG_Y0 || y_cnt == BG_Y1 - 1);

    reg [7:0] peak [0:BIN_COUNT-1];
    reg [5:0] frame_cnt;
    integer   j;

    // 每帧末：峰值跟高或每 PEAK_DECAY 帧降 1px；闪烁计数器同步翻位
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            frame_cnt <= 6'd0;
            for (j = 0; j < BIN_COUNT; j = j + 1) peak[j] <= 8'd0;
        end
        else if (vs_in && !vs_d) begin
            for (j = 0; j < BIN_COUNT; j = j + 1) begin
                if (bin_height(spec_energy[j*16 +: 16]) > peak[j])
                    peak[j] <= bin_height(spec_energy[j*16 +: 16]);
                else if (frame_cnt == PEAK_DECAY - 1 && peak[j] != 0)
                    peak[j] <= peak[j] - 1'b1;
            end
            frame_cnt <= (frame_cnt == PEAK_DECAY - 1) ? 6'd0 : frame_cnt + 1'b1;
        end
    end

    wire [7:0] peak_h = peak[bar_index];
    wire peak_lit = in_bar && peak_h >= 2 && pix_level >= peak_h - 2 && pix_level < peak_h;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 24'd0; hs_out <= 1'b0; vs_out <= 1'b0; de_out <= 1'b0;
        end
        else begin
            hs_out <= hs_in;
            vs_out <= vs_in;
            de_out <= de_in;
            if (!de_in) rgb_out <= rgb_in;
            else if (peak_lit) rgb_out <= COLOR_PEAK;
            else if (bar_lit) rgb_out <= bar_color;
            else if (bg_border) rgb_out <= COLOR_BORDER;
            else if (in_bg) rgb_out <= COLOR_BG;
            else rgb_out <= rgb_in;
        end
    end
endmodule
