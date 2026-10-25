`timescale 1ns/1ps
module tb_first_image_fast;
reg clk=0,rst=1,next_cmd=0,auto_cmd=0,emergency_cmd=0;
reg hazard_active=0,hazard_evacuation=0;
always #5 clk=~clk;
wire fast_valid,slow_valid,fast_busy,fast_fade,fast_emergency,fast_auto;
wire [1:0] fast_image;
reg fast_finish=0,slow_finish=0,writer_enable=0;
integer cycles=0,n,first_cycle,scan_cycle,fast_wait=0,slow_wait=0,fade_ticks=0;
integer first_loads=0;
always @(posedge clk) begin
    cycles<=cycles+1;
    if(rst)begin fast_finish<=0;slow_finish<=0;fast_wait<=0;slow_wait<=0;fade_ticks<=0;end
    else begin
        if(fast_busy && fast.bmp_ready)begin
            if(fast_wait==30 && writer_enable)begin fast_finish<=~fast_finish;fast_wait<=31;end
            else if(fast_wait!=31)fast_wait<=fast_wait+1;
        end else fast_wait<=0;
        if(slow.load_busy && slow.bmp_ready)begin
            if(slow_wait==30)begin slow_finish<=~slow_finish;slow_wait<=31;end
            else if(slow_wait!=31)slow_wait<=slow_wait+1;
        end else slow_wait<=0;
        if(fast_fade)fade_ticks<=fade_ticks+1;else fade_ticks<=0;
    end
end
wire fast_black=fast_fade && (fast_valid ? fade_ticks>=12 : cycles[5:0]==0);
sd_card_bmp #(.FAST_FIRST_IMAGE_ENABLE(1),.EXTERNAL_UI(1),.HAZARD_POLICY_ENABLE(1),.CLK_FREQ_HZ(1000),
    .LOAD_TIMEOUT_CYCLES(20000),.SCAN_MAX_SECTOR(650)) fast (
    .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_auto_allowed(1'b1),
    .clock_set_active(1'b0),.ui_next_pulse(next_cmd),.ui_emergency_pulse(emergency_cmd),
    .ui_auto_route_pulse(auto_cmd),.voice_done(1'b1),.ui_playback_order(3'd0),
    .hazard_active(hazard_active),.hazard_evacuation(hazard_evacuation),
    .hazard_route_locked(1'b0),.hazard_route_b(1'b0),
    .bmp_width(16'd1280),.bmp_height(16'd960),.SD_MISO(1'b1),.write_req_ack(1'b1),
    .write_finish_toggle(fast_finish),.fade_black_ready(fast_black),
    .display_valid(fast_valid),.load_busy_status(fast_busy),.fade_request_status(fast_fade),
    .current_image_index(fast_image),.emergency_mode_status(fast_emergency),.auto_play_status(fast_auto));
sd_card_bmp #(.FAST_FIRST_IMAGE_ENABLE(0),.EXTERNAL_UI(1),.CLK_FREQ_HZ(1000),
    .LOAD_TIMEOUT_CYCLES(20000),.SCAN_MAX_SECTOR(650)) slow (
    .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_auto_allowed(1'b1),
    .clock_set_active(1'b0),.ui_next_pulse(1'b0),.ui_emergency_pulse(1'b0),
    .ui_auto_route_pulse(1'b0),.voice_done(1'b1),.ui_playback_order(3'd0),
    .bmp_width(16'd1280),.bmp_height(16'd960),.SD_MISO(1'b1),.write_req_ack(1'b1),
    .write_finish_toggle(slow_finish),.fade_black_ready(1'b1),.display_valid(slow_valid));
task ticks;input integer count;begin repeat(count)@(negedge clk);end endtask
task check;input good;input[8*110-1:0]msg;begin
    if(good!==1'b1)begin $display("FAIL: %0s cycles=%0d count=%0d busy=%b",msg,cycles,fast.img_found_count,fast_busy);$fatal(1);end
end endtask
task reset_case;begin rst=1;ticks(5);rst=0;ticks(5);end endtask
task await_first;begin
    n=0;while(!fast_valid && n<15000)begin ticks(1);n=n+1;end
    check(fast_valid && fast_image==0,"first full image must display without all four headers");
end endtask
task await_scan;begin
    n=0;while(!fast.scan_done && n<400000)begin ticks(1);n=n+1;end
    check(fast.scan_done,"remaining scan must complete");ticks(2);
end endtask
initial begin
    reset_case;
    n=0;while(!(fast_busy && fast.bmp_ready && fast.source_done_seen) && n<15000)begin ticks(1);n=n+1;end
    check(fast_busy && fast.bmp_ready,"first BMP load must finish while scan is paused");
    ticks(150);check(!fast_valid,"black readiness cannot bypass SDRAM-write completion");
    writer_enable=1;fast_wait=0;await_first;
    first_cycle=cycles;
    check(!slow_valid && !fast.scan_done,"early display must precede legacy full scan");
    check(fast.img_found_count==1,"first image must not be discovered twice");
    ticks(20);check(!fast.bmp_ready,"scanner must resume after the first commit");
    next_cmd=1;ticks(1);next_cmd=0;ticks(2);
    check(fast.next_req_pending,"manual request during discovery is remembered");
    await_scan;scan_cycle=cycles;
    check(fast.img_found_count==4,"all four image indices must survive pause/load/resume");
    check(fast.img_sector0==2 && fast.img_sector1==200 && fast.img_sector2==400 && fast.img_sector3==600,
        "resumed cursor must locate exact subsequent BMP sectors");
    n=0;while(fast_image!=1 && n<15000)begin ticks(1);n=n+1;end
    check(fast_image==1,"queued manual switch runs after discovery");
    $display("SIMULATED_FIRST_DISPLAY_CYCLE=%0d REMAINING_SCAN_DONE_CYCLE=%0d",first_cycle,scan_cycle);

    reset_case;await_first;ticks(20);auto_cmd=1;ticks(1);auto_cmd=0;ticks(2);
    check(fast_auto,"automatic-play selection during discovery is remembered");
    await_scan;n=0;while(fast_image!=1 && n<25000)begin ticks(1);n=n+1;end
    check(fast_image==1,"automatic playback starts after discovery");

    reset_case;await_first;ticks(20);emergency_cmd=1;ticks(1);emergency_cmd=0;ticks(2);
    check(fast.force_req_pending && !fast_emergency,"emergency queues without showing an unready fourth page");
    await_scan;n=0;while(!fast_emergency && n<15000)begin ticks(1);n=n+1;end
    check(fast_emergency && fast_image==3,"queued emergency loads the actual fourth image");

    fast.sd_card_top_m0.fourth_valid=0;
    reset_case;await_first;ticks(20);emergency_cmd=1;ticks(1);emergency_cmd=0;
    await_scan;ticks(10);
    check(fast.img_found_count==3 && !fast.force_req_pending && !fast_emergency,
        "missing fourth BMP must release queued emergency without loading a bogus address");
    check(fast_valid && fast_image==0,"missing files must not blank the valid first image");

    fast.sd_card_top_m0.fourth_valid=1;
    reset_case;await_first;ticks(20);hazard_active=1;hazard_evacuation=1;
    await_scan;n=0;while(!fast_emergency && n<15000)begin ticks(1);n=n+1;end
    check(fast_emergency && fast_image==3,"hazard during discovery must select the actual emergency BMP");
    hazard_active=0;hazard_evacuation=0;
    n=0;while(fast_emergency && n<15000)begin ticks(1);n=n+1;end
    check(!fast_emergency && fast_image==0,"hazard release must restore the first scene");

    reset_case;await_first;ticks(200);
    fast.sd_card_top_m0.present=0;ticks(5);
    check(!fast_valid && !fast.scan_paused && fast.img_found_count==0,"unplug must discard scan cursor/session");
    fast.sd_card_top_m0.present=1;await_first;
    check(!fast.scan_done && fast.img_found_count==1,"reinsertion must take early-first path again");
    $display("FIRST_IMAGE_EARLY_SCAN_AND_COMMIT_TEST_PASSED");$finish;
end
initial begin #30000000;$fatal(1,"overall timeout");end
endmodule

// Byte-accurate sector model, real BMP parser above. Long gaps between valid
// headers expose discovery latency without assuming the real card's layout.
module sd_card_top #(parameter integer CLK_FREQ_HZ=50_000_000)(
    input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output sd_init_done,
    input sd_sec_read,input[31:0]sd_sec_read_addr,output reg[7:0]sd_sec_read_data,
    output reg sd_sec_read_data_valid,sd_sec_read_end,input sd_sec_write,
    input[31:0]sd_sec_write_addr,input[7:0]sd_sec_write_data,
    output sd_sec_write_data_req,sd_sec_write_end);
reg present=1,fourth_valid=1,active=0;
integer index=0,cooldown=0;
reg[31:0]sector=0;
assign sd_init_done=present && !rst;
assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;
assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
function[7:0] sector_byte;input[31:0]sec;input integer off;begin
    sector_byte=0;
    if(sec==2||sec==200||sec==400||(sec==600&&fourth_valid))begin
        case(off)
        0:sector_byte="B";1:sector_byte="M";2:sector_byte=70;10:sector_byte=54;
        14:sector_byte=40;18:sector_byte=2;22:sector_byte=2;26:sector_byte=1;
        28:sector_byte=24;
        default:sector_byte=0;
        endcase
    end
end endfunction
always @(posedge clk or posedge rst)begin
    if(rst)begin active<=0;index<=0;cooldown<=0;sd_sec_read_data_valid<=0;sd_sec_read_end<=0;sd_sec_read_data<=0;end
    else if(!present)begin active<=0;index<=0;cooldown<=0;sd_sec_read_data_valid<=0;sd_sec_read_end<=0;end
    else begin
        sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
        if(active)begin
            if(index<512)begin sd_sec_read_data<=sector_byte(sector,index);sd_sec_read_data_valid<=1;index<=index+1;end
            else begin sd_sec_read_end<=1;active<=0;cooldown<=2;end
        end else if(cooldown!=0)cooldown<=cooldown-1;
        else if(sd_sec_read)begin active<=1;index<=0;sector<=sd_sec_read_addr;end
    end
end
endmodule
module bilinear_scaler_stream #(parameter OUT_WIDTH=640,OUT_HEIGHT=480,MAX_INPUT_WIDTH=1280)(
    input clk,rst,frame_start,input[15:0]source_width,source_height,
    input in_valid,input[23:0]in_pixel,output reg out_valid,output reg[23:0]out_pixel,
    output reg frame_done,busy,overrun_error);
integer pixels=0;
always @(posedge clk or posedge rst)begin
    if(rst)begin pixels<=0;out_valid<=0;out_pixel<=0;frame_done<=0;busy<=0;overrun_error<=0;end
    else begin
        out_valid<=0;frame_done<=0;
        if(frame_start)begin pixels<=0;busy<=1;end
        else if(busy&&in_valid)begin
            out_valid<=1;out_pixel<=in_pixel;pixels<=pixels+1;
            if(pixels==3)begin busy<=0;frame_done<=1;end
        end
    end
end
endmodule
