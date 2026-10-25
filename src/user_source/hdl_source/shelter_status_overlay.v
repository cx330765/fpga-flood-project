// Chinese live shelter-status overlay at bottom right.
// It is hidden in emergency mode so the large route countdown remains clear.
module shelter_status_overlay #(
    parameter integer PANEL_X = 504,
    parameter integer PANEL_Y = 432,
    parameter integer PANEL_W = 132,
    parameter integer PANEL_H = 48
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [1:0]  edit_mode,
    input  wire [3:0]  people_hundreds,
    input  wire [3:0]  people_tens,
    input  wire [3:0]  people_ones,
    input  wire [1:0]  material_state,
    input  wire [1:0]  medical_state,
    input  wire [23:0] rgb_in,
    input  wire        hs_in,
    input  wire        vs_in,
    input  wire        de_in,
    output reg  [23:0] rgb_out,
    output reg         hs_out,
    output reg         vs_out,
    output reg         de_out
);
    reg [10:0] x_cnt;
    reg [9:0]  y_cnt;
    reg        de_d;
    reg        vs_d;
    wire frame_start = vs_in && !vs_d;

    reg [1:0] edit_meta, edit_sync;
    reg [3:0] ph_meta, ph_sync, pt_meta, pt_sync, po_meta, po_sync;
    reg [1:0] mat_meta, mat_sync, med_meta, med_sync;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            edit_meta <= 0; edit_sync <= 0;
            ph_meta <= 1; ph_sync <= 1; pt_meta <= 2; pt_sync <= 2;
            po_meta <= 0; po_sync <= 0; mat_meta <= 0; mat_sync <= 0;
            med_meta <= 0; med_sync <= 0;
        end else begin
            edit_meta <= edit_mode; edit_sync <= edit_meta;
            ph_meta <= people_hundreds; ph_sync <= ph_meta;
            pt_meta <= people_tens; pt_sync <= pt_meta;
            po_meta <= people_ones; po_sync <= po_meta;
            mat_meta <= material_state; mat_sync <= mat_meta;
            med_meta <= medical_state; med_sync <= med_meta;
        end
    end

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            x_cnt <= 0; y_cnt <= 0; de_d <= 0; vs_d <= 0;
        end else begin
            de_d <= de_in;
            vs_d <= vs_in;
            if (frame_start) begin x_cnt <= 0; y_cnt <= 0; end
            else begin
                if (de_in) x_cnt <= x_cnt + 1'b1; else x_cnt <= 0;
                if (de_d && !de_in) y_cnt <= y_cnt + 1'b1;
            end
        end
    end

    // Dedicated bottom-right panel, above/beside the scrolling caption viewport.
    // The dark backing is clipped to exactly the same rectangle as the
    // cyan interaction frame.  No background pixel is drawn to its left.
    wire panel_area = de_in && x_cnt >= PANEL_X && x_cnt < PANEL_X+PANEL_W &&
                      y_cnt >= PANEL_Y && y_cnt < PANEL_Y+PANEL_H;
    wire panel_border = panel_area &&
                      (x_cnt < PANEL_X+2 || x_cnt >= PANEL_X+PANEL_W-2 ||
                       y_cnt < PANEL_Y+2 || y_cnt >= PANEL_Y+PANEL_H-2);
    wire [10:0] tx = x_cnt-(PANEL_X+8);
    wire [9:0] ty = y_cnt-(PANEL_Y+3);
    // Three fixed 14-pixel rows fit inside the bottom 48-pixel strip.
    // Map each compact row onto the complete 16-row source glyph.
    wire [1:0] text_line = (ty < 14) ? 0 : (ty < 28) ? 1 : 2;
    wire [5:0] row_offset = (text_line==0) ? ty : (text_line==1) ? ty-14 : ty-28;
    wire [3:0] glyph_row = (row_offset >= 10) ? row_offset+2 :
                           (row_offset >= 4) ? row_offset+1 : row_offset;
    wire text_area = panel_area && x_cnt >= PANEL_X+8 && x_cnt < PANEL_X+PANEL_W-8 &&
                     y_cnt >= PANEL_Y+3 && row_offset < 14;
    wire [3:0] char_index = tx[7:4];
    reg [5:0] code;
    always @(*) begin
        code=6'd63;
        case(text_line)
          0: begin
            case(char_index)
              4'd0: code=6'd0;
              4'd1: code=6'd1;
              4'd2: code=6'd2;
              4'd3: code=6'd24+ph_sync;
              4'd4: code=6'd24+pt_sync;
              4'd5: code=6'd24+po_sync;
              4'd6: code=6'd0;
              default: code=6'd63;
            endcase
          end
          1: begin
            case(char_index)
              4'd0: code=6'd3;
              4'd1: code=6'd4;
              4'd2: code=6'd2;
              4'd3: code=(mat_sync==0)?6'd5:(mat_sync==1)?6'd7:6'd8;
              4'd4: code=(mat_sync==0)?6'd6:(mat_sync==1)?6'd8:6'd9;
              default: code=6'd63;
            endcase
          end
          2: begin
            case(char_index)
              4'd0: code=6'd10;
              4'd1: code=6'd11;
              4'd2: code=6'd2;
              4'd3: code=(med_sync==0)?6'd12:(med_sync==1)?6'd14:6'd16;
              4'd4: code=(med_sync==0)?6'd13:(med_sync==1)?6'd15:6'd17;
              default: code=6'd63;
            endcase
          end
          default: code=6'd63;
        endcase
    end
    wire font_bit;
    shelter_cn_font u_status_cn(.code(code),.row(glyph_row),.col(tx[3:0]),.bit_on(font_bit));
    wire glyph_bit=text_area && font_bit;
    wire person_warn = (ph_sync >= 4'd3) || (ph_sync == 4'd2 && pt_sync >= 4'd5);
    wire person_full = (ph_sync >= 4'd3);
    reg [23:0] glyph_color;
    always @(*) begin
        if(char_index<3) glyph_color=24'hFFFFFF;
        else if(text_line==0)
            glyph_color=person_full?24'hFF6060:person_warn?24'hFFFF40:24'h60FF90;
        else if(text_line==1)
            glyph_color=(mat_sync==2)?24'hFF6060:(mat_sync==1)?24'hFFFF40:24'h60FF90;
        else glyph_color=(med_sync==2)?24'hFF6060:(med_sync==1)?24'hFFFF40:24'h60FF90;
    end
    wire selected_line=panel_area && x_cnt>=PANEL_X+3 && x_cnt<PANEL_X+6 &&
        y_cnt>=PANEL_Y+3 && row_offset<14 &&
        ((edit_sync==1 && text_line==0)||(edit_sync==2 && text_line==1)||
         (edit_sync==3 && text_line==2));

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; hs_out <= 0; vs_out <= 0; de_out <= 0;
        end else begin
            hs_out <= hs_in; vs_out <= vs_in; de_out <= de_in;
            if (!de_in) rgb_out <= 24'h000000;
            else if (!enable) rgb_out <= rgb_in;
            else if (selected_line) rgb_out <= 24'hFFFF00;
            else if (panel_border) rgb_out <= 24'h00C8FF;
            else if (glyph_bit) rgb_out <= glyph_color;
            else if (panel_area) rgb_out <= 24'h081018;
            else rgb_out <= rgb_in;
        end
    end
endmodule

module shelter_cn_font(input wire [5:0] code, input wire [3:0] row, input wire [3:0] col, output wire bit_on);
reg [255:0] bitmap;
always @(*) begin
bitmap=256'd0;
case(code)
6'd0: bitmap=256'h01800180018001800380038003c003c007c007e00e701c703c3c781e700e6004; // 人
6'd1: bitmap=256'h0c306d306fb06d7fffff7fe67fe6efe64dfeff3c7f3c771c3e3c3ffef3e76042; // 数
6'd2: bitmap=256'h0000000000001c001c001c000000000000001c001c001c000000000000000000; // ：
6'd3: bitmap=256'h598059fe7ffe7f5edaded8d6d9b619b67f36ff76f86618e619c61bbe1b3c0000; // 物
6'd4: bitmap=256'h77fe2ffe06e614f67bf0ff9c460f3ffe3ffc318c318c33cc07fc1e7cfc1e7006; // 资
6'd5: bitmap=256'h0180ffffffff07200e703c383ffc3ffe0e640e600e601c661c677867f07e607c; // 充
6'd6: bitmap=256'h3ffc300c300c300c3ffc3ffc01c019c039fe39fe39c03dc07fff67fee0004000; // 足
6'd7: bitmap=256'h61ff61ff7c00fdfed9fe5986ff86fffe19fe3c803dc636ce76cc63ffe3ff4000; // 短
6'd8: bitmap=256'h70307f307ffef8fe58361836ff36ffff7bfe7b707b787bf87bdc7fce7f870102; // 缺
6'd9: bitmap=256'h19cc39f879f0fbc27fc73cfe00fe3ffc3ffc300c318c018c03ec1ffcfe3e7806; // 货
6'd10: bitmap=256'h7fff7fff630067fe6ffe6ce06ce07ffe7ffe61f063b86f1e64047fff7fff0000; // 医
6'd11: bitmap=256'h004000e03fff3fff3800fffe7ffef83cf878f87030703070707063f021e00000; // 疗
6'd12: bitmap=256'h307033fe33fefd8cfddc37ff37ff78c0fffff7ff339c33d831f831fcf7cef706; // 接
6'd13: bitmap=256'h207070f039f8339c072efef7f5e27788723c707871e47fce7b3c70f827e00300; // 诊
6'd14: bitmap=256'h383038307c007ffffffff980f980f9803980398039803980398039fe39fe3800; // 忙
6'd15: bitmap=256'h7ffe7dfe31fe71fe700effffffffed326db66cbe6cfc7ffe7ff66cf000e00000; // 碌
6'd16: bitmap=256'h300efffe7fe060ff7ffe7eccffccfecc1c0c00003ffc3ffc3ffc3ffc3ffc3ffc; // 暂
6'd17: bitmap=256'h3fff37fe330e730e730ef3fef000ffff3fff3c0337fe37fe307031e031e00000; // 停
6'd18: bitmap=256'h631c6ff86fdff6fffff66ff6603e7fdeffdee7de66cc67cc66de64ffe7f3e582; // 撤
6'd19: bitmap=256'h0180ffffffff366e33ce3fee3c3e3ffe3ffc7ffe7ffe6e667ff66ffe603e601c; // 离
6'd20: bitmap=256'h3fc63fd6369676d67fd67ff6fc76f316f3167fd63fd6331633c63fc63f9e301c; // 倒
6'd21: bitmap=256'h707038701070007007fff7fff0703070307034703c703c703870307020700000; // 计
6'd22: bitmap=256'h7e0e7e0e67ff67ff660e668e7fce7eee666e667e662e660e7e0e7e0e667c007c; // 时
6'd23: bitmap=256'h1c30fe30f83c39fe39b6ffb7ffb23b367b36f83efc3c7e183e3038e03bc03b00; // 秒
6'd24: bitmap=256'h0000000003e007f007780e380e380e380e380e380e380f7007f003e000000000; // 0
6'd25: bitmap=256'h0000000001c007c00fc00dc001c001c001c001c001c001c001c001c000000000; // 1
6'd26: bitmap=256'h0000000003e007f004f00070007000f001e003c007000e000ff00ff000000000; // 2
6'd27: bitmap=256'h0000000007e007f00470007000f003e003f000780038047807f007e000000000; // 3
6'd28: bitmap=256'h00000000006000e001e001e0036006600e601c601ff81ff80060006000000000; // 4
6'd29: bitmap=256'h0000000007f807f80600060007e007f0007800380038047807f003e000000000; // 5
6'd30: bitmap=256'h0000000001e003e007200e000ee00ff00f700e300e300f7007e003c000000000; // 6
6'd31: bitmap=256'h000000001ff01ff0007000e000c001c001800380038007000700070000000000; // 7
6'd32: bitmap=256'h0000000003c00ff00e700c300e7007e007e00e700c300e700ff003c000000000; // 8
6'd33: bitmap=256'h0000000003e007f00e780c380c380e7807f803b80038047007e007c000000000; // 9
default: bitmap=256'd0;
endcase
end
assign bit_on=bitmap[255-{row,col}];
endmodule
