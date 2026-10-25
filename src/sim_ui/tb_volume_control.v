`timescale 1ns/1ps
module tb_volume_control;
    reg clk=0,rst=1,emergency=0;
    reg [1:0] volume=3;
    reg signed [23:0] sample=0;
    always #5 clk=~clk;
    hdmi_audio_tone_i2s_64fs #(.VOLUME_CONTROL_ENABLE(1)) dut (
        .I_mclk(clk),.I_rst(rst),.I_image_idx(2'd0),.I_display_valid(1'b1),
        .I_emergency_mode(emergency),.I_countdown_expired(1'b0),.I_wait_for_staff(1'b0),
        .I_volume_level(volume));
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s",msg);$fatal(1);end end
    endtask
    initial begin
        ticks(5);rst=0;force dut.V_audio_out=sample;
        sample=24'sd4000;volume=0;ticks(8);check(dut.scaled_audio==1000,"25 percent positive");
        volume=1;ticks(8);check(dut.scaled_audio==2000,"50 percent");
        volume=2;ticks(8);check(dut.scaled_audio==3000,"75 percent");
        volume=3;ticks(8);check(dut.scaled_audio==4000,"100 percent original");
        sample=-24'sd4000;volume=0;ticks(8);check(dut.scaled_audio==-1000,"negative arithmetic shift");
        volume=2;ticks(8);check(dut.scaled_audio==-3000,"negative 75 percent");
        volume=0;emergency=1;ticks(8);check(dut.scaled_audio==-2000,"emergency minimum 50 percent");
        emergency=0;ticks(8);check(dut.scaled_audio==-1000,"normal volume restored");
        // Confirm the scaler feeds the actual I2S sample latch.
        force dut.S_bit_cnt=63;force dut.O_i2s_BCLK=1;force dut.O_i2s_LRCK=1;
        ticks(1);check(dut.S_sample_next==-1000,"I2S receives scaled sample");
        $display("VOLUME_SIGNED_PCM_TEST_PASSED");$finish;
    end
endmodule
