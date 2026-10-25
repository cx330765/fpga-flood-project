module font_rom (
    input  wire [3:0] character_code,
    input  wire [3:0] row,
    input  wire [2:0] column,

    output reg         font_bit
);

    reg [63:0] glyph;
    reg [7:0]  row_data;

    /*
     * ????????8×8???
     * ?????????????8×16???
     */
    always @(*) begin
        case (character_code)
            4'd0: glyph = 64'h3C666E7666663C00;
            4'd1: glyph = 64'h1838181818187E00;
            4'd2: glyph = 64'h3C66060C30607E00;
            4'd3: glyph = 64'h3C66061C06663C00;
            4'd4: glyph = 64'h0C1C3C6C7E0C0C00;
            4'd5: glyph = 64'h7E607C0606663C00;
            4'd6: glyph = 64'h1C30607C66663C00;
            4'd7: glyph = 64'h7E060C1830303000;
            4'd8: glyph = 64'h3C66663C66663C00;
            4'd9: glyph = 64'h3C66663E060C3800;

            default:
                glyph = 64'h0000000000000000;
        endcase

        // row[3:1]???????????
        case (row[3:1])
            3'd0: row_data = glyph[63:56];
            3'd1: row_data = glyph[55:48];
            3'd2: row_data = glyph[47:40];
            3'd3: row_data = glyph[39:32];
            3'd4: row_data = glyph[31:24];
            3'd5: row_data = glyph[23:16];
            3'd6: row_data = glyph[15:8];
            3'd7: row_data = glyph[7:0];

            default:
                row_data = 8'h00;
        endcase

        if (character_code <= 4'd9)
            font_bit = row_data[7 - column];
        else
            font_bit = 1'b0;
    end

endmodule