module font_rom_ascii (
    input  wire [7:0] character_code,
    input  wire [3:0] row,
    input  wire [2:0] column,
    output reg        font_bit
);

    reg [63:0] glyph;
    reg [7:0] row_data;

    always @(*) begin
        case (character_code)
            8'h20: glyph = 64'h0000000000000000; // space
            8'h3A: glyph = 64'h0018180018180000; // colon
            8'h41: glyph = 64'h1824427E42424200; // A
            8'h42: glyph = 64'h7C42427C42427C00; // B
            8'h43: glyph = 64'h3C42404040423C00; // C
            8'h44: glyph = 64'h7844424242447800; // D
            8'h45: glyph = 64'h7E40407C40407E00; // E
            8'h46: glyph = 64'h7E40407C40404000; // F
            8'h47: glyph = 64'h3C42404E42423C00; // G
            8'h48: glyph = 64'h4242427E42424200; // H
            8'h49: glyph = 64'h3E08080808083E00; // I
            8'h4B: glyph = 64'h4244487048444200; // K
            8'h4C: glyph = 64'h4040404040407E00; // L
            8'h4D: glyph = 64'h42665A5A42424200; // M
            8'h4E: glyph = 64'h4262524A46424200; // N
            8'h4F: glyph = 64'h3C42424242423C00; // O
            8'h50: glyph = 64'h7C42427C40404000; // P
            8'h52: glyph = 64'h7C42427C48444200; // R
            8'h53: glyph = 64'h3C42403C02423C00; // S
            8'h54: glyph = 64'h7F08080808080800; // T
            8'h56: glyph = 64'h4242424224241800; // V
            8'h59: glyph = 64'h4141221408080800; // Y
            8'h78: glyph = 64'h0000422418244200; // x
            default: glyph = 64'h0000000000000000;
        endcase

        case (row[3:1])
            3'd0: row_data = glyph[63:56];
            3'd1: row_data = glyph[55:48];
            3'd2: row_data = glyph[47:40];
            3'd3: row_data = glyph[39:32];
            3'd4: row_data = glyph[31:24];
            3'd5: row_data = glyph[23:16];
            3'd6: row_data = glyph[15:8];
            3'd7: row_data = glyph[7:0];
            default: row_data = 8'h00;
        endcase

        font_bit = row_data[7 - column];
    end

endmodule
