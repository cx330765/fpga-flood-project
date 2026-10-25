// Geometry matches the current 640x480 emergency BMP, not arbitrary maps.
// One pixel of latency, including all timing signals. No extra frame memory.
module hazard_overlay (
    input wire pixel_clk, reset,
    input wire [3:0] hazards_control,
    input wire emergency_control,
    input wire route_b_control,
    input wire [23:0] rgb_in,
    input wire hs_in, vs_in, de_in,
    output reg [23:0] rgb_out,
    output reg hs_out, vs_out, de_out
);
    reg [5:0] state_meta, state_sync, state_previous, state_frame;
    reg [9:0] x, y;
    reg de_d, vs_d;
    wire frame_start = vs_in && !vs_d;
    wire [3:0] h = state_frame[3:0];
    wire active = |h;
    wire emergency = state_frame[4];
    wire blocked_both = h[0] && h[1];
    wire evacuation = h[0] || h[1] || h[3];
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            state_meta<=0; state_sync<=0; state_previous<=0; state_frame<=0;
            x<=0; y<=0; de_d<=0; vs_d<=0;
        end else begin
            state_meta <= {route_b_control,emergency_control,hazards_control};
            state_sync <= state_meta;
            state_previous <= state_sync;
            // A bus changing at this very frame edge waits for the next one.
            if (frame_start && state_sync == state_previous) state_frame <= state_sync;
            de_d <= de_in; vs_d <= vs_in;
            if (frame_start) begin x<=0; y<=0; end
            else begin
                if (de_in) x<=x+1'b1; else x<=0;
                if (de_d && !de_in) y<=y+1'b1;
            end
        end
    end
    // IDs: 0 A blocked, 1 B blocked, 2 both, 3 emergency, 4 medical,
    // 5 load pending, 6 central heading, 7 central waiting instruction.
    function [5:0] message_code;
        input [2:0] id;
        input [4:0] pos;
        begin
            message_code=63;
            case(id)
                0,1: case(pos)
                    0,7:message_code=0; 1,8:message_code=1;
                    2:message_code=(id==0)?35:36;
                    3:message_code=2; 4:message_code=3;
                    5:message_code=4; 6:message_code=5;
                    9:message_code=(id==0)?36:35; default:;
                endcase
                2,6: case(pos)
                    0:message_code=0; 1:message_code=1; 2:message_code=6;
                    3:message_code=7; 4:message_code=8; 5:message_code=9;
                    6:if(id==2)message_code=4; 7:if(id==2)message_code=10;
                    8:if(id==2)message_code=11; 9:if(id==2)message_code=12;
                    10:if(id==2)message_code=13; default:;
                endcase
                3,5: case(pos)
                    0:message_code=26; 1:message_code=27;
                    2:message_code=28; 3:message_code=29;
                    4:message_code=(id==5)?30:4;
                    5:message_code=(id==5)?31:5;
                    6:message_code=(id==5)?32:0;
                    7:message_code=(id==5)?33:1;
                    8:message_code=(id==5)?34:(state_frame[5]?36:35); default:;
                endcase
                4: case(pos)
                    0:message_code=20; 1:message_code=21; 2:message_code=22;
                    3:message_code=23; 4:message_code=24; 5:message_code=25; default:;
                endcase
                7: case(pos)
                    0:message_code=4; 1:message_code=10; 2:message_code=11;
                    3:message_code=12; 4:message_code=13; 5:message_code=14;
                    6:message_code=15; 7:message_code=16; 8:message_code=17;
                    9:message_code=18; 10:message_code=19; default:;
                endcase
                default:;
            endcase
        end
    endfunction
    // 字模改由同步 ROM 提供，见文件末尾 hazard_glyph_rom
    wire map_wait = emergency && blocked_both &&
                    x>=180 && x<636 && y>=145 && y<424;
    // Hide blocked route segments INCLUDING arrows already painted in the BMP.
    // Preserve the shared start and the safe branch. Cross out its exit icon.
    wire mask_a = emergency && h[0] && !blocked_both &&
        ((x>=240 && x<500 && y>=160 && y<197) ||
         (x>=239 && x<267 && y>=176 && y<293) ||
         (x>=562 && x<608 && y>=158 && y<302));
    wire mask_b = emergency && h[1] && !blocked_both &&
        ((x>=261 && x<365 && y>=282 && y<309) ||
         (x>=346 && x<369 && y>=291 && y<365) ||
         (x>=360 && x<556 && y>=336 && y<365));
    wire cross_a_area = emergency && h[0] && !blocked_both &&
                        x>=496 && x<536 && y>=148 && y<188;
    wire cross_b_area = emergency && h[1] && !blocked_both &&
                        x>=446 && x<486 && y>=332 && y<372;
    wire [5:0] ca_x=x-496, ca_y=y-148, cb_x=x-446, cb_y=y-332;
    wire cross_a = cross_a_area && ((ca_x>ca_y?ca_x-ca_y:ca_y-ca_x)<4 ||
                                   (ca_x+ca_y>=36 && ca_x+ca_y<=42));
    wire cross_b = cross_b_area && ((cb_x>cb_y?cb_x-cb_y:cb_y-cb_x)<4 ||
                                   (cb_x+cb_y>=36 && cb_x+cb_y<=42));
    wire banner = active && y>=432 && y<480 && x>=4 && x<636;
    // A visible "evacuate in 30s" instruction conflicts with a closed-exits
    // decision. Cover only that original panel; its internal timer is intact.
    wire wait_panel = emergency && blocked_both &&
                      x>=544 && x<636 && y>=84 && y<144;
    wire wait_text = wait_panel && x>=552 && x<616 && y>=108 && y<124;
    wire [2:0] banner_id = evacuation && !emergency ? 3'd5 :
        blocked_both ? 3'd2 : h[3] ? 3'd3 : h[0] ? 3'd0 : h[1] ? 3'd1 : 3'd4;
    // Keep the original mask and map geometry. Centre the waiting messages
    // in the right-hand black area [180,636), whose centre is x=408.
    // Heading: 6 x 64-pixel cells (4x font); instruction: 11 x 32 (2x).
    wire heading = map_wait && x>=216 && x<600 && y>=224 && y<288;
    wire instruction = map_wait && x>=232 && x<584 && y>=316 && y<348;
    // Bottom messages have different lengths; centre each actual message,
    // not a fixed-width field containing unused trailing spaces.
    wire [9:0] banner_x0 = (banner_id==0 || banner_id==1) ? 10'd160 :
        banner_id==2 ? 10'd144 : banner_id==4 ? 10'd224 : 10'd176;
    wire [9:0] banner_x1 = (banner_id==0 || banner_id==1) ? 10'd480 :
        banner_id==2 ? 10'd496 : banner_id==4 ? 10'd416 : 10'd464;
    wire banner_text = banner && x>=banner_x0 && x<banner_x1 && y>=440 && y<472;
    wire [9:0] local_x = wait_text ? x-552 : heading ? ((x-216)>>2) :
                         instruction ? ((x-232)>>1) : ((x-banner_x0)>>1);
    wire [9:0] local_y = wait_text ? y-108 : heading ? ((y-224)>>2) :
                         instruction ? ((y-316)>>1) : ((y-440)>>1);
    wire [5:0] code = wait_text ?
        (local_x[5:4]==0 ? 6'd10 : local_x[5:4]==1 ? 6'd11 : local_x[5:4]==2 ? 6'd12 : 6'd13) :
        message_code(heading?3'd6:instruction?3'd7:banner_id, local_x[8:4]);
    wire [9:0] glyph_addr = {code, local_y[3:0]};
    wire [15:0] glyph_word;
    hazard_glyph_rom u_glyph (.clk(pixel_clk), .addr(glyph_addr), .q(glyph_word));

    // 区域判定一起打一拍，和 ROM 的 1 拍读延迟对齐
    reg text_area_d, banner_edge_d, cross_d, mask_d, hs_d2, vs_d2, de_d2;
    reg [3:0] col_d;
    reg [23:0] rgb_d;
    wire text_area = heading || instruction || banner_text || wait_text;
    wire banner_edge = banner && (y<435 || y>=477);
    wire cross_any = cross_a || cross_b;
    wire mask_any = map_wait || mask_a || mask_b || banner || wait_panel;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            text_area_d<=0; banner_edge_d<=0; cross_d<=0; mask_d<=0;
            hs_d2<=0; vs_d2<=0; de_d2<=0; col_d<=0; rgb_d<=0;
        end else begin
            text_area_d<=text_area; banner_edge_d<=banner_edge;
            cross_d<=cross_any; mask_d<=mask_any;
            hs_d2<=hs_in; vs_d2<=vs_in; de_d2<=de_in;
            col_d<=local_x[3:0]; rgb_d<=rgb_in;
        end
    end
    wire text_bit = glyph_word[15-col_d];

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin rgb_out<=0; hs_out<=0; vs_out<=0; de_out<=0; end
        else begin
            hs_out<=hs_d2; vs_out<=vs_d2; de_out<=de_d2;
            if (!de_d2) rgb_out<=0;
            else if (text_area_d && text_bit) rgb_out<=24'hFFFF20;
            else if (banner_edge_d) rgb_out<=24'hFF2020;
            else if (cross_d) rgb_out<=24'hFF2020;
            else if (mask_d) rgb_out<=24'h081018;
            else rgb_out<=rgb_d;
        end
    end
