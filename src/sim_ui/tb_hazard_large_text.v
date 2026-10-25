`timescale 1ns/1ps
// Layout-only checks isolate renderer coordinates; raster/timing is covered
// separately by tb_hazard_overlay. Production fonts and policy are unchanged.
module tb_hazard_large_text;
    reg clk=0,reset=1,de=0,vs=0;
    reg [3:0] hazards=0;
    wire [23:0] rgb;
    integer xx,yy,id,count;
    reg [5:0] expected_code;
    reg [255:0] expected_glyph;
    reg expected_bit;
    always #5 clk=~clk;
    hazard_overlay dut(.pixel_clk(clk),.reset(reset),.hazards_control(hazards),
        .emergency_control(1'b1),.route_b_control(1'b0),.rgb_in(24'hAABBCC),
        .hs_in(1'b0),.vs_in(vs),.de_in(de),.rgb_out(rgb));
    task ticks; input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s x=%0d y=%0d",msg,xx,yy);$fatal(1);end end
    endtask
    task publish;input [3:0]value;
        begin de=0;vs=0;hazards=value;ticks(8);vs=1;ticks(2);vs=0;ticks(2);end
    endtask
    task sample;input integer px,py;
        begin
            force dut.x=px;force dut.y=py;de=1;ticks(1);
            release dut.x;release dut.y;
        end
    endtask
    task banner_check;input [3:0]value;input integer left,right,message;
        begin publish(value);
            sample(10,450);check(!dut.banner_text,"left margin contains no text");
            sample(left,440);check(dut.banner_text,"bottom left boundary");
            sample(right-1,471);check(dut.banner_text,"bottom right boundary");
            sample(right,450);check(!dut.banner_text,"right boundary exclusive");
            check(left+right==640,"bottom text centred on whole screen");
            count=0;
            for(yy=440;yy<472;yy=yy+1)begin
                for(xx=left;xx<right;xx=xx+1)begin
                    expected_code=dut.message_code(message,(xx-left)>>5);
                    expected_glyph=dut.glyph(expected_code);
                    expected_bit=expected_glyph[255-((((yy-440)>>1)*16)+(((xx-left)>>1)%16))];
                    sample(xx,yy);
                    check(rgb==(expected_bit?24'hFFFF20:24'h081018),"2x bottom glyph has no clipping");
                    if(expected_bit)count=count+1;
                end
            end
            check(count>100,"bottom text visible");
        end
    endtask
    initial begin
        ticks(5);reset=0;
        banner_check(1,160,480,0);banner_check(2,160,480,1);
        banner_check(3,144,496,2);banner_check(8,176,464,3);
        banner_check(4,224,416,4);
        publish(3);
        sample(216,224);check(dut.heading,"heading starts at expected larger position");
        sample(599,287);check(dut.heading,"heading covers 384x64");
        sample(600,250);check(!dut.heading,"heading width bound");
        check(216+600==2*408,"heading centred in right black area");
        for(yy=224;yy<288;yy=yy+1)begin
            for(xx=216;xx<600;xx=xx+1)begin
                expected_code=dut.message_code(6,(xx-216)>>6);
                expected_glyph=dut.glyph(expected_code);
                expected_bit=expected_glyph[255-((((yy-224)>>2)*16)+(((xx-216)>>2)%16))];
                sample(xx,yy);
                check(rgb==(expected_bit?24'hFFFF20:24'h081018),"4x heading glyph mapping");
            end
        end
        sample(232,316);check(dut.instruction,"instruction enlarged start");
        sample(583,347);check(dut.instruction,"instruction covers 352x32");
        check(232+584==2*408,"instruction centred with heading");
        for(yy=316;yy<348;yy=yy+1)begin
            for(xx=232;xx<584;xx=xx+1)begin
                expected_code=dut.message_code(7,(xx-232)>>5);
                expected_glyph=dut.glyph(expected_code);
                expected_bit=expected_glyph[255-((((yy-316)>>1)*16)+(((xx-232)>>1)%16))];
                sample(xx,yy);
                check(rgb==(expected_bit?24'hFFFF20:24'h081018),"2x instruction glyph mapping");
            end
        end
        $display("HAZARD_LARGE_TEXT_LAYOUT_TEST_PASSED");$finish;
    end
    initial begin #3000000;$display("FAIL layout watchdog");$fatal(1);end
endmodule
