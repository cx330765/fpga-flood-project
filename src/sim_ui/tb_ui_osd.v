`timescale 1ns/1ps
module tb_ui_osd;
    reg clk=0, reset=1, hs=0, vs=0, de=0, menu=0;
    reg [3:0] item=2;
    reg [9:0] value=9;
    reg [23:0] input_rgb=24'h315173;
    always #5 clk=~clk;
    wire [23:0] rgb_new, rgb_old;
    wire hn,vn,dn,ho,vo,d_o;
    integer x,y,lit=0;
    video_osd #(.GROUPED_MENU_ENABLE(1)) dut (
        .pixel_clk(clk),.reset(reset),.rgb_in(input_rgb),.hs_in(hs),.vs_in(vs),.de_in(de),
        .image_index(2'd0),.source_width(16'd640),.source_height(16'd480),
        .auto_play_status(1'b0),.load_busy_status(1'b0),
        .brightness_level(4'd8),.contrast_level(4'd8),.saturation_level(4'd8),
        .adjust_mode(1'b0),.saturation_mode(1'b0),.osd_enable(1'b1),
        .auto_brightness_mode(1'b0),.time_set_mode(1'b0),
        .menu_active(menu),.menu_item(item),.menu_value(value),
        .clock_hour(5'd12),.clock_minute(6'd0),.clock_second(6'd0),
        .rgb_out(rgb_new),.hs_out(hn),.vs_out(vn),.de_out(dn));
    video_osd_baseline baseline (
        .pixel_clk(clk),.reset(reset),.rgb_in(input_rgb),.hs_in(hs),.vs_in(vs),.de_in(de),
        .image_index(2'd0),.source_width(16'd640),.source_height(16'd480),
        .auto_play_status(1'b0),.load_busy_status(1'b0),
        .brightness_level(4'd8),.contrast_level(4'd8),.saturation_level(4'd8),
        .adjust_mode(1'b0),.saturation_mode(1'b0),.osd_enable(1'b1),
        .auto_brightness_mode(1'b0),.time_set_mode(1'b0),
        .clock_hour(5'd12),.clock_minute(6'd0),.clock_second(6'd0),
        .rgb_out(rgb_old),.hs_out(ho),.vs_out(vo),.de_out(d_o));
    task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
    task check; input good; input [8*100-1:0] message;
        begin if(good!==1'b1) begin $display("FAIL: %0s x=%0d y=%0d",message,x,y); $fatal(1); end end
    endtask
    task frame;
        begin
            de=0; vs=1; ticks(2); vs=0; ticks(2);
            for(y=0;y<480;y=y+1) begin
                for(x=0;x<640;x=x+1) begin
                    de=1; ticks(1);
                    check({hn,vn,dn}==={ho,vo,d_o},"menu must preserve sync and DE latency");
                    if(!menu) check(rgb_new===rgb_old,"menu-off output matches original OSD exactly");
                    else if(x<8 || x>=96 || y<8 || y>=92)
                        check(rgb_new===rgb_old,"menu remains inside original panel");
                    if(menu && x>=14 && x<86 && y>=26 && y<42 && rgb_new==24'hFFFF00) lit=lit+1;
                end
                de=0; hs=1; ticks(2); hs=0; ticks(2);
            end
        end
    endtask
    initial begin
        ticks(4); reset=0; ticks(3); frame;
        menu=1; frame;
        check(lit>30,"menu label and value have visible glyph pixels");
        check(dut.menu_item_latched==2 && dut.menu_value_latched==9,"menu values latched at frame start");
        value=10; ticks(4); check(dut.menu_value_latched==9,"value cannot tear in mid frame");
        vs=1; ticks(2); vs=0; ticks(2);
        check(dut.menu_value_latched==10,"next frame receives new value");
        item=9;value=100;vs=1;ticks(2);vs=0;ticks(2);
        check(dut.menu_label=="VOL","volume label");
        force dut.x_cnt=14;ticks(1);check(dut.menu_is_digit&&dut.menu_digit==4,"playback group visible as 4");
        force dut.x_cnt=62;ticks(1);check(dut.menu_digit==1,"volume hundred digit");
        force dut.x_cnt=78;ticks(1);check(dut.menu_digit==0,"volume ones digit fits panel");
        release dut.x_cnt;
        item=10;value=3;vs=1;ticks(2);vs=0;ticks(2);check(dut.menu_label=="SPD","speed label");
        item=11;value=321;vs=1;ticks(2);vs=0;ticks(2);check(dut.menu_label=="ORD","order label");
        $display("UI_STAGE1_OSD_TEST_PASSED"); $finish;
    end
    initial begin #10000000; $display("FAIL OSD watchdog"); $fatal(1); end
endmodule
