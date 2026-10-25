module video_adjust (
    input wire pixel_clk, input wire reset,
    input wire [23:0] rgb_in, input wire hs_in, input wire vs_in, input wire de_in,
    input wire [3:0] brightness_level, input wire [3:0] contrast_level,
    input wire [3:0] saturation_level,
    output reg [23:0] rgb_out, output reg hs_out, output reg vs_out, output reg de_out
);
    wire [7:0] red_in = rgb_in[23:16];
    wire [7:0] green_in = rgb_in[15:8];
    wire [7:0] blue_in = rgb_in[7:0];

    wire [15:0] luma_sum = red_in * 7'd77 + green_in * 8'd150 + blue_in * 6'd29;
    wire [7:0]  luma = luma_sum[15:8];

    // Four deliberately separated demonstration levels:
    // brightness 4/8/12/15 = -72/0/+64/+112
    // contrast   4/8/12/15 = 0.50/1.00/1.50/1.875
    // saturation 4/8/12/15 = 0.50/1.00/1.50/1.75
    function [7:0] saturate_channel;
        input [7:0] channel;
        input [7:0] gray;
        input [3:0] saturation;
        integer delta;
        integer result;
        begin
            delta = $signed({1'b0, channel}) - $signed({1'b0, gray});
            case (saturation)
                4'd4:  result = gray + (delta >>> 1);
                4'd8:  result = channel;
                4'd12: result = gray + delta + (delta >>> 1);
                4'd15: result = gray + delta + (delta >>> 1) + (delta >>> 2);
                default: result = channel;
            endcase
            if (result > 255) saturate_channel = 8'd255;
            else if (result < 0) saturate_channel = 8'd0;
            else saturate_channel = result[7:0];
        end
    endfunction

    function [7:0] adjust_channel;
        input [7:0] channel;
        input [3:0] brightness;
        input [3:0] contrast;
        integer centered;
        integer contrast_scale;
        integer brightness_offset;
        integer result;
        begin
            case (brightness)
                4'd4: brightness_offset = -72;
                4'd8: brightness_offset = 0;
                4'd12: brightness_offset = 64;
                4'd15: brightness_offset = 112;
                default: brightness_offset = 0;
            endcase
            case (contrast)
                4'd4: contrast_scale = 8;
                4'd8: contrast_scale = 16;
                4'd12: contrast_scale = 24;
                4'd15: contrast_scale = 30;
                default: contrast_scale = 16;
            endcase
            centered = $signed({1'b0, channel}) - 128;
            result = ((centered * contrast_scale) >>> 4) + 128 + brightness_offset;

            // Saturation prevents an overflow from wrapping bright pixels to dark.
            if (result > 255) adjust_channel = 8'd255;
            else if (result < 0) adjust_channel = 8'd0;
            else adjust_channel = result[7:0];
        end
    endfunction

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 24'h000000;
            hs_out <= 1'b0;
            vs_out <= 1'b0;
            de_out <= 1'b0;
        end
        else begin
            hs_out <= hs_in;
            vs_out <= vs_in;
            de_out <= de_in;
            if (de_in) begin
                rgb_out[23:16] <= adjust_channel(
                    saturate_channel(red_in, luma, saturation_level),
                    brightness_level, contrast_level);
                rgb_out[15:8]  <= adjust_channel(
                    saturate_channel(green_in, luma, saturation_level),
                    brightness_level, contrast_level);
                rgb_out[7:0]   <= adjust_channel(
                    saturate_channel(blue_in, luma, saturation_level),
                    brightness_level, contrast_level);
            end
            else rgb_out <= 24'h000000;
        end
    end
endmodule
