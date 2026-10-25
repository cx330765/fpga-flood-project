`timescale 1ns/1ps
module tb_four_group_menu;
    reg clk=0,reset=1,k2=1,k3=1,k4=1,hazard=0,emergency=0;
    always #5 clk=~clk;
    wire menu,next_cmd,emerg_cmd,auto_cmd;
    wire [3:0] item,bright,contrast,sat;
    wire [1:0] group,vol,speed;
    wire [2:0] order;
    wire [9:0] value;
    wire [4:0] hour;
    wire [5:0] minute,second;
    integer next_count=0,auto_count=0,emerg_count=0,i;
    ui_controller #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(3),.LONG_PRESS_MS(40),
        .MENU_TIMEOUT_SECONDS(1),.GROUPED_MENU_ENABLE(1),.HAZARD_POLICY_ENABLE(1)) dut (
        .clk(clk),.reset(reset),.key2_n(k2),.key3_n(k3),.key4_n(k4),
        .hazard_active(hazard),.emergency_mode(emergency),.player_ready(1'b1),
        .menu_active(menu),.menu_item(item),.menu_group(group),.menu_value(value),
        .volume_level(vol),.subtitle_speed(speed),.playback_order(order),
        .brightness_level(bright),.contrast_level(contrast),.saturation_level(sat),
        .clock_hour(hour),.clock_minute(minute),.clock_second(second),
        .next_image_pulse(next_cmd),.emergency_toggle_pulse(emerg_cmd),.auto_or_route_pulse(auto_cmd));
    always @(posedge clk)begin
        if(next_cmd)next_count<=next_count+1;
        if(auto_cmd)auto_count<=auto_count+1;
        if(emerg_cmd)emerg_count<=emerg_count+1;
    end
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s item=%d group=%d",msg,item,group);$fatal(1);end end
    endtask
    task press;input integer key,n;
        begin case(key)2:k2=0;3:k3=0;4:k4=0;endcase ticks(n);
            case(key)2:k2=1;3:k3=1;4:k4=1;endcase ticks(12);end
    endtask
    initial begin
        ticks(5);reset=0;ticks(8);
        check(vol==3&&speed==1&&order==0,"defaults preserve original sound/speed/order");
        press(3,70);check(menu&&group==0&&item==0,"enter picture group");
        press(3,12);check(bright==12,"brightness increases to preset");
        press(4,12);check(bright==8,"brightness decreases");
        for(i=0;i<4;i=i+1)press(2,12);
        check(item==0&&group==0,"KEY2 wraps inside picture group");
        k4=0;ticks(1500);check(menu&&group==1&&item==4,"held KEY4 changes group once without timeout");
        k4=1;ticks(12);check(hour==12&&auto_count==0,"long release does not decrement hour or toggle auto");
        press(3,12);check(hour==13,"hour plus");press(4,12);check(hour==12,"hour minus");
        press(2,12);check(item==5,"minutes select");press(3,12);check(minute==1,"minute plus");
        press(2,12);check(item==4&&group==1,"clock group wraps");
        press(4,70);check(item==6&&group==2,"information group");
        press(3,12);check(value==121,"people plus");press(4,12);check(value==120,"people minus");
        press(2,12);check(item==7,"materials");press(3,12);check(value==1,"material update");
        press(2,12);check(item==8,"medical");press(3,12);check(value==1,"medical update");
        press(2,12);check(item==6&&group==2,"info group wraps");
        press(4,70);check(item==9&&group==3&&value==100,"playback group shows volume percent");
        press(3,12);check(vol==0&&value==25,"volume wraps to 25");
        press(3,12);check(vol==1&&value==50,"volume 50");
        press(3,12);check(vol==2&&value==75,"volume 75");
        press(3,12);check(vol==3&&value==100,"volume 100");
        press(4,12);check(vol==2,"volume decrement");
        press(2,12);check(item==10&&value==2,"speed default medium");
        press(3,12);check(speed==2&&value==3,"fast speed");
        press(3,12);check(speed==0&&value==1,"speed wraps slow");
        press(4,12);check(speed==2,"speed reverse wraps");
        press(2,12);check(item==11&&value==123,"order default");
        press(3,12);check(order==1&&value==132,"order 132");
        for(i=0;i<5;i=i+1)press(3,12);
        check(order==0&&value==123,"all six order entries wrap");
        press(4,12);check(order==5&&value==321,"order reverse wraps");
        press(2,12);check(item==9&&group==3,"playback group wraps");
        press(4,70);check(item==0&&group==0,"four groups cycle back");
        check(next_count==0&&auto_count==0&&emerg_count==0,"menu events never leak to media commands");
        // Real hazard cancels settings even while the group-switch key is held.
        k4=0;ticks(8);hazard=1;ticks(5);check(!menu,"hazard preempts menu");
        ticks(65);k4=1;ticks(12);check(auto_count==0,"hazard crossing release cannot toggle autoplay");
        press(3,70);check(!menu,"hazard denies menu");hazard=0;ticks(8);
        press(3,70);check(menu&&group==0,"reentry starts picture group");
        ticks(1050);check(!menu,"ten-second scaled timeout still works");
        press(3,70);press(2,70);check(!menu&&emerg_count==1,"manual emergency long press still wins");
        reset=1;ticks(5);check(vol==3&&speed==1&&order==0,"reset defaults");
        $display("FOUR_GROUP_MENU_CONTROL_TEST_PASSED");$finish;
    end
    initial begin #2000000;$display("FAIL group watchdog");$fatal(1);end
endmodule
