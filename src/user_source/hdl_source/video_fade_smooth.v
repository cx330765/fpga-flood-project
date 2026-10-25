module video_fade_smooth #(
    parameter integer STEP_FRAMES = 4
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire        enable,
    input  wire        load_busy,

    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,

    output reg  [23:0] rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out,
    output reg  [4:0]  fade_level
);

    reg vs_d;
    reg [7:0] frame_count;

    wire [12:0] red_scaled;
    wire [12:0] green_scaled;
    wire [12:0] blue_scaled;

    assign red_scaled   = rgb_in[23:16] * fade_level;
    assign green_scaled = rgb_in[15:8]  * fade_level;
    assign blue_scaled  = rgb_in[7:0]   * fade_level;

    // Fade level changes only on a frame boundary, avoiding tearing.
    // 16 means full brightness and 0 means black.
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            vs_d        <= 1'b0;
            frame_count <= 8'd0;
            fade_level  <= 5'd0;
        end
        else begin
            vs_d <= vs_in;

            if (!enable) begin
                frame_count <= 8'd0;
                fade_level  <= 5'd16;
            end
            else if (vs_in && !vs_d) begin
                // Hold the divider at zero while the fade is idle.  This makes
                // every transition start from the same frame count instead of
                // inheriting an arbitrary divider phase from the previous page.
                if (load_busy && (fade_level == 0)) begin
                    frame_count <= 8'd0;
                end
                else if (!load_busy && (fade_level >= 5'd16)) begin
                    frame_count <= 8'd0;
                    fade_level  <= 5'd16;
                end
                else if (frame_count >= STEP_FRAMES - 1) begin
                    frame_count <= 8'd0;

                    if (load_busy)
                        fade_level <= fade_level - 5'd1;
                    else
                        fade_level <= fade_level + 5'd1;
                end
                else begin
                    frame_count <= frame_count + 8'd1;
                end
            end
        end
    end

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 24'h000000;
            hs_out  <= 1'b0;
            vs_out  <= 1'b0;
            de_out  <= 1'b0;
        end
        else begin
            hs_out <= hs_in;
            vs_out <= vs_in;
            de_out <= de_in;

            if (!de_in)
                rgb_out <= 24'h000000;
            else if (!enable)
                rgb_out <= rgb_in;
            else
                rgb_out <= {
                    red_scaled[11:4],
                    green_scaled[11:4],
                    blue_scaled[11:4]
                };
        end
    end

endmodule
