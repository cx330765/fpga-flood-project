`timescale 1ns/1ps
module tb_ui_controller;
    reg clk=0, reset=1, k2=1, k3=1, k4=1, emergency=0, ready=1;
    always #5 clk=~clk;
    wire next_image, emergency_toggle, auto_route, pause_play, menu;
    wire [3:0] item, brightness, contrast, saturation;
    wire [9:0] value;
    wire auto_bright, adjust, sat_mode, time_mode;
    wire [4:0] hour;
    wire [5:0] minute, second;
    wire [1:0] edit_mode, material, medical;
    wire [3:0] ph, pt, po;
    integer next_count=0, emergency_count=0, auto_count=0;
    integer i;
    ui_controller #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(3), .LONG_PRESS_MS(40),
        .MENU_TIMEOUT_SECONDS(1), .DEFAULT_HOUR(23), .DEFAULT_MINUTE(59), .DEFAULT_SECOND(58)) dut (
        .clk(clk), .reset(reset), .key2_n(k2), .key3_n(k3), .key4_n(k4),
        .emergency_mode(emergency), .player_ready(ready),
        .next_image_pulse(next_image), .emergency_toggle_pulse(emergency_toggle),
        .auto_or_route_pulse(auto_route), .playback_pause(pause_play),
        .menu_active(menu), .menu_item(item), .menu_value(value),
        .brightness_level(brightness), .contrast_level(contrast), .saturation_level(saturation),
        .auto_brightness(auto_bright), .adjust_mode(adjust), .saturation_mode(sat_mode),
        .time_set_mode(time_mode), .clock_hour(hour), .clock_minute(minute), .clock_second(second),
        .status_edit_mode(edit_mode), .people_hundreds(ph), .people_tens(pt), .people_ones(po),
        .material_state(material), .medical_state(medical));
    always @(posedge clk) if (!reset) begin
        if (next_image) next_count=next_count+1;
        if (emergency_toggle) emergency_count=emergency_count+1;
        if (auto_route) auto_count=auto_count+1;
        if (menu && (next_image || auto_route)) begin
            $display("FAIL menu leaked playback command"); $fatal(1);
        end
        if ((next_image && auto_route) || (next_image && emergency_toggle) ||
            (auto_route && emergency_toggle)) begin
            $display("FAIL simultaneous unrelated commands"); $fatal(1);
        end
    end
    task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
    task check; input good; input [8*100-1:0] message;
        begin if (good !== 1'b1) begin $display("FAIL: %0s",message); $fatal(1); end end
    endtask
    task press; input integer key; input integer duration;
        begin
            case(key) 2:k2=0; 3:k3=0; 4:k4=0; endcase
            ticks(duration);
            case(key) 2:k2=1; 3:k3=1; 4:k4=1; endcase
            ticks(12);
        end
    endtask
    task select_item; input integer target;
        begin
            for(i=0; i<9 && item!=target; i=i+1) press(2,12);
            check(item==target,"item selection");
        end
    endtask
    initial begin
        ticks(5); reset=0; ticks(10);
        check(brightness==8 && contrast==8 && saturation==8,"default picture values");
        // Short contact bounce below debounce threshold must do nothing.
        k2=0; ticks(1); k2=1; ticks(1); k2=0; ticks(1); k2=1; ticks(10);
        check(next_count==0,"contact bounce ignored");
        press(2,12); check(next_count==1 && emergency_count==0,"normal short KEY2");
        press(4,12); check(auto_count==1,"normal short KEY4");
        press(3,12); check(!menu && brightness==8,"normal short KEY3 does not change picture");
        ready=0; press(3,70); check(!menu,"busy player denies menu entry"); ready=1;
        press(3,70); check(menu && item==0 && brightness==8,"long KEY3 enters without increment");
        press(3,12); check(brightness==12,"menu advances brightness 8 to 12");
        press(4,12); check(brightness==8 && auto_count==1,"menu decrement does not toggle auto");
        select_item(1); press(3,12); check(contrast==12 && adjust,"contrast selection");
        select_item(2); press(3,12); check(saturation==12 && sat_mode,"saturation selection");
        select_item(3); press(3,12); check(auto_bright && brightness==8,"night auto brightness");
        select_item(4); press(3,12); check(hour==0 && time_mode && !adjust,"hour wraps 23 to 0");
        press(4,12); check(hour==23,"hour decrement wraps 0 to 23");
        select_item(5); press(3,12); check(minute==0 && adjust,"minute wraps 59 to 0");
        press(4,12); check(minute==59,"minute decrement wraps 0 to 59");
        ticks(1300); check(!menu,"idle timeout exits menu");
        check(second==0,"seconds reset during clock edit");
        ticks(2300); check(hour==23 && minute==59 && second==2,"clock resumes after save");
        ticks(58000); check(hour==0 && minute==0 && second==0,"clock rolls midnight");
        press(3,70); select_item(6);
        press(4,12); check(ph==1 && pt==1 && po==9 && edit_mode==1,"people BCD borrow");
        press(3,12); check(ph==1 && pt==2 && po==0,"people BCD carry");
        select_item(7); press(4,12); check(material==2 && edit_mode==2,"material backward cycle");
        press(3,12); check(material==0,"material forward cycle");
        select_item(8); press(4,12); check(medical==2 && edit_mode==3,"medical backward cycle");
        press(3,12); check(medical==0,"medical forward cycle");
        press(2,12); check(item==0 && next_count==1,"menu wraps without changing image");
        press(3,70); check(!menu && brightness==8 && auto_bright,"long save has no extra increment");
        press(3,70); press(2,70);
        check(!menu && emergency_count==1 && next_count==1,"long KEY2 preempts menu without short");
        emergency=1; ticks(10); press(3,70); check(!menu,"emergency denies menu");
        press(2,12); check(next_count==1,"emergency ignores ordinary next");
        press(4,12); check(auto_count==2,"emergency route command");
        press(2,70); check(emergency_count==2,"emergency exit command");
        // KEY4 held in emergency, then emergency exits: release must not toggle auto.
        k4=0; ticks(12); emergency=0; ticks(2); k4=1; ticks(12);
        check(auto_count==2,"release context prevents emergency-to-normal leakage");
        // KEY4 starts in menu, then KEY3 long exits: no autoplay on its release.
        press(3,70); k4=0; ticks(12); press(3,70); k4=1; ticks(12);
        check(!menu && auto_count==2,"menu-to-normal release does not toggle autoplay");
        press(3,70); select_item(0);
        press(4,12); check(brightness==4 && !auto_bright,"brightness 8 to 4 cancels auto mode");
        press(4,12); check(brightness==15,"brightness reverse wrap 4 to 15");
        press(4,12); check(brightness==12,"brightness reverse 15 to 12");
        press(4,12); check(brightness==8,"brightness reverse 12 to 8");
        press(3,12); check(brightness==12,"brightness forward 8 to 12");
        press(3,12); check(brightness==15,"brightness forward 12 to 15");
        press(3,12); check(brightness==4,"brightness forward wrap 15 to 4");
        press(3,12); check(brightness==8,"brightness forward 4 to 8");
        select_item(1);
        press(3,12); check(contrast==15,"contrast 12 to 15");
        press(3,12); check(contrast==4,"contrast forward wrap");
        press(3,12); check(contrast==8,"contrast 4 to 8");
        press(3,12); check(contrast==12,"contrast 8 to 12");
        press(4,12); check(contrast==8,"contrast 12 to 8");
        press(4,12); check(contrast==4,"contrast 8 to 4");
        press(4,12); check(contrast==15,"contrast reverse wrap");
        press(4,12); check(contrast==12,"contrast 15 to 12");
        select_item(2);
        press(3,12); check(saturation==15,"saturation 12 to 15");
        press(3,12); check(saturation==4,"saturation forward wrap");
        press(3,12); check(saturation==8,"saturation 4 to 8");
        press(3,12); check(saturation==12,"saturation 8 to 12");
        press(4,12); check(saturation==8,"saturation 12 to 8");
        press(4,12); check(saturation==4,"saturation 8 to 4");
        press(4,12); check(saturation==15,"saturation reverse wrap");
        press(4,12); check(saturation==12,"saturation 15 to 12");
        select_item(6);
        for(i=0;i<890;i=i+1) press(3,12);
        check(ph==9 && pt==9 && po==9,"people upper bound 999");
        for(i=0;i<1010;i=i+1) press(4,12);
        check(ph==0 && pt==0 && po==0,"people lower bound 000");
        ready=0; press(2,70); check(!menu && emergency_count==2,"busy emergency request is not emitted");
        ready=1; press(4,70); check(auto_count==2,"KEY4 long has no short side effect");
        k2=0; k4=0; ticks(12); k2=1; k4=1; ticks(12);
        check(next_count==2 && auto_count==2,"simultaneous release prioritizes next image");
        reset=1; ticks(3); reset=0; ticks(10);
        check(!menu && brightness==8 && contrast==8 && saturation==8 && ph==1 && pt==2 && po==0,
              "reset restores UI defaults");
        $display("UI_STAGE1_CONTROLLER_TEST_PASSED"); $finish;
    end
    initial begin #2000000; $display("FAIL watchdog"); $fatal(1); end
endmodule
