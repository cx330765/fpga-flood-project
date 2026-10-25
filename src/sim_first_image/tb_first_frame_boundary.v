`timescale 1ns/1ps
module tb_first_frame_boundary;
reg clk=0,pixel_clk=0,rst=1,fade_request=0;
always #5 clk=~clk;
always #7 pixel_clk=~pixel_clk;
wire hs,vs,de,read_req;
reg ack_d0=0,ack_d1=0;
always @(posedge pixel_clk)begin ack_d0<=read_req;ack_d1<=ack_d0;end
video_timing_data timing(.video_clk(pixel_clk),.rst(rst),.read_req(read_req),
    .read_req_ack(ack_d1),.hs(hs),.vs(vs),.de(de));
defparam timing.color_bar_m0.H_ACTIVE=8,timing.color_bar_m0.H_FP=2,
    timing.color_bar_m0.H_SYNC=2,timing.color_bar_m0.H_BP=2,
    timing.color_bar_m0.V_ACTIVE=6,timing.color_bar_m0.V_FP=1,
    timing.color_bar_m0.V_SYNC=1,timing.color_bar_m0.V_BP=1;
wire[4:0]level;
video_fade_smooth #(.STEP_FRAMES(2)) fade(.pixel_clk(pixel_clk),.reset(rst),
    .enable(1'b1),.load_busy(fade_request),.rgb_in(24'hffffff),.hs_in(hs),.vs_in(vs),.de_in(de),
    .fade_level(level));
reg display_valid=0,source_done=0,writer_done=0;
wire black_ready_video=(level==0)&&(display_valid||read_req);
reg[1:0]black_sync=0;
always @(posedge clk or posedge rst)begin
    if(rst)begin black_sync<=0;display_valid<=0;end
    else begin
        black_sync<={black_sync[0],black_ready_video};
        if(fade_request && black_sync[1] && source_done && writer_done)display_valid<=1;
    end
end
time last_read;
always @(posedge read_req)last_read=$time;
always @(posedge display_valid)begin
    if(de!==0 || $time-last_read>112)begin
        $display("FAIL: initial display did not commit at a fresh frame restart");$fatal(1);
    end
end
initial begin
    repeat(10)@(negedge clk);rst=0;
    wait(level==16);@(negedge clk);fade_request=1;
    wait(level==0);repeat(100)@(negedge clk);
    if(display_valid)$fatal(1,"commit before source/frame complete");
    source_done=1;repeat(100)@(negedge clk);
    if(display_valid)$fatal(1,"commit before SDRAM write finished");
    wait(de);@(negedge clk);writer_done=1;
    wait(display_valid);@(negedge clk);fade_request=0;
    wait(level==16);@(negedge clk);fade_request=1;
    wait(level==0);wait(!read_req);#1;
    if(!black_ready_video)$fatal(1,"ordinary transition acquired an unwanted frame-request gate");
    $display("FIRST_FRAME_BLANKING_HANDSHAKE_TEST_PASSED");$finish;
end
initial begin #1000000;$fatal(1,"frame-boundary timeout");end
endmodule
