`timescale 1ns/1ps
// Control integration test: real UI + real image-controller state machine.
// SD/BMP/scaler dependencies are stubs; this is not a board/bandwidth test.
module tb_ui_player;
    reg clk=0, rst=1, k2=1, k3=1, k4=1, voice_done=1;
    always #5 clk=~clk;
    wire next_cmd, emergency_cmd, auto_cmd, pause_play, menu;
    wire [3:0] item;
    wire [9:0] value;
    wire [2:0] order;
    wire [1:0] image, route_unused;
    wire display_valid, load_busy, fade_req, emergency, route, auto_on;
    wire [1:0] write_buf, display_buf;
    reg finish_toggle=0, finish_enable=1;
    reg [15:0] load_ticks=0, fade_ticks=0;
    wire black_ready=fade_req && fade_ticks>=30;
    integer wait_count;
    ui_controller #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(3), .LONG_PRESS_MS(40),
        .MENU_TIMEOUT_SECONDS(20),.GROUPED_MENU_ENABLE(1)) ui (
        .clk(clk), .reset(rst), .key2_n(k2), .key3_n(k3), .key4_n(k4),
        .emergency_mode(emergency), .player_ready(display_valid && !load_busy && !fade_req),
        .next_image_pulse(next_cmd), .emergency_toggle_pulse(emergency_cmd),
        .auto_or_route_pulse(auto_cmd), .playback_pause(pause_play),
        .menu_active(menu), .menu_item(item), .menu_value(value), .playback_order(order));
    sd_card_bmp #(.EXTERNAL_UI(1), .CLK_FREQ_HZ(1000), .LOAD_TIMEOUT_CYCLES(10000), .PLAYBACK_ORDER_ENABLE(1)) player (
        .clk(clk), .rst(rst), .key_next(1'b1), .key_auto(1'b1),
        .key_auto_allowed(1'b1), .clock_set_active(pause_play),
        .ui_next_pulse(next_cmd), .ui_emergency_pulse(emergency_cmd), .ui_auto_route_pulse(auto_cmd),
        .ui_playback_order(order),
        .voice_done(voice_done), .bmp_width(16'd1280), .bmp_height(16'd960),
        .write_finish_toggle(finish_toggle), .fade_black_ready(black_ready),
        .write_req_ack(1'b1), .SD_MISO(1'b1),
        .write_buf_idx(write_buf), .disp_buf_idx(display_buf), .display_valid(display_valid),
        .current_image_index(image), .load_busy_status(load_busy), .fade_request_status(fade_req),
        .emergency_mode_status(emergency), .accessible_route_status(route), .auto_play_status(auto_on));
    always @(posedge clk or posedge rst) begin
        if(rst) begin load_ticks<=0; finish_toggle<=0; fade_ticks<=0; end
        else begin
            if(!load_busy) load_ticks<=0;
            else begin
                load_ticks<=load_ticks+1'b1;
                if(load_ticks==119 && finish_enable) finish_toggle<=~finish_toggle;
            end
            if(!fade_req) fade_ticks<=0;
            else fade_ticks<=fade_ticks+1'b1;
        end
    end
    task ticks; input integer n; begin repeat(n) @(negedge clk); end endtask
    task check; input good; input [8*100-1:0] message;
        begin if(good!==1'b1) begin $display("FAIL: %0s",message); $fatal(1); end end
    endtask
    task press; input integer key; input integer duration;
        begin
            case(key) 2:k2=0; 3:k3=0; 4:k4=0; endcase
            ticks(duration);
            case(key) 2:k2=1; 3:k3=1; 4:k4=1; endcase
            ticks(12);
        end
    endtask
    task wait_image; input [1:0] target;
        begin
            wait_count=0;
            while((!display_valid || load_busy || image!==target) && wait_count<2000) begin
                ticks(1); wait_count=wait_count+1;
            end
            check(wait_count<2000,"wait for committed image");
        end
    endtask
    initial begin
        ticks(5); rst=0;
        wait_image(0);
        press(2,12); wait_image(1);
        press(2,12); wait_image(2);
        press(2,12); wait_image(0);
        press(4,12); check(auto_on,"normal auto enable");
        press(3,70); check(menu,"menu enters");
        ticks(8000); check(image==0 && !load_busy && auto_on,"menu pauses auto but preserves switch state");
        press(2,12); check(item==1 && image==0 && !load_busy,"menu next item is not next picture");
        press(4,12); check(auto_on && image==0,"menu minus does not toggle autoplay");
        press(3,70); check(!menu,"save menu");
        ticks(2800); check(image==0,"autoplay restarts dwell on menu exit");
        ticks(500); wait_image(1);
        press(4,12); check(!auto_on,"disable auto");
        press(2,12); wait_image(2); press(4,12); check(auto_on,"enable auto before emergency");
        press(3,70); check(menu,"enter menu before emergency");
        press(2,70); check(!menu && !emergency && load_busy,"emergency requests load, not early visible state");
        wait_image(3); check(emergency && !auto_on,"emergency commits only after full load/black handshake");
        check(display_buf!=write_buf || !load_busy,"buffer transaction complete");
        press(4,12); check(route && !auto_on,"emergency KEY4 selects B only");
        press(3,70); check(!menu,"emergency menu denied");
        ticks(7000); check(image==3 && !auto_on,"emergency suspends normal auto");
        press(2,70); check(emergency && load_busy,"exit remains emergency until old image committed");
        wait_image(2); check(!emergency && auto_on,"restore prior image and auto state");
        voice_done=0; ticks(3500); check(image==2 && !load_busy,"autoplay waits for narration");
        ticks(2700); wait_image(0); check(auto_on,"six second voice timeout advances");
        press(4,12); voice_done=1; check(!auto_on,"disable auto for load fault");
        finish_enable=0; press(2,12); ticks(10100);
        check(!load_busy && image==0 && display_valid && !fade_req,"write timeout retains old image");
        finish_enable=1; press(2,12); wait_image(1);
        // Real UI order output drives the real player, not a test-only mux.
        press(3,70);press(4,70);press(4,70);press(4,70);
        check(menu && item==9,"grouped playback settings reached");
        press(2,12);press(2,12);press(3,12);
        check(item==11 && value==132 && order==1,"menu changes actual playback order");
        press(3,70);press(2,12);wait_image(0);
        press(2,12);wait_image(2);press(2,12);wait_image(1);
        check(!auto_on,"132 order uses real manual control without enabling auto");
        rst=1; ticks(5); rst=0; wait_image(0);
        check(!menu && !emergency && !auto_on,"reset restores both UI and player");
        $display("UI_STAGE1_PLAYER_INTEGRATION_TEST_PASSED"); $finish;
    end
    initial begin #1000000; $display("FAIL integration watchdog"); $fatal(1); end
endmodule
