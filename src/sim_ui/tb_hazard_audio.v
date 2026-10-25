`timescale 1ns/1ps
// Mock ROM definitions are shared with sim_img4_alarm/tb_img4_long_alarm.v.
module tb_hazard_audio;
    reg clk=0,reset=1,waiting=0;
    always #5 clk=~clk;
    hdmi_audio_tone_i2s_64fs #(.HAZARD_POLICY_ENABLE(1),.ALARM_SAMPLES(4),.BEEP_HALF(2)) dut (
        .I_mclk(clk),.I_rst(reset),.I_image_idx(2'd3),.I_display_valid(1'b1),
        .I_emergency_mode(1'b1),.I_countdown_expired(1'b0),.I_wait_for_staff(waiting));
    task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
    task check;input good;input [8*100-1:0]msg;
        begin if(good!==1'b1)begin $display("FAIL %0s",msg);$fatal(1);end end
    endtask
    initial begin
        force dut.sample_tick=0;ticks(5);reset=0;ticks(8);
        force dut.sample_tick=1;ticks(4);force dut.sample_tick=0;ticks(2);
        check(dut.V_state==2,"original narration begins");
        waiting=1;ticks(6);
        check(dut.wait_only&&dut.V_audio_out===dut.S_alarm_out,"closed exits emit warning, never narration");
        waiting=0;ticks(6);
        check(!dut.wait_only&&dut.V_state==1,"clear waiting restarts complete opening sequence");
        force dut.sample_tick=1;ticks(4);force dut.sample_tick=0;ticks(2);
        check(dut.V_state==2,"original narration resumes from start");
        $display("HAZARD_AUDIO_SAFETY_GATE_TEST_PASSED");$finish;
    end
endmodule
