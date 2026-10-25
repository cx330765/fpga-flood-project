`timescale 1ns/1ps
module tb_hazard_policy;
    reg clk=0, reset=1;
    reg [3:0] switches=0;
    always #5 clk=~clk;
    wire [3:0] h, hl;
    wire active, evac, both, rb, locked;
    wire [2:0] reason;
    integer i;
    hazard_policy #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(3)) dut (
        .clk(clk),.reset(reset),.switches(switches),.hazards(h),
        .active(active),.evacuation(evac),.all_exits_blocked(both),
        .route_b(rb),.route_locked(locked),.reason(reason));
    hazard_policy #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(3),.SWITCH_ACTIVE_LOW(4'b1111)) low_dut (
        .clk(clk),.reset(reset),.switches(~switches),.hazards(hl));
    task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
    task check; input good; input [8*100-1:0] msg;
        begin if(good!==1'b1)begin $display("FAIL %0s input=%b",msg,switches);$fatal(1);end end
    endtask
    initial begin
        ticks(5);reset=0;ticks(10);
        switches=1;ticks(1);switches=0;ticks(12);check(h==0,"bounce filtered");
        for(i=0;i<16;i=i+1)begin
            switches=i;ticks(10);
            check(h==i && hl==i,"vector and configurable polarity");
            check(active==(|switches),"active");
            check(evac==(switches[3]|switches[1]|switches[0]),"medical cannot mask evacuation");
            check(both==(switches[0]&switches[1]),"no route when both closed");
            check(rb==(switches[0]&!switches[1]),"choose available exit");
            check(locked==(switches[0]|switches[1]),"availability veto");
            check(reason==(switches[3]?5:both?4:switches[0]?2:switches[1]?3:switches[2]?1:0),"priority");
        end
        switches=0;ticks(10);check(h==0,"clear all");
        $display("HAZARD_ALL_16_COMBINATIONS_TEST_PASSED");$finish;
    end
endmodule
