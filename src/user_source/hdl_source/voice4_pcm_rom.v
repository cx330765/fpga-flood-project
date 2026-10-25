// Image 4 original-quality 8-bit PCM, split across seven 32K BRAMs.
module voice4_pcm_rom(input wire clk, input wire [14:0] addr, output reg [7:0] dout);
wire [7:0] b0;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b00.mif"),.FILL_ALL("NONE")) u_b0 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b0),.dob());
wire [7:0] b1;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b01.mif"),.FILL_ALL("NONE")) u_b1 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b1),.dob());
wire [7:0] b2;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b02.mif"),.FILL_ALL("NONE")) u_b2 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b2),.dob());
wire [7:0] b3;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b03.mif"),.FILL_ALL("NONE")) u_b3 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b3),.dob());
wire [7:0] b4;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b04.mif"),.FILL_ALL("NONE")) u_b4 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b4),.dob());
wire [7:0] b5;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b05.mif"),.FILL_ALL("NONE")) u_b5 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b5),.dob());
wire [7:0] b6;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img4_pcm_b06.mif"),.FILL_ALL("NONE")) u_b6 (.dia(8'd0),.dib(8'd0),.addra(addr[11:0]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(b6),.dob());
always @* begin
  dout = 8'h80;
  case (addr[14:12])
    0: dout = b0;
    1: dout = b1;
    2: dout = b2;
    3: dout = b3;
    4: dout = b4;
    5: dout = b5;
    6: dout = b6;
    default: dout = 8'h80;
  endcase
end
endmodule
