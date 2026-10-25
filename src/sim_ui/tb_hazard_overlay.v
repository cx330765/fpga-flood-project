`timescale 1ns/1ps
module tb_hazard_overlay;
    reg clk=0,reset=1,de=0,vs=0,hs=0;
    reg [3:0] hazards=0;
    reg emergency=0, route=0;
    wire [23:0] rgb;
    wire ho,vo,deo;
    integer i,j;
    always #5 clk=~clk;
    hazard_overlay dut(.pixel_clk(clk),.reset(reset),.hazards_control(hazards),
        .emergency_control(emergency),.route_b_control(route),.rgb_in(24'hAABBCC),
        .hs_in(hs),.vs_in(vs),.de_in(de),.rgb_out(rgb),.hs_out(ho),.vs_out(vo),.de_out(deo));
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s",msg);$fatal(1);end end
    endtask
    task frame;begin de=0;vs=0;ticks(6);vs=1;ticks(2);vs=0;ticks(2);end endtask
    // Independent raster drive for a point, not an internal counter force.
    task point;input integer px,py;
        begin frame;
            for(j=0;j<py;j=j+1)begin de=1;ticks(640);de=0;ticks(3);end
            de=1;ticks(px+1);end
    endtask
    initial begin
        ticks(5);reset=0;frame;
        // Full frame bypass plus registered HS/VS/DE: normal picture unchanged.
        for(j=0;j<480;j=j+1)begin
            de=1;for(i=0;i<640;i=i+1)begin
                hs=i[0];ticks(1);check(rgb==24'hAABBCC&&deo&&ho==hs,"normal pixel/timing bypass");
            end de=0;ticks(3);check(rgb==0&&!deo,"blanking alignment");
        end
        hazards=1;emergency=1;point(254,225);check(rgb==24'h081018,"hide A vertical static arrow");
        point(370,177);check(rgb==24'h081018,"hide A horizontal static arrow");
        point(360,350);check(rgb==24'hAABBCC,"retain B branch");
        hazards=2;point(340,294);check(rgb==24'h081018,"hide blocked B static arrow");
        point(370,177);check(rgb==24'hAABBCC,"retain A route");
        hazards=3;point(254,345);check(rgb==24'h081018,"hide dynamic/start map in waiting mode");
        point(547,90);check(rgb==24'h081018,"hide conflicting evacuation countdown");
        point(100,170);check(rgb==24'hAABBCC,"retain left safety instructions");
        // New state must not tear a frame; publish only on VS rising edge.
        hazards=0;ticks(8);check(dut.state_frame[3:0]==3,"frame boundary latch");
        point(254,345);check(rgb==24'hAABBCC,"normal overlay restored");
        $display("HAZARD_OVERLAY_PIXEL_TEST_PASSED");$finish;
    end
    initial begin #30000000;$display("FAIL overlay watchdog");$fatal(1);end
endmodule
