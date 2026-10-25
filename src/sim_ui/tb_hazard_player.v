`timescale 1ns/1ps
// Real debounce + UI + SD image FSM. Only media dependencies are simulated.
module tb_hazard_player;
    reg clk=0,rst=1,k2=1,k3=1,k4=1;
    reg [3:0] switches=0;
    always #5 clk=~clk;
    wire [3:0] hazards;
    wire hazard_active,evac,both,forced_b,locked;
    wire next_cmd,emerg_cmd,auto_cmd,pause_play,menu;
    wire [1:0] image;
    wire valid,busy,fade,emergency,route,auto_on;
    reg finish_toggle=0,finish_enable=1;
    reg [15:0] load_ticks=0,fade_ticks=0;
    integer wait_count, load_starts=0, starts_saved, i;
    hazard_policy #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(3)) policy (
        .clk(clk),.reset(rst),.switches(switches),.hazards(hazards),
        .active(hazard_active),.evacuation(evac),.all_exits_blocked(both),
        .route_b(forced_b),.route_locked(locked));
    ui_controller #(.CLK_FREQ_HZ(1000),.DEBOUNCE_MS(3),.LONG_PRESS_MS(40),
        .MENU_TIMEOUT_SECONDS(20),.HAZARD_POLICY_ENABLE(1),.GROUPED_MENU_ENABLE(1)) ui (
        .clk(clk),.reset(rst),.key2_n(k2),.key3_n(k3),.key4_n(k4),
        .emergency_mode(emergency),.hazard_active(hazard_active),.player_ready(valid&&!busy&&!fade),
        .next_image_pulse(next_cmd),.emergency_toggle_pulse(emerg_cmd),
        .auto_or_route_pulse(auto_cmd),.playback_pause(pause_play),.menu_active(menu));
    sd_card_bmp #(.EXTERNAL_UI(1),.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_CYCLES(10000),
        .HAZARD_POLICY_ENABLE(1)) player (
        .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_auto_allowed(1'b1),
        .clock_set_active(pause_play),.ui_next_pulse(next_cmd),.ui_emergency_pulse(emerg_cmd),
        .ui_auto_route_pulse(auto_cmd),.hazard_active(hazard_active),.hazard_evacuation(evac),
        .hazard_route_locked(locked),.hazard_route_b(forced_b),
        .voice_done(1'b1),.bmp_width(16'd1280),.bmp_height(16'd960),
        .write_finish_toggle(finish_toggle),.fade_black_ready(fade&&fade_ticks>=30),
        .write_req_ack(1'b1),.SD_MISO(1'b1),.current_image_index(image),
        .display_valid(valid),.load_busy_status(busy),.fade_request_status(fade),
        .emergency_mode_status(emergency),.accessible_route_status(route),.auto_play_status(auto_on));
    always @(posedge clk or posedge rst)begin
        if(rst)begin finish_toggle<=0;load_ticks<=0;fade_ticks<=0;end
        else begin
            if(player.load_start_pulse)load_starts<=load_starts+1;
            if(!busy)load_ticks<=0;
            else begin load_ticks<=load_ticks+1'b1;
                if(load_ticks==119&&finish_enable)finish_toggle<=~finish_toggle;end
            if(!fade)fade_ticks<=0;else fade_ticks<=fade_ticks+1'b1;
        end
    end
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*110-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s scene=%d mode=%b busy=%b h=%b",msg,image,emergency,busy,hazards);$fatal(1);end end
    endtask
    task press;input integer key;input integer duration;
        begin case(key)2:k2=0;3:k3=0;4:k4=0;endcase ticks(duration);
            case(key)2:k2=1;3:k3=1;4:k4=1;endcase ticks(12);end
    endtask
    task wait_scene;input [1:0]target;input mode;
        begin wait_count=0;
            while((!valid||busy||image!==target||emergency!==mode)&&wait_count<22000)
                begin ticks(1);wait_count=wait_count+1;end
            check(wait_count<22000,"wait for committed target");ticks(12);end
    endtask
    initial begin
        ticks(5);rst=0;wait_scene(0,0);
        press(2,12);wait_scene(1,0);press(4,12);check(auto_on,"auto enabled before hazard");
        press(3,70);check(menu,"menu open before hazard");
        switches=1;ticks(15);check(!menu&&!auto_on,"policy preempts menu and autoplay");
        wait_scene(3,1);check(route,"A closed chooses B");
        starts_saved=load_starts;press(4,12);press(2,70);press(3,70);
        check(route&&emergency&&!menu,"buttons cannot bypass a blocked exit");
        switches=3;ticks(15);check(both,"both blocked veto");
        switches=2;ticks(15);check(!route,"B closed chooses A");
        switches=14;ticks(15);check(!route,"secondary+medical cannot select blocked B");
        switches=8;ticks(15);press(4,12);check(route,"secondary alone permits safe route toggle");
        check(load_starts==starts_saved,"changing severity/routes never reloads emergency page");
        switches=0;wait_scene(1,0);check(auto_on&&!player.policy_session,"restore original page and auto");
        press(4,12);check(!auto_on,"auto off for remaining tests");
        switches=4;wait_scene(2,0);check(!auto_on,"medical uses third page, not emergency countdown");
        press(2,12);press(2,70);press(3,70);press(4,12);
        check(image==2&&!emergency&&!menu&&!auto_on,"medical policy owns page");
        switches=5;wait_scene(3,1);check(route,"medical cannot mask A blockage");
        switches=4;wait_scene(2,0);switches=0;wait_scene(1,0);
        check(!auto_on,"restore snapshot once, not medical/emergency intermediate pages");
        switches=4;wait_scene(2,0);k2=0;ticks(8);
        switches=0;wait_scene(1,0);k2=1;ticks(12);
        check(image==1&&!busy,"hazard-owned KEY2 release cannot switch normal page");
        switches=4;wait_scene(2,0);k4=0;ticks(8);
        switches=0;wait_scene(1,0);k4=1;ticks(12);
        check(!auto_on,"hazard-owned KEY4 release cannot enable normal auto");
        // Trigger while normal next image is in-flight: keep the old snapshot.
        press(2,12);check(busy,"normal write in flight");switches=1;ticks(15);
        check(busy&&image==1,"do not abort/early-commit active write");
        wait_scene(3,1);switches=0;wait_scene(1,0);
        // Cancel/escalate while policy writes: last desired state wins afterward.
        switches=4;ticks(25);check(busy,"medical write in flight");
        switches=8;ticks(15);wait_scene(3,1);switches=0;wait_scene(1,0);
        // A hazard overlaying an already-manual emergency must restore it.
        press(2,70);wait_scene(3,1);press(4,12);check(route,"manual emergency B");
        switches=2;ticks(20);check(!route,"policy veto in manual emergency");
        switches=0;ticks(30);check(emergency&&route&&!player.policy_session,"restore manual emergency route");
        press(2,70);wait_scene(1,0);
        // Failed load retains the old valid image; retry must eventually recover.
        finish_enable=0;switches=1;ticks(10050);
        check(valid&&image==1,"write failure retains committed frame");
        finish_enable=1;wait_scene(3,1);switches=0;wait_scene(1,0);
        // Missing fourth BMP never reads an invalid sector and never locks exit.
        force player.img_found_count=3'd3;starts_saved=load_starts;
        switches=8;ticks(500);check(image==1&&!busy&&load_starts==starts_saved,"missing emergency BMP safe hold");
        switches=0;ticks(30);check(!player.policy_session,"missing page hazard clears safely");
        release player.img_found_count;
        // All combinations through the real player, with snapshot recovery.
        rst=1;ticks(5);rst=0;wait_scene(0,0);
        for(i=1;i<16;i=i+1)begin
            switches=i;ticks(12);wait_scene(evac?3:2,evac);
            if(locked)check(route==forced_b,"integration availability veto");
            switches=0;wait_scene(0,0);
        end
        switches=8;rst=1;ticks(5);rst=0;wait_scene(3,1);
        switches=0;wait_scene(0,0);check(!auto_on&&!menu,"reset with switch held uses startup snapshot");
        $display("HAZARD_PLAYER_INTEGRATION_TEST_PASSED");$finish;
    end
    initial begin #5000000;$display("FAIL hazard integration watchdog");$fatal(1);end
endmodule
