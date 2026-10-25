`timescale 1ns/1ps

// Streaming bilinear scaler used by extension requirement 3.
// Input: bottom-up 24-bit RGB BMP pixels, 2..1280 x 2..960.
// Output: bottom-up fixed 640 x 480 RGB pixels for the existing SDRAM path.
// Three synchronous line buffers infer block RAM. Coordinate generation uses
// quotient/remainder accumulators, and interpolation is split into two stages.
module bilinear_scaler_stream #(
    parameter integer OUT_WIDTH       = 640,
    parameter integer OUT_HEIGHT      = 480,
    parameter integer MAX_INPUT_WIDTH = 1280
)(
    input wire clk, input wire rst, input wire frame_start,
    input wire [15:0] source_width, input wire [15:0] source_height,
    input wire in_valid, input wire [23:0] in_pixel,
    output reg out_valid, output reg [23:0] out_pixel,
    output reg frame_done, output reg busy, output reg overrun_error
);

// Keep every multiplier and adder in a separate registered stage.  The old
// implementation placed BRAM output, two multipliers and an adder in one
// 100-MHz path and only met about 61 MHz after routing.
localparam [3:0] S_WAIT_ROW  = 4'd0;
localparam [3:0] S_ISSUE_X0  = 4'd1;
localparam [3:0] S_CAPTURE_X0 = 4'd2;
localparam [3:0] S_CAPTURE_X1 = 4'd3;
localparam [3:0] S_HMUL      = 4'd4;
localparam [3:0] S_HSUM      = 4'd5;
localparam [3:0] S_VMUL      = 4'd6;
localparam [3:0] S_VSUM      = 4'd7;
localparam [3:0] S_OUTPUT    = 4'd8;
localparam integer X_DEN = OUT_WIDTH - 1;
localparam integer Y_DEN = OUT_HEIGHT - 1;

wire [23:0] bank0_read_q, bank1_read_q, bank2_read_q;

reg [15:0] src_w, src_h, in_x, in_y, rows_complete;
reg [1:0] in_bank;
reg [3:0] state;
reg [15:0] dst_x, dst_y, src_x_pos, src_y_pos;
reg [1:0] x_step_integer, y_step_integer;
reg [9:0] x_step_remainder, x_error;
reg [8:0] y_step_remainder, y_error;
reg [1:0] row_bank0, row_bank1;
reg [7:0] row_fy, px_fx_hold;
reg [23:0] p00_hold, p01_hold, p10_hold, p11_hold;
reg [16:0] ht_left_r, ht_right_r, ht_left_g, ht_right_g, ht_left_b, ht_right_b;
reg [16:0] hb_left_r, hb_right_r, hb_left_g, hb_right_g, hb_left_b, hb_right_b;
reg [16:0] h_top_r, h_top_g, h_top_b;
reg [16:0] h_bottom_r, h_bottom_g, h_bottom_b;
reg [25:0] vt_r, vb_r, vt_g, vb_g, vt_b, vb_b;
reg [25:0] mixed_r, mixed_g, mixed_b;

reg [15:0] sx0_comb, sx1_comb, sy0_comb, sy1_comb, read_x_comb;
reg [1:0] sy0_bank_comb, sy1_bank_comb;
reg [23:0] row0_pixel_comb, row1_pixel_comb;

wire [10:0] x_error_sum = {1'b0,x_error} + {1'b0,x_step_remainder};
wire [9:0] y_error_sum = {1'b0,y_error} + {1'b0,y_step_remainder};
wire [19:0] fx_product = x_error * 10'd410;
wire [18:0] fy_product = y_error * 10'd547;
wire [7:0] fx_comb = (dst_x == OUT_WIDTH-1) ? 8'd0 : fx_product[17:10];
wire [7:0] fy_comb = (dst_y == OUT_HEIGHT-1) ? 8'd0 : fy_product[17:10];

function [1:0] bank_from_row;
    input [15:0] row_number;
    begin
        case (row_number % 3)
            0: bank_from_row = 2'd0;
            1: bank_from_row = 2'd1;
            default: bank_from_row = 2'd2;
        endcase
    end
endfunction

function [16:0] horizontal_mix;
    input [7:0] left_pixel, right_pixel, fraction;
    reg [8:0] inverse_fraction;
    begin
        inverse_fraction = 9'd256 - {1'b0,fraction};
        horizontal_mix = left_pixel * inverse_fraction +
                         right_pixel * {1'b0,fraction};
    end
endfunction

function [7:0] vertical_mix;
    input [16:0] top_value, bottom_value;
    input [7:0] fraction;
    reg [8:0] inverse_fraction;
    reg [25:0] mixed_value;
    begin
        inverse_fraction = 9'd256 - {1'b0,fraction};
        mixed_value = top_value * inverse_fraction +
                      bottom_value * {1'b0,fraction} + 26'd32768;
        vertical_mix = mixed_value[23:16];
    end
endfunction

always @(*) begin
    if (dst_x == OUT_WIDTH-1) begin
        sx0_comb = src_w-1'b1; sx1_comb = src_w-1'b1;
    end else begin
        sx0_comb = src_x_pos;
        sx1_comb = (src_x_pos+1'b1 >= src_w) ? (src_w-1'b1) : (src_x_pos+1'b1);
    end
    if (dst_y == OUT_HEIGHT-1) begin
        sy0_comb = src_h-1'b1; sy1_comb = src_h-1'b1;
    end else begin
        sy0_comb = src_y_pos;
        sy1_comb = (src_y_pos+1'b1 >= src_h) ? (src_h-1'b1) : (src_y_pos+1'b1);
    end
    sy0_bank_comb = bank_from_row(sy0_comb);
    sy1_bank_comb = bank_from_row(sy1_comb);
    read_x_comb = (state == S_CAPTURE_X0) ? sx1_comb : sx0_comb;
    case (row_bank0)
        2'd0: row0_pixel_comb = bank0_read_q;
        2'd1: row0_pixel_comb = bank1_read_q;
        default: row0_pixel_comb = bank2_read_q;
    endcase
    case (row_bank1)
        2'd0: row1_pixel_comb = bank0_read_q;
        2'd1: row1_pixel_comb = bank1_read_q;
        default: row1_pixel_comb = bank2_read_q;
    endcase
end

// Explicit Anlogic block RAMs prevent the three scan-line stores from being
// implemented with LUTs. 2048 x 24 leaves room for inputs up to 1280 pixels.
scaler_line_bram line_bank0 (
    .clk(clk), .we(busy && in_valid && in_bank==2'd0),
    .write_addr(in_x[10:0]), .write_data(in_pixel),
    .read_addr(read_x_comb[10:0]), .read_data(bank0_read_q)
);
scaler_line_bram line_bank1 (
    .clk(clk), .we(busy && in_valid && in_bank==2'd1),
    .write_addr(in_x[10:0]), .write_data(in_pixel),
    .read_addr(read_x_comb[10:0]), .read_data(bank1_read_q)
);
scaler_line_bram line_bank2 (
    .clk(clk), .we(busy && in_valid && in_bank==2'd2),
    .write_addr(in_x[10:0]), .write_data(in_pixel),
    .read_addr(read_x_comb[10:0]), .read_data(bank2_read_q)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        src_w<=640; src_h<=480; in_x<=0; in_y<=0; in_bank<=0; rows_complete<=0;
    end else if (frame_start) begin
        src_w<=source_width; src_h<=source_height;
        in_x<=0; in_y<=0; in_bank<=0; rows_complete<=0;
    end else if (busy && in_valid) begin
        if (in_x+1'b1 >= src_w) begin
            in_x<=0; rows_complete<=rows_complete+1'b1;
            if (in_y+1'b1 < src_h) in_y<=in_y+1'b1;
            in_bank <= (in_bank==2'd2) ? 2'd0 : in_bank+1'b1;
        end else in_x<=in_x+1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state<=S_WAIT_ROW; dst_x<=0; dst_y<=0; src_x_pos<=0; src_y_pos<=0;
        x_step_integer<=1; y_step_integer<=1;
        x_step_remainder<=0; y_step_remainder<=0; x_error<=0; y_error<=0;
        row_bank0<=0; row_bank1<=1; row_fy<=0;
        p00_hold<=0; p01_hold<=0; p10_hold<=0; p11_hold<=0;
        px_fx_hold<=0; h_top_r<=0; h_top_g<=0; h_top_b<=0;
        h_bottom_r<=0; h_bottom_g<=0; h_bottom_b<=0;
        ht_left_r<=0; ht_right_r<=0; ht_left_g<=0; ht_right_g<=0;
        ht_left_b<=0; ht_right_b<=0; hb_left_r<=0; hb_right_r<=0;
        hb_left_g<=0; hb_right_g<=0; hb_left_b<=0; hb_right_b<=0;
        vt_r<=0; vb_r<=0; vt_g<=0; vb_g<=0; vt_b<=0; vb_b<=0;
        mixed_r<=0; mixed_g<=0; mixed_b<=0;
        out_valid<=0; out_pixel<=0; frame_done<=0; busy<=0; overrun_error<=0;
    end else begin
        out_valid<=0; frame_done<=0;
        if (frame_start) begin
            state<=S_WAIT_ROW; dst_x<=0; dst_y<=0; src_x_pos<=0; src_y_pos<=0;
            x_error<=0; y_error<=0; busy<=1; overrun_error<=0;
            if (source_width-1'b1 >= 16'd1278) begin
                x_step_integer<=2; x_step_remainder<=source_width-16'd1279;
            end else if (source_width-1'b1 >= 16'd639) begin
                x_step_integer<=1; x_step_remainder<=source_width-16'd640;
            end else begin
                x_step_integer<=0; x_step_remainder<=source_width-1'b1;
            end
            if (source_height-1'b1 >= 16'd958) begin
                y_step_integer<=2; y_step_remainder<=source_height-16'd959;
            end else if (source_height-1'b1 >= 16'd479) begin
                y_step_integer<=1; y_step_remainder<=source_height-16'd480;
            end else begin
                y_step_integer<=0; y_step_remainder<=source_height-1'b1;
            end
        end else if (busy) begin
            if (rows_complete > sy0_comb+16'd3) overrun_error<=1;
            case (state)
                S_WAIT_ROW: if ((dst_y<OUT_HEIGHT) && (rows_complete>sy1_comb)) begin
                    row_bank0<=sy0_bank_comb; row_bank1<=sy1_bank_comb; row_fy<=fy_comb;
                    dst_x<=0; src_x_pos<=0; x_error<=0; state<=S_ISSUE_X0;
                end
                S_ISSUE_X0: state<=S_CAPTURE_X0;
                S_CAPTURE_X0: begin
                    p00_hold<=row0_pixel_comb; p01_hold<=row1_pixel_comb;
                    px_fx_hold<=fx_comb; state<=S_CAPTURE_X1;
                end
                S_CAPTURE_X1: begin
                    p10_hold<=row0_pixel_comb; p11_hold<=row1_pixel_comb;
                    state<=S_HMUL;
                end
                S_HMUL: begin
                    ht_left_r <= p00_hold[23:16] * (9'd256-{1'b0,px_fx_hold});
                    ht_right_r<= p10_hold[23:16] * {1'b0,px_fx_hold};
                    ht_left_g <= p00_hold[15:8]  * (9'd256-{1'b0,px_fx_hold});
                    ht_right_g<= p10_hold[15:8]  * {1'b0,px_fx_hold};
                    ht_left_b <= p00_hold[7:0]   * (9'd256-{1'b0,px_fx_hold});
                    ht_right_b<= p10_hold[7:0]   * {1'b0,px_fx_hold};
                    hb_left_r <= p01_hold[23:16] * (9'd256-{1'b0,px_fx_hold});
                    hb_right_r<= p11_hold[23:16] * {1'b0,px_fx_hold};
                    hb_left_g <= p01_hold[15:8]  * (9'd256-{1'b0,px_fx_hold});
                    hb_right_g<= p11_hold[15:8]  * {1'b0,px_fx_hold};
                    hb_left_b <= p01_hold[7:0]   * (9'd256-{1'b0,px_fx_hold});
                    hb_right_b<= p11_hold[7:0]   * {1'b0,px_fx_hold};
                    state<=S_HSUM;
                end
                S_HSUM: begin
                    h_top_r<=ht_left_r+ht_right_r; h_top_g<=ht_left_g+ht_right_g;
                    h_top_b<=ht_left_b+ht_right_b; h_bottom_r<=hb_left_r+hb_right_r;
                    h_bottom_g<=hb_left_g+hb_right_g; h_bottom_b<=hb_left_b+hb_right_b;
                    state<=S_VMUL;
                end
                S_VMUL: begin
                    vt_r<=h_top_r*(9'd256-{1'b0,row_fy}); vb_r<=h_bottom_r*{1'b0,row_fy};
                    vt_g<=h_top_g*(9'd256-{1'b0,row_fy}); vb_g<=h_bottom_g*{1'b0,row_fy};
                    vt_b<=h_top_b*(9'd256-{1'b0,row_fy}); vb_b<=h_bottom_b*{1'b0,row_fy};
                    state<=S_VSUM;
                end
                S_VSUM: begin
                    mixed_r<=vt_r+vb_r+26'd32768;
                    mixed_g<=vt_g+vb_g+26'd32768;
                    mixed_b<=vt_b+vb_b+26'd32768;
                    state<=S_OUTPUT;
                end
                S_OUTPUT: begin
                    out_pixel[23:16]<=mixed_r[23:16];
                    out_pixel[15:8]<=mixed_g[23:16];
                    out_pixel[7:0]<=mixed_b[23:16];
                    out_valid<=1;
                    if (dst_x==OUT_WIDTH-1) begin
                        dst_x<=0; src_x_pos<=0; x_error<=0;
                        if (dst_y==OUT_HEIGHT-1) begin
                            busy<=0; frame_done<=1; state<=S_WAIT_ROW;
                        end else begin
                            dst_y<=dst_y+1'b1;
                            if (y_error_sum>=Y_DEN) begin
                                y_error<=y_error_sum-Y_DEN;
                                src_y_pos<=src_y_pos+y_step_integer+1'b1;
                            end else begin
                                y_error<=y_error_sum[8:0];
                                src_y_pos<=src_y_pos+y_step_integer;
                            end
                            state<=S_WAIT_ROW;
                        end
                    end else begin
                        dst_x<=dst_x+1'b1;
                        if (x_error_sum>=X_DEN) begin
                            x_error<=x_error_sum-X_DEN;
                            src_x_pos<=src_x_pos+x_step_integer+1'b1;
                        end else begin
                            x_error<=x_error_sum[9:0];
                            src_x_pos<=src_x_pos+x_step_integer;
                        end
                        state<=S_ISSUE_X0;
                    end
                end
                default: state<=S_WAIT_ROW;
            endcase
        end
    end
end
endmodule

module scaler_line_bram(
    input wire clk,
    input wire we,
    input wire [10:0] write_addr,
    input wire [23:0] write_data,
    input wire [10:0] read_addr,
    output wire [23:0] read_data
);
wire [23:0] unused_write_port_data;
EG_LOGIC_BRAM #(
    .DATA_WIDTH_A(24), .DATA_WIDTH_B(24),
    .ADDR_WIDTH_A(11), .ADDR_WIDTH_B(11),
    .DATA_DEPTH_A(2048), .DATA_DEPTH_B(2048),
    .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1),
    .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
    .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
    .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
    .IMPLEMENT("32K")
) line_memory (
    .doa(unused_write_port_data), .dob(read_data),
    .dia(write_data), .dib(24'd0),
    .cea(1'b1), .ocea(1'b1), .clka(clk), .wea(we), .rsta(1'b0),
    .ceb(1'b1), .oceb(1'b1), .clkb(clk), .web(1'b0), .rstb(1'b0),
    .bea(1'b1), .beb(1'b1), .addra(write_addr), .addrb(read_addr)
);
endmodule