endmodule

// 汉字字模同步 ROM，37 码 x 16 行 x 16 位；读延迟 1 拍
module hazard_glyph_rom (
    input  wire        clk,
    input  wire [9:0]  addr,
    output reg  [15:0] q
);
    reg [15:0] mem [0:591];
    initial begin
        mem[0] = 16'h0000;
        mem[1] = 16'h0000;
        mem[2] = 16'h0c00;
        mem[3] = 16'hccc0;
        mem[4] = 16'hccc0;
        mem[5] = 16'hccc0;
        mem[6] = 16'hffc0;
        mem[7] = 16'h0c00;
        mem[8] = 16'h8c40;
        mem[9] = 16'h8c40;
        mem[10] = 16'h8c40;
        mem[11] = 16'hffc0;
        mem[12] = 16'h0040;
        mem[13] = 16'h0000;
        mem[14] = 16'h0000;
        mem[15] = 16'h0000;
        mem[16] = 16'h0000;
        mem[17] = 16'h0000;
        mem[18] = 16'h0000;
        mem[19] = 16'hffc0;
        mem[20] = 16'hc0c0;
        mem[21] = 16'hc0c0;
        mem[22] = 16'hc0c0;
        mem[23] = 16'hc0c0;
        mem[24] = 16'hc0c0;
        mem[25] = 16'hc0c0;
        mem[26] = 16'hc0c0;
        mem[27] = 16'hffc0;
        mem[28] = 16'hc0c0;
        mem[29] = 16'h0000;
        mem[30] = 16'h0000;
        mem[31] = 16'h0000;
        mem[32] = 16'h0000;
        mem[33] = 16'h0000;
        mem[34] = 16'hffc0;
        mem[35] = 16'h4cc0;
        mem[36] = 16'h6d80;
        mem[37] = 16'hffc0;
        mem[38] = 16'h8040;
        mem[39] = 16'h0000;
        mem[40] = 16'h7f80;
        mem[41] = 16'h6180;
        mem[42] = 16'h3f00;
        mem[43] = 16'h3f00;
        mem[44] = 16'hf3c0;
        mem[45] = 16'h0000;
        mem[46] = 16'h0000;
        mem[47] = 16'h0000;
        mem[48] = 16'h0000;
        mem[49] = 16'h0000;
        mem[50] = 16'hffc0;
        mem[51] = 16'hbc40;
        mem[52] = 16'hac40;
        mem[53] = 16'hafc0;
        mem[54] = 16'hec40;
        mem[55] = 16'hbc40;
        mem[56] = 16'hbfc0;
        mem[57] = 16'hbc40;
        mem[58] = 16'hec40;
        mem[59] = 16'h8c40;
        mem[60] = 16'h9fe0;
        mem[61] = 16'h0000;
        mem[62] = 16'h0000;
        mem[63] = 16'h0000;
        mem[64] = 16'h0000;
        mem[65] = 16'h8200;
        mem[66] = 16'hffe0;
        mem[67] = 16'h4200;
        mem[68] = 16'h1fc0;
        mem[69] = 16'h0200;
        mem[70] = 16'hffe0;
        mem[71] = 16'hd8c0;
        mem[72] = 16'hdfc0;
        mem[73] = 16'hd8c0;
        mem[74] = 16'hffc0;
        mem[75] = 16'hd8c0;
        mem[76] = 16'h98c0;
        mem[77] = 16'h03c0;
        mem[78] = 16'h0000;
        mem[79] = 16'h0000;
        mem[80] = 16'h0000;
        mem[81] = 16'h0000;
        mem[82] = 16'h0c00;
        mem[83] = 16'hffc0;
        mem[84] = 16'h0c00;
        mem[85] = 16'h0c00;
        mem[86] = 16'hffe0;
        mem[87] = 16'h0c00;
        mem[88] = 16'h6c00;
        mem[89] = 16'h4fc0;
        mem[90] = 16'hec00;
        mem[91] = 16'hfc00;
        mem[92] = 16'h9fe0;
        mem[93] = 16'h0000;
        mem[94] = 16'h0000;
        mem[95] = 16'h0000;
        mem[96] = 16'h0000;
        mem[97] = 16'h0000;
        mem[98] = 16'hc400;
        mem[99] = 16'hcc00;
        mem[100] = 16'hcfc0;
        mem[101] = 16'hf840;
        mem[102] = 16'hc640;
        mem[103] = 16'hc240;
        mem[104] = 16'hc140;
        mem[105] = 16'hc640;
        mem[106] = 16'he840;
        mem[107] = 16'h80c0;
        mem[108] = 16'h03c0;
        mem[109] = 16'h0000;
        mem[110] = 16'h0000;
        mem[111] = 16'h0000;
        mem[112] = 16'h0000;
        mem[113] = 16'h0000;
        mem[114] = 16'hffc0;
        mem[115] = 16'h0c00;
        mem[116] = 16'h0c00;
        mem[117] = 16'h1c00;
        mem[118] = 16'h3d00;
        mem[119] = 16'h6f80;
        mem[120] = 16'hcce0;
        mem[121] = 16'h8c40;
        mem[122] = 16'h0c00;
        mem[123] = 16'h0c00;
        mem[124] = 16'h0c00;
        mem[125] = 16'h0000;
        mem[126] = 16'h0000;
        mem[127] = 16'h0000;
        mem[128] = 16'h0000;
        mem[129] = 16'h0000;
        mem[130] = 16'hffe0;
        mem[131] = 16'h0080;
        mem[132] = 16'h0080;
        mem[133] = 16'h7c80;
        mem[134] = 16'h4c80;
        mem[135] = 16'h4c80;
        mem[136] = 16'h4c80;
        mem[137] = 16'h7c80;
        mem[138] = 16'h4080;
        mem[139] = 16'h0080;
        mem[140] = 16'h0780;
        mem[141] = 16'h0000;
        mem[142] = 16'h0000;
        mem[143] = 16'h0000;
        mem[144] = 16'h0000;
        mem[145] = 16'h0000;
        mem[146] = 16'hffc0;
        mem[147] = 16'hccc0;
        mem[148] = 16'hccc0;
        mem[149] = 16'hffc0;
        mem[150] = 16'hccc0;
        mem[151] = 16'hccc0;
        mem[152] = 16'hffc0;
        mem[153] = 16'hccc0;
        mem[154] = 16'hccc0;
        mem[155] = 16'h8cc0;
        mem[156] = 16'h8fc0;
        mem[157] = 16'h0000;
        mem[158] = 16'h0000;
        mem[159] = 16'h0000;
        mem[160] = 16'h0000;
        mem[161] = 16'h0000;
        mem[162] = 16'hffe0;
        mem[163] = 16'hc600;
        mem[164] = 16'hdfc0;
        mem[165] = 16'hd0c0;
        mem[166] = 16'hdfc0;
        mem[167] = 16'hd0c0;
        mem[168] = 16'hdfc0;
        mem[169] = 16'hc200;
        mem[170] = 16'hd280;
        mem[171] = 16'hb3c0;
        mem[172] = 16'hee40;
        mem[173] = 16'h0000;
        mem[174] = 16'h0000;
        mem[175] = 16'h0000;
        mem[176] = 16'h0000;
        mem[177] = 16'h0000;
        mem[178] = 16'hc300;
        mem[179] = 16'hdb00;
        mem[180] = 16'hdb00;
        mem[181] = 16'hdbc0;
        mem[182] = 16'hff40;
        mem[183] = 16'hdb40;
        mem[184] = 16'hdb40;
        mem[185] = 16'hdbc0;
        mem[186] = 16'hfb40;
        mem[187] = 16'hd860;
        mem[188] = 16'h0fc0;
        mem[189] = 16'h0000;
        mem[190] = 16'h0000;
        mem[191] = 16'h0000;
        mem[192] = 16'h0000;
        mem[193] = 16'h0000;
        mem[194] = 16'h4300;
        mem[195] = 16'hfbe0;
        mem[196] = 16'ha780;
        mem[197] = 16'hbc80;
        mem[198] = 16'hffc0;
        mem[199] = 16'h0c00;
        mem[200] = 16'hffe0;
        mem[201] = 16'h0100;
        mem[202] = 16'hffc0;
        mem[203] = 16'h3100;
        mem[204] = 16'h2f00;
        mem[205] = 16'h0000;
        mem[206] = 16'h0000;
        mem[207] = 16'h0000;
        mem[208] = 16'h0000;
        mem[209] = 16'h0000;
        mem[210] = 16'h4300;
        mem[211] = 16'h7fc0;
        mem[212] = 16'hc300;
        mem[213] = 16'h8300;
        mem[214] = 16'h3fe0;
        mem[215] = 16'h4080;
        mem[216] = 16'hdfe0;
        mem[217] = 16'h4880;
        mem[218] = 16'h4c80;
        mem[219] = 16'h4480;
        mem[220] = 16'h4380;
        mem[221] = 16'h0000;
        mem[222] = 16'h0000;
        mem[223] = 16'h0000;
        mem[224] = 16'h0000;
        mem[225] = 16'h0000;
        mem[226] = 16'hffc0;
        mem[227] = 16'h0c00;
        mem[228] = 16'h0c00;
        mem[229] = 16'h0c00;
        mem[230] = 16'h0c00;
        mem[231] = 16'h0c00;
        mem[232] = 16'h0c00;
        mem[233] = 16'h0c00;
        mem[234] = 16'h0c00;
        mem[235] = 16'h0c00;
        mem[236] = 16'hffe0;
        mem[237] = 16'h0000;
        mem[238] = 16'h0000;
        mem[239] = 16'h0000;
        mem[240] = 16'h0000;
        mem[241] = 16'h0000;
        mem[242] = 16'h6c00;
        mem[243] = 16'h6c00;
        mem[244] = 16'h4fe0;
        mem[245] = 16'hde00;
        mem[246] = 16'hd600;
        mem[247] = 16'hf7c0;
        mem[248] = 16'h4600;
        mem[249] = 16'h4600;
        mem[250] = 16'h47c0;
        mem[251] = 16'h4600;
        mem[252] = 16'h4600;
        mem[253] = 16'h0000;
        mem[254] = 16'h0000;
        mem[255] = 16'h0000;
        mem[256] = 16'h0000;
        mem[257] = 16'h0000;
        mem[258] = 16'h0c00;
        mem[259] = 16'h0c00;
        mem[260] = 16'h0c00;
        mem[261] = 16'h0c00;
        mem[262] = 16'h0c00;
        mem[263] = 16'h1c00;
        mem[264] = 16'h1e00;
        mem[265] = 16'h3200;
        mem[266] = 16'h6300;
        mem[267] = 16'hc180;
        mem[268] = 16'h8040;
        mem[269] = 16'h0000;
        mem[270] = 16'h0000;
        mem[271] = 16'h0000;
        mem[272] = 16'h0000;
        mem[273] = 16'h0000;
        mem[274] = 16'h7f80;
        mem[275] = 16'h4080;
        mem[276] = 16'h7f80;
        mem[277] = 16'h0000;
        mem[278] = 16'hffc0;
        mem[279] = 16'hc0c0;
        mem[280] = 16'hccc0;
        mem[281] = 16'hccc0;
        mem[282] = 16'h1f00;
        mem[283] = 16'h3180;
        mem[284] = 16'hc040;
        mem[285] = 16'h0000;
        mem[286] = 16'h0000;
        mem[287] = 16'h0000;
        mem[288] = 16'h0000;
        mem[289] = 16'h0000;
        mem[290] = 16'hd8c0;
        mem[291] = 16'hdf80;
        mem[292] = 16'hf840;
        mem[293] = 16'hcfc0;
        mem[294] = 16'hc000;
        mem[295] = 16'hcfc0;
        mem[296] = 16'he840;
        mem[297] = 16'hcfc0;
        mem[298] = 16'hc840;
        mem[299] = 16'hcfc0;
        mem[300] = 16'hc840;
        mem[301] = 16'h0000;
        mem[302] = 16'h0000;
        mem[303] = 16'h0000;
        mem[304] = 16'h0000;
        mem[305] = 16'h0000;
        mem[306] = 16'hdfe0;
        mem[307] = 16'hd660;
        mem[308] = 16'he600;
        mem[309] = 16'hdfc0;
        mem[310] = 16'hcc00;
        mem[311] = 16'heb00;
        mem[312] = 16'hdfc0;
        mem[313] = 16'hc300;
        mem[314] = 16'hffe0;
        mem[315] = 16'hc300;
        mem[316] = 16'hc300;
        mem[317] = 16'h0000;
        mem[318] = 16'h0000;
        mem[319] = 16'h0000;
        mem[320] = 16'h0000;
        mem[321] = 16'h0000;
        mem[322] = 16'hffe0;
        mem[323] = 16'h9800;
        mem[324] = 16'h9800;
        mem[325] = 16'hbfc0;
        mem[326] = 16'ha600;
        mem[327] = 16'hbfc0;
        mem[328] = 16'h8e00;
        mem[329] = 16'h9980;
        mem[330] = 16'hb0c0;
        mem[331] = 16'h8000;
        mem[332] = 16'hffe0;
        mem[333] = 16'h0000;
        mem[334] = 16'h0000;
        mem[335] = 16'h0000;
        mem[336] = 16'h0000;
        mem[337] = 16'h0000;
        mem[338] = 16'h0600;
        mem[339] = 16'h7fe0;
        mem[340] = 16'he000;
        mem[341] = 16'he000;
        mem[342] = 16'h7fc0;
        mem[343] = 16'hc1c0;
        mem[344] = 16'hc300;
        mem[345] = 16'h4300;
        mem[346] = 16'hc300;
        mem[347] = 16'hc300;
        mem[348] = 16'h8e00;
        mem[349] = 16'h0000;
        mem[350] = 16'h0000;
        mem[351] = 16'h0000;
        mem[352] = 16'h0000;
        mem[353] = 16'h0000;
        mem[354] = 16'h3b00;
        mem[355] = 16'h2b00;
        mem[356] = 16'hfbe0;
        mem[357] = 16'h2640;
        mem[358] = 16'haec0;
        mem[359] = 16'hbec0;
        mem[360] = 16'hf380;
        mem[361] = 16'hf980;
        mem[362] = 16'haf80;
        mem[363] = 16'h6ee0;
        mem[364] = 16'he440;
        mem[365] = 16'h0000;
        mem[366] = 16'h0000;
        mem[367] = 16'h0000;
        mem[368] = 16'h0000;
        mem[369] = 16'h0000;
        mem[370] = 16'hf200;
        mem[371] = 16'h9200;
        mem[372] = 16'hf7c0;
        mem[373] = 16'h9240;
        mem[374] = 16'h9240;
        mem[375] = 16'hf240;
        mem[376] = 16'h9640;
        mem[377] = 16'h9640;
        mem[378] = 16'h9e40;
        mem[379] = 16'hfc40;
        mem[380] = 16'h05c0;
        mem[381] = 16'h0000;
        mem[382] = 16'h0000;
        mem[383] = 16'h0000;
        mem[384] = 16'h0000;
        mem[385] = 16'h0000;
        mem[386] = 16'h6d80;
        mem[387] = 16'h6cc0;
        mem[388] = 16'h4c00;
        mem[389] = 16'hffe0;
        mem[390] = 16'hcf00;
        mem[391] = 16'hcf00;
        mem[392] = 16'hcf00;
        mem[393] = 16'hcb00;
        mem[394] = 16'hdb60;
        mem[395] = 16'hf360;
        mem[396] = 16'hd1c0;
        mem[397] = 16'h0000;
        mem[398] = 16'h0000;
        mem[399] = 16'h0000;
        mem[400] = 16'h0000;
        mem[401] = 16'h0000;
        mem[402] = 16'h6c00;
        mem[403] = 16'h6c00;
        mem[404] = 16'hffc0;
        mem[405] = 16'h8c00;
        mem[406] = 16'h0c00;
        mem[407] = 16'hffe0;
        mem[408] = 16'h3200;
        mem[409] = 16'h3200;
        mem[410] = 16'h3260;
        mem[411] = 16'h6260;
        mem[412] = 16'h83c0;
        mem[413] = 16'h0000;
        mem[414] = 16'h0000;
        mem[415] = 16'h0000;
        mem[416] = 16'h0000;
        mem[417] = 16'h0000;
        mem[418] = 16'h3fc0;
        mem[419] = 16'hbcc0;
        mem[420] = 16'hb780;
        mem[421] = 16'hbce0;
        mem[422] = 16'h3800;
        mem[423] = 16'h7e00;
        mem[424] = 16'h7980;
        mem[425] = 16'hffc0;
        mem[426] = 16'h2d00;
        mem[427] = 16'hecc0;
        mem[428] = 16'h9c40;
        mem[429] = 16'h0000;
        mem[430] = 16'h0000;
        mem[431] = 16'h0000;
        mem[432] = 16'h0000;
        mem[433] = 16'h0000;
        mem[434] = 16'h3000;
        mem[435] = 16'h7f00;
        mem[436] = 16'hc300;
        mem[437] = 16'hffc0;
        mem[438] = 16'h00c0;
        mem[439] = 16'h7fc0;
        mem[440] = 16'h00c0;
        mem[441] = 16'hffc0;
        mem[442] = 16'hfcc0;
        mem[443] = 16'hb740;
        mem[444] = 16'hbfc0;
        mem[445] = 16'h0000;
        mem[446] = 16'h0000;
        mem[447] = 16'h0000;
        mem[448] = 16'h0000;
        mem[449] = 16'h0800;
        mem[450] = 16'hbe80;
        mem[451] = 16'h9de0;
        mem[452] = 16'hd540;
        mem[453] = 16'hbf40;
        mem[454] = 16'h8140;
        mem[455] = 16'hffc0;
        mem[456] = 16'hb6c0;
        mem[457] = 16'hbec0;
        mem[458] = 16'hb6c0;
        mem[459] = 16'hbf60;
        mem[460] = 16'hb600;
        mem[461] = 16'h0c00;
        mem[462] = 16'h0000;
        mem[463] = 16'h0000;
        mem[464] = 16'h0000;
        mem[465] = 16'h0c00;
        mem[466] = 16'hffe0;
        mem[467] = 16'h3200;
        mem[468] = 16'hcfc0;
        mem[469] = 16'hf3c0;
        mem[470] = 16'hffc0;
        mem[471] = 16'h0800;
        mem[472] = 16'hffc0;
        mem[473] = 16'h9240;
        mem[474] = 16'hb340;
        mem[475] = 16'hbf40;
        mem[476] = 16'h81c0;
        mem[477] = 16'h0000;
        mem[478] = 16'h0000;
        mem[479] = 16'h0000;
        mem[480] = 16'h0000;
        mem[481] = 16'h0000;
        mem[482] = 16'hf600;
        mem[483] = 16'hb7c0;
        mem[484] = 16'hbcc0;
        mem[485] = 16'hf780;
        mem[486] = 16'h6780;
        mem[487] = 16'hece0;
        mem[488] = 16'hf7c0;
        mem[489] = 16'he440;
        mem[490] = 16'he440;
        mem[491] = 16'hf7c0;
        mem[492] = 16'he440;
        mem[493] = 16'h0000;
        mem[494] = 16'h0000;
        mem[495] = 16'h0000;
        mem[496] = 16'h0000;
        mem[497] = 16'h0000;
        mem[498] = 16'h4780;
        mem[499] = 16'h46c0;
        mem[500] = 16'hc7c0;
        mem[501] = 16'hbe00;
        mem[502] = 16'he600;
        mem[503] = 16'h67e0;
        mem[504] = 16'hde40;
        mem[505] = 16'he2c0;
        mem[506] = 16'hc3c0;
        mem[507] = 16'h1f60;
        mem[508] = 16'hf9c0;
        mem[509] = 16'h0000;
        mem[510] = 16'h0000;
        mem[511] = 16'h0000;
        mem[512] = 16'h0000;
        mem[513] = 16'h0000;
        mem[514] = 16'hb300;
        mem[515] = 16'hffe0;
        mem[516] = 16'hb300;
        mem[517] = 16'hf300;
        mem[518] = 16'hbfc0;
        mem[519] = 16'h0c00;
        mem[520] = 16'hffe0;
        mem[521] = 16'h1c80;
        mem[522] = 16'h77c0;
        mem[523] = 16'hf780;
        mem[524] = 16'h38c0;
        mem[525] = 16'h0000;
        mem[526] = 16'h0000;
        mem[527] = 16'h0000;
        mem[528] = 16'h0000;
        mem[529] = 16'h0000;
        mem[530] = 16'h2280;
        mem[531] = 16'hfec0;
        mem[532] = 16'h2280;
        mem[533] = 16'hffe0;
        mem[534] = 16'h6300;
        mem[535] = 16'hff40;
        mem[536] = 16'hf3c0;
        mem[537] = 16'hff80;
        mem[538] = 16'h33e0;
        mem[539] = 16'hffe0;
        mem[540] = 16'h37c0;
        mem[541] = 16'h0000;
        mem[542] = 16'h0000;
        mem[543] = 16'h0000;
        mem[544] = 16'h0000;
        mem[545] = 16'h0000;
        mem[546] = 16'h0c00;
        mem[547] = 16'h0c00;
        mem[548] = 16'hffc0;
        mem[549] = 16'h8c40;
        mem[550] = 16'h8c40;
        mem[551] = 16'h8c40;
        mem[552] = 16'hffc0;
        mem[553] = 16'h8c40;
        mem[554] = 16'h0c00;
        mem[555] = 16'h0c00;
        mem[556] = 16'h0c00;
        mem[557] = 16'h0000;
        mem[558] = 16'h0000;
        mem[559] = 16'h0000;
        mem[560] = 16'h0000;
        mem[561] = 16'h0000;
        mem[562] = 16'h0000;
        mem[563] = 16'h3000;
        mem[564] = 16'h7800;
        mem[565] = 16'h7800;
        mem[566] = 16'h5800;
        mem[567] = 16'hcc00;
        mem[568] = 16'hfc00;
        mem[569] = 16'hfc00;
        mem[570] = 16'h8600;
        mem[571] = 16'h8600;
        mem[572] = 16'h0000;
        mem[573] = 16'h0000;
        mem[574] = 16'h0000;
        mem[575] = 16'h0000;
        mem[576] = 16'h0000;
        mem[577] = 16'h0000;
        mem[578] = 16'h0000;
        mem[579] = 16'hfc00;
        mem[580] = 16'hfe00;
        mem[581] = 16'hce00;
        mem[582] = 16'hf800;
        mem[583] = 16'hfc00;
        mem[584] = 16'hc600;
        mem[585] = 16'hc600;
        mem[586] = 16'hfe00;
        mem[587] = 16'hfc00;
        mem[588] = 16'h0000;
        mem[589] = 16'h0000;
        mem[590] = 16'h0000;
        mem[591] = 16'h0000;
    end
    always @(posedge clk) q <= mem[addr];
endmodule

