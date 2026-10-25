`timescale 1ns/1ps
module tb_subtitle_speed;
    reg clk=0,rst=1,vs=0;
    reg [1:0] speed=1;
    always #5 clk=~clk;
    integer before_x,i,s;
    scroll_text #(.RUNTIME_SPEED_ENABLE(1)) dut (
        .pixel_clk(clk),.reset(rst),.rgb_in(24'd0),.hs_in(1'b0),.vs_in(vs),.de_in(1'b0),
        .scroll_enable(1'b1),.status_panel_visible(1'b1),.speed_level(speed));
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task frame;begin vs=1;ticks(2);vs=0;ticks(3);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s",msg);$fatal(1);end end
    endtask
    initial begin
        ticks(5);rst=0;
        for(s=0;s<3;s=s+1)begin
            speed=s;frame;frame;frame;frame;
            before_x=dut.scroll_x;
            for(i=0;i<8;i=i+1)frame;
            check(before_x-dut.scroll_x==(s==0?2:s==1?4:8),"4/2/1 frame periods drive actual scroll position");
        end
        check(dut.scroll_x<504,"changing speed does not reset text position");
        $display("SUBTITLE_THREE_SPEEDS_TEST_PASSED");$finish;
    end
endmodule
