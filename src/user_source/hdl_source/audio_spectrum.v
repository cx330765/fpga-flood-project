// 扩展5：32点DFT频谱能量提取，512样本窗，单个8×8乘法器时分复用，256项余弦表内嵌

module audio_spectrum #(
    parameter BIN_COUNT  = 32,
    parameter WINDOW_LEN = 512,
    parameter MAG_SHIFT  = 8
)(
    input  wire        pixel_clk,
    input  wire        reset,
    input  wire        audio_valid,
    input  wire [23:0] audio_pcm,
    output reg  [BIN_COUNT*16-1:0] spec_energy,
    output reg         spec_valid
);
    // 半周期余弦表 256 项：0~π 按四分对称取整，索引 256~511 取负，值域 ±127
    function [7:0] cos_lut;
        input [8:0] index;
        reg [7:0] base;
        begin
            case (index[7:0])
                8'd0: base = 8'sd127;
                8'd1: base = 8'sd127;
                8'd2: base = 8'sd127;
                8'd3: base = 8'sd127;
                8'd4: base = 8'sd127;
                8'd5: base = 8'sd127;
                8'd6: base = 8'sd127;
                8'd7: base = 8'sd127;
                8'd8: base = 8'sd126;
                8'd9: base = 8'sd126;
                8'd10: base = 8'sd126;
                8'd11: base = 8'sd126;
                8'd12: base = 8'sd126;
                8'd13: base = 8'sd125;
                8'd14: base = 8'sd125;
                8'd15: base = 8'sd125;
                8'd16: base = 8'sd125;
                8'd17: base = 8'sd124;
                8'd18: base = 8'sd124;
                8'd19: base = 8'sd124;
                8'd20: base = 8'sd123;
                8'd21: base = 8'sd123;
                8'd22: base = 8'sd122;
                8'd23: base = 8'sd122;
                8'd24: base = 8'sd122;
                8'd25: base = 8'sd121;
                8'd26: base = 8'sd121;
                8'd27: base = 8'sd120;
                8'd28: base = 8'sd120;
                8'd29: base = 8'sd119;
                8'd30: base = 8'sd118;
                8'd31: base = 8'sd118;
                8'd32: base = 8'sd117;
                8'd33: base = 8'sd117;
                8'd34: base = 8'sd116;
                8'd35: base = 8'sd115;
                8'd36: base = 8'sd115;
                8'd37: base = 8'sd114;
                8'd38: base = 8'sd113;
                8'd39: base = 8'sd113;
                8'd40: base = 8'sd112;
                8'd41: base = 8'sd111;
                8'd42: base = 8'sd111;
                8'd43: base = 8'sd110;
                8'd44: base = 8'sd109;
                8'd45: base = 8'sd108;
                8'd46: base = 8'sd107;
                8'd47: base = 8'sd106;
                8'd48: base = 8'sd106;
                8'd49: base = 8'sd105;
                8'd50: base = 8'sd104;
                8'd51: base = 8'sd103;
                8'd52: base = 8'sd102;
                8'd53: base = 8'sd101;
                8'd54: base = 8'sd100;
                8'd55: base = 8'sd99;
                8'd56: base = 8'sd98;
                8'd57: base = 8'sd97;
                8'd58: base = 8'sd96;
                8'd59: base = 8'sd95;
                8'd60: base = 8'sd94;
                8'd61: base = 8'sd93;
                8'd62: base = 8'sd92;
                8'd63: base = 8'sd91;
                8'd64: base = 8'sd90;
                8'd65: base = 8'sd89;
                8'd66: base = 8'sd88;
                8'd67: base = 8'sd86;
                8'd68: base = 8'sd85;
                8'd69: base = 8'sd84;
                8'd70: base = 8'sd83;
                8'd71: base = 8'sd82;
                8'd72: base = 8'sd81;
                8'd73: base = 8'sd79;
                8'd74: base = 8'sd78;
                8'd75: base = 8'sd77;
                8'd76: base = 8'sd76;
                8'd77: base = 8'sd74;
                8'd78: base = 8'sd73;
                8'd79: base = 8'sd72;
                8'd80: base = 8'sd71;
                8'd81: base = 8'sd69;
                8'd82: base = 8'sd68;
                8'd83: base = 8'sd67;
                8'd84: base = 8'sd65;
                8'd85: base = 8'sd64;
                8'd86: base = 8'sd63;
                8'd87: base = 8'sd61;
                8'd88: base = 8'sd60;
                8'd89: base = 8'sd58;
                8'd90: base = 8'sd57;
                8'd91: base = 8'sd56;
                8'd92: base = 8'sd54;
                8'd93: base = 8'sd53;
                8'd94: base = 8'sd51;
                8'd95: base = 8'sd50;
                8'd96: base = 8'sd49;
                8'd97: base = 8'sd47;
                8'd98: base = 8'sd46;
                8'd99: base = 8'sd44;
                8'd100: base = 8'sd43;
                8'd101: base = 8'sd41;
                8'd102: base = 8'sd40;
                8'd103: base = 8'sd38;
                8'd104: base = 8'sd37;
                8'd105: base = 8'sd35;
                8'd106: base = 8'sd34;
                8'd107: base = 8'sd32;
                8'd108: base = 8'sd31;
                8'd109: base = 8'sd29;
                8'd110: base = 8'sd28;
                8'd111: base = 8'sd26;
                8'd112: base = 8'sd25;
                8'd113: base = 8'sd23;
                8'd114: base = 8'sd22;
                8'd115: base = 8'sd20;
                8'd116: base = 8'sd19;
                8'd117: base = 8'sd17;
                8'd118: base = 8'sd16;
                8'd119: base = 8'sd14;
                8'd120: base = 8'sd12;
                8'd121: base = 8'sd11;
                8'd122: base = 8'sd9;
                8'd123: base = 8'sd8;
                8'd124: base = 8'sd6;
                8'd125: base = 8'sd5;
                8'd126: base = 8'sd3;
                8'd127: base = 8'sd2;
                8'd128: base = 8'sd0;
                8'd129: base = -8'sd2;
                8'd130: base = -8'sd3;
                8'd131: base = -8'sd5;
                8'd132: base = -8'sd6;
                8'd133: base = -8'sd8;
                8'd134: base = -8'sd9;
                8'd135: base = -8'sd11;
                8'd136: base = -8'sd12;
                8'd137: base = -8'sd14;
                8'd138: base = -8'sd16;
                8'd139: base = -8'sd17;
                8'd140: base = -8'sd19;
                8'd141: base = -8'sd20;
                8'd142: base = -8'sd22;
                8'd143: base = -8'sd23;
                8'd144: base = -8'sd25;
                8'd145: base = -8'sd26;
                8'd146: base = -8'sd28;
                8'd147: base = -8'sd29;
                8'd148: base = -8'sd31;
                8'd149: base = -8'sd32;
                8'd150: base = -8'sd34;
                8'd151: base = -8'sd35;
                8'd152: base = -8'sd37;
                8'd153: base = -8'sd38;
                8'd154: base = -8'sd40;
                8'd155: base = -8'sd41;
                8'd156: base = -8'sd43;
                8'd157: base = -8'sd44;
                8'd158: base = -8'sd46;
                8'd159: base = -8'sd47;
                8'd160: base = -8'sd49;
                8'd161: base = -8'sd50;
                8'd162: base = -8'sd51;
                8'd163: base = -8'sd53;
                8'd164: base = -8'sd54;
                8'd165: base = -8'sd56;
                8'd166: base = -8'sd57;
                8'd167: base = -8'sd58;
                8'd168: base = -8'sd60;
                8'd169: base = -8'sd61;
                8'd170: base = -8'sd63;
                8'd171: base = -8'sd64;
                8'd172: base = -8'sd65;
                8'd173: base = -8'sd67;
                8'd174: base = -8'sd68;
                8'd175: base = -8'sd69;
                8'd176: base = -8'sd71;
                8'd177: base = -8'sd72;
                8'd178: base = -8'sd73;
                8'd179: base = -8'sd74;
                8'd180: base = -8'sd76;
                8'd181: base = -8'sd77;
                8'd182: base = -8'sd78;
                8'd183: base = -8'sd79;
                8'd184: base = -8'sd81;
                8'd185: base = -8'sd82;
                8'd186: base = -8'sd83;
                8'd187: base = -8'sd84;
                8'd188: base = -8'sd85;
                8'd189: base = -8'sd86;
                8'd190: base = -8'sd88;
                8'd191: base = -8'sd89;
                8'd192: base = -8'sd90;
                8'd193: base = -8'sd91;
                8'd194: base = -8'sd92;
                8'd195: base = -8'sd93;
                8'd196: base = -8'sd94;
                8'd197: base = -8'sd95;
                8'd198: base = -8'sd96;
                8'd199: base = -8'sd97;
                8'd200: base = -8'sd98;
                8'd201: base = -8'sd99;
                8'd202: base = -8'sd100;
                8'd203: base = -8'sd101;
                8'd204: base = -8'sd102;
                8'd205: base = -8'sd103;
                8'd206: base = -8'sd104;
                8'd207: base = -8'sd105;
                8'd208: base = -8'sd106;
                8'd209: base = -8'sd106;
                8'd210: base = -8'sd107;
                8'd211: base = -8'sd108;
                8'd212: base = -8'sd109;
                8'd213: base = -8'sd110;
                8'd214: base = -8'sd111;
                8'd215: base = -8'sd111;
                8'd216: base = -8'sd112;
                8'd217: base = -8'sd113;
                8'd218: base = -8'sd113;
                8'd219: base = -8'sd114;
                8'd220: base = -8'sd115;
                8'd221: base = -8'sd115;
                8'd222: base = -8'sd116;
                8'd223: base = -8'sd117;
                8'd224: base = -8'sd117;
                8'd225: base = -8'sd118;
                8'd226: base = -8'sd118;
                8'd227: base = -8'sd119;
                8'd228: base = -8'sd120;
                8'd229: base = -8'sd120;
                8'd230: base = -8'sd121;
                8'd231: base = -8'sd121;
                8'd232: base = -8'sd122;
                8'd233: base = -8'sd122;
                8'd234: base = -8'sd122;
                8'd235: base = -8'sd123;
                8'd236: base = -8'sd123;
                8'd237: base = -8'sd124;
                8'd238: base = -8'sd124;
                8'd239: base = -8'sd124;
                8'd240: base = -8'sd125;
                8'd241: base = -8'sd125;
                8'd242: base = -8'sd125;
                8'd243: base = -8'sd125;
                8'd244: base = -8'sd126;
                8'd245: base = -8'sd126;
                8'd246: base = -8'sd126;
                8'd247: base = -8'sd126;
                8'd248: base = -8'sd126;
                8'd249: base = -8'sd127;
                8'd250: base = -8'sd127;
                8'd251: base = -8'sd127;
                8'd252: base = -8'sd127;
                8'd253: base = -8'sd127;
                8'd254: base = -8'sd127;
                8'd255: base = -8'sd127;
                default: base = 8'd0;
            endcase
            cos_lut = index[8] ? (~base + 8'd1) : base;
        end
    endfunction

    // 26 位累加器余量：512 点 × 8bit×8bit 最大 512×16256 = 8.3M < 2^23
    function [26:0] abs27;
        input [25:0] value;
        begin
            abs27 = value[25] ? (~{1'b1, value} + 27'd1) : {1'b0, value};
        end
    endfunction

    localparam ST_IDLE = 2'd0;
    localparam ST_MAC  = 2'd1;
    localparam ST_SNAP = 2'd2;

    reg [1:0]  state;
    reg        mac_sin;
    reg [4:0]  bin_idx;
    reg [9:0]  sample_cnt;
    reg signed [7:0] pcm8;

    reg [8:0]  phase  [0:BIN_COUNT-1];
    reg signed [25:0] acc_re [0:BIN_COUNT-1];
    reg signed [25:0] acc_im [0:BIN_COUNT-1];

    // cos 查表相位 384 = 移相 −90°，即 sin；im 按标准 DFT 取负
    wire [8:0] lut_index = mac_sin ? (phase[bin_idx] + 9'd384) : phase[bin_idx];
    wire signed [7:0]  lut_value = cos_lut(lut_index);
    wire signed [15:0] product   = pcm8 * lut_value;

    integer i;
    reg [26:0] mag_sum;

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            state       <= ST_IDLE;
            mac_sin     <= 1'b0;
            bin_idx     <= 5'd0;
            sample_cnt  <= 10'd0;
            pcm8        <= 8'sd0;
            spec_valid  <= 1'b0;
            spec_energy <= {BIN_COUNT*16{1'b0}};
            for (i = 0; i < BIN_COUNT; i = i + 1) begin
                phase[i]  <= 9'd0;
                acc_re[i] <= 26'sd0;
                acc_im[i] <= 26'sd0;
            end
        end
        else begin
            spec_valid <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (audio_valid) begin
                        pcm8    <= audio_pcm[23:16];
                        bin_idx <= 5'd0;
                        mac_sin <= 1'b0;
                        state   <= ST_MAC;
                    end
                end
                ST_MAC: begin
                    if (!mac_sin) begin
                        acc_re[bin_idx] <= acc_re[bin_idx] + product;
                        mac_sin <= 1'b1;
                    end
                    else begin
                        acc_im[bin_idx] <= acc_im[bin_idx] - product;
                        phase[bin_idx]  <= phase[bin_idx] + bin_idx;
                        mac_sin <= 1'b0;
                        if (bin_idx == BIN_COUNT - 1) begin
                            sample_cnt <= sample_cnt + 1'b1;
                            state <= (sample_cnt == WINDOW_LEN - 1) ? ST_SNAP : ST_IDLE;
                        end
                        else bin_idx <= bin_idx + 1'b1;
                    end
                end
                ST_SNAP: begin
                    for (i = 0; i < BIN_COUNT; i = i + 1) begin
                        // 能量 = |re| + |im|，右移 MAG_SHIFT 后饱和到 16bit
                        mag_sum = abs27(acc_re[i]) + abs27(acc_im[i]);
                        spec_energy[i*16 +: 16] <= (mag_sum >> MAG_SHIFT) > 27'd65535 ?
                            16'hFFFF : (mag_sum >> MAG_SHIFT);
                        acc_re[i] <= 26'sd0;
                        acc_im[i] <= 26'sd0;
                        phase[i]  <= 9'd0;
                    end
                    spec_valid <= 1'b1;
                    sample_cnt <= 10'd0;
                    state      <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
