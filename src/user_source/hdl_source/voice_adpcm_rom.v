// Auto-generated image 1-3, 4-bit IMA-ADPCM voice ROM bank.
module voice_adpcm_rom(input wire clk, input wire [1:0] voice_sel, input wire [14:0] addr, output reg [3:0] dout);
wire [3:0] v0b0;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b00.mif"),.FILL_ALL("NONE")) u_v0_b0 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b0),.dob());
wire [3:0] v0b1;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b01.mif"),.FILL_ALL("NONE")) u_v0_b1 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b1),.dob());
wire [3:0] v0b2;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b02.mif"),.FILL_ALL("NONE")) u_v0_b2 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b2),.dob());
wire [3:0] v0b3;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b03.mif"),.FILL_ALL("NONE")) u_v0_b3 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b3),.dob());
wire [3:0] v0b4;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b04.mif"),.FILL_ALL("NONE")) u_v0_b4 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b4),.dob());
wire [3:0] v0b5;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b05.mif"),.FILL_ALL("NONE")) u_v0_b5 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b5),.dob());
wire [3:0] v0b6;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b06.mif"),.FILL_ALL("NONE")) u_v0_b6 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b6),.dob());
wire [3:0] v0b7;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b07.mif"),.FILL_ALL("NONE")) u_v0_b7 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b7),.dob());
wire [3:0] v0b8;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b08.mif"),.FILL_ALL("NONE")) u_v0_b8 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b8),.dob());
wire [3:0] v0b9;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b09.mif"),.FILL_ALL("NONE")) u_v0_b9 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b9),.dob());
wire [3:0] v0b10;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b10.mif"),.FILL_ALL("NONE")) u_v0_b10 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b10),.dob());
wire [3:0] v0b11;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b11.mif"),.FILL_ALL("NONE")) u_v0_b11 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b11),.dob());
wire [3:0] v0b12;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b12.mif"),.FILL_ALL("NONE")) u_v0_b12 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b12),.dob());
wire [3:0] v0b13;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img1_b13.mif"),.FILL_ALL("NONE")) u_v0_b13 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v0b13),.dob());
wire [3:0] v1b0;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b00.mif"),.FILL_ALL("NONE")) u_v1_b0 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b0),.dob());
wire [3:0] v1b1;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b01.mif"),.FILL_ALL("NONE")) u_v1_b1 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b1),.dob());
wire [3:0] v1b2;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b02.mif"),.FILL_ALL("NONE")) u_v1_b2 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b2),.dob());
wire [3:0] v1b3;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b03.mif"),.FILL_ALL("NONE")) u_v1_b3 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b3),.dob());
wire [3:0] v1b4;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b04.mif"),.FILL_ALL("NONE")) u_v1_b4 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b4),.dob());
wire [3:0] v1b5;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b05.mif"),.FILL_ALL("NONE")) u_v1_b5 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b5),.dob());
wire [3:0] v1b6;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b06.mif"),.FILL_ALL("NONE")) u_v1_b6 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b6),.dob());
wire [3:0] v1b7;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b07.mif"),.FILL_ALL("NONE")) u_v1_b7 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b7),.dob());
wire [3:0] v1b8;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b08.mif"),.FILL_ALL("NONE")) u_v1_b8 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b8),.dob());
wire [3:0] v1b9;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b09.mif"),.FILL_ALL("NONE")) u_v1_b9 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b9),.dob());
wire [3:0] v1b10;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b10.mif"),.FILL_ALL("NONE")) u_v1_b10 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b10),.dob());
wire [3:0] v1b11;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(4),.ADDR_WIDTH_A(11),.DATA_DEPTH_A(2048),.DATA_WIDTH_B(4),.ADDR_WIDTH_B(11),.DATA_DEPTH_B(2048),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img2_b11.mif"),.FILL_ALL("NONE")) u_v1_b11 (.dia(4'd0),.dib(4'd0),.addra(addr[10:0]),.addrb(11'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v1b11),.dob());
wire [7:0] v2b0;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img3_b00.mif"),.FILL_ALL("NONE")) u_v2_b0 (.dia(8'd0),.dib(8'd0),.addra(addr[12:1]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v2b0),.dob());
wire [7:0] v2b1;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img3_b01.mif"),.FILL_ALL("NONE")) u_v2_b1 (.dia(8'd0),.dib(8'd0),.addra(addr[12:1]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v2b1),.dob());
wire [7:0] v2b2;
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(12),.DATA_DEPTH_A(4096),.DATA_WIDTH_B(8),.ADDR_WIDTH_B(12),.DATA_DEPTH_B(4096),.MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("python/voice_adpcm/img3_b02.mif"),.FILL_ALL("NONE")) u_v2_b2 (.dia(8'd0),.dib(8'd0),.addra(addr[12:1]),.addrb(12'd0),.cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),.clka(clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(v2b2),.dob());
always @* begin
  dout = 4'd0;
  case (voice_sel)
    2'd0: case (addr[14:11])
      0: dout = v0b0;
      1: dout = v0b1;
      2: dout = v0b2;
      3: dout = v0b3;
      4: dout = v0b4;
      5: dout = v0b5;
      6: dout = v0b6;
      7: dout = v0b7;
      8: dout = v0b8;
      9: dout = v0b9;
      10: dout = v0b10;
      11: dout = v0b11;
      12: dout = v0b12;
      13: dout = v0b13;
      default: dout = 4'd0; endcase
    2'd1: case (addr[14:11])
      0: dout = v1b0;
      1: dout = v1b1;
      2: dout = v1b2;
      3: dout = v1b3;
      4: dout = v1b4;
      5: dout = v1b5;
      6: dout = v1b6;
      7: dout = v1b7;
      8: dout = v1b8;
      9: dout = v1b9;
      10: dout = v1b10;
      11: dout = v1b11;
      default: dout = 4'd0; endcase
    2'd2: case (addr[14:13])
      0: dout = addr[0] ? v2b0[7:4] : v2b0[3:0];
      1: dout = addr[0] ? v2b1[7:4] : v2b1[3:0];
      2: dout = addr[0] ? v2b2[7:4] : v2b2[3:0];
      default: dout = 4'd0; endcase
    default: dout = 4'd0;
  endcase
end
endmodule
