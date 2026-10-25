`timescale 1ns/1ps
module tb_playback_order;
    reg clk=0,rst=1,next_cmd=0,auto_cmd=0,pause_play=0;
    reg [2:0] order=0;
    always #5 clk=~clk;
    wire [1:0] image;
    wire valid,busy,fade,auto_on;
    reg finish_toggle=0;
    reg [15:0] ticks_load=0,ticks_fade=0;
    integer i,j,n;
    reg [1:0] first,second,third;
    sd_card_bmp #(.EXTERNAL_UI(1),.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_CYCLES(10000),
        .PLAYBACK_ORDER_ENABLE(1)) dut (
        .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.key_auto_allowed(1'b1),
        .clock_set_active(pause_play),.ui_next_pulse(next_cmd),.ui_emergency_pulse(1'b0),
        .ui_auto_route_pulse(auto_cmd),.ui_playback_order(order),.voice_done(1'b1),
        .bmp_width(16'd1280),.bmp_height(16'd960),.write_finish_toggle(finish_toggle),
        .fade_black_ready(fade&&ticks_fade>=30),.write_req_ack(1'b1),.SD_MISO(1'b1),
        .current_image_index(image),.display_valid(valid),.load_busy_status(busy),
        .fade_request_status(fade),.auto_play_status(auto_on));
    always @(posedge clk or posedge rst)begin
        if(rst)begin ticks_load<=0;ticks_fade<=0;finish_toggle<=0;end
        else begin
            if(!busy)ticks_load<=0;else begin ticks_load<=ticks_load+1;
                if(ticks_load==119)finish_toggle<=~finish_toggle;end
            if(!fade)ticks_fade<=0;else ticks_fade<=ticks_fade+1;
        end
    end
    task ticks;input integer count;begin repeat(count)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s order=%d image=%d",msg,order,image);$fatal(1);end end
    endtask
    task wait_image;input [1:0] target;
        begin n=0;while((!valid||busy||image!==target)&&n<2000)begin ticks(1);n=n+1;end
            check(n<2000,"expected committed image");ticks(5);end
    endtask
    task step;input [1:0]target;
        begin next_cmd=1;ticks(1);next_cmd=0;wait_image(target);end
    endtask
    initial begin
        ticks(5);rst=0;wait_image(0);
        for(i=0;i<6;i=i+1)begin
            case(i)
                0:begin first=0;second=1;third=2;end
                1:begin first=0;second=2;third=1;end
                2:begin first=1;second=0;third=2;end
                3:begin first=1;second=2;third=0;end
                4:begin first=2;second=0;third=1;end
                5:begin first=2;second=1;third=0;end
            endcase
            pause_play=1;order=i;ticks(20);check(!busy,"menu order change does not load");
            pause_play=0;ticks(4);
            if(image!=first)step(first);
            step(second);step(third);step(first);
            check(image<3,"normal order never includes emergency page");
            auto_cmd=1;ticks(1);auto_cmd=0;ticks(3100);wait_image(second);
            check(auto_on,"autoplay uses same configured next image");
            auto_cmd=1;ticks(1);auto_cmd=0;
        end
        $display("ALL_SIX_PLAYBACK_ORDERS_TEST_PASSED");$finish;
    end
    initial begin #2000000;$display("FAIL order watchdog");$fatal(1);end
endmodule
