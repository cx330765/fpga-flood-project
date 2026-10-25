`timescale 1ns/1ps
// Unit test: accelerated sample ticks and mock voice ROM data. It checks
// control/gating only, not the real voice waveform or HDMI/I2S link quality.
module tb_img4_long_alarm;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1, valid = 1, emergency = 1, expired = 0;
    reg [1:0] image = 3;
    wire done;
    reg [31:0] saved_phase;
    reg [31:0] saved_inc;
    hdmi_audio_tone_i2s_64fs #(.ALARM_SAMPLES(4), .BEEP_HALF(2),
        .HALF_ALERT(4)) dut (
        .I_mclk(clk), .I_rst(reset), .I_image_idx(image),
        .I_display_valid(valid), .I_emergency_mode(emergency),
        .I_countdown_expired(expired), .O_voice_done(done),
        .O_i2s_BCLK(), .O_i2s_LRCK(), .O_i2s_DOUT());
    task cycles;
        input integer count;
        begin repeat(count) @(negedge clk); end
    endtask
    task samples;
        input integer count;
        begin
            force dut.sample_tick = 1'b1;
            cycles(count);
            force dut.sample_tick = 1'b0;
            cycles(2);
        end
    endtask
    task check;
        input condition;
        input [511:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("IMG4_LONG_ALARM_TEST_FAILED: %0s",message);
                $stop; $finish;
            end
        end
    endtask
    initial begin
        force dut.sample_tick = 1'b0;
        cycles(5); reset = 0; cycles(8);
        check(dut.V_state == 1 && !dut.V_long_alarm && !done,
              "image 4 starts with original prealarm");
        samples(4);
        check(dut.V_state == 2 && !done, "prealarm precedes narration");
        // Skip to the final PCM sample; the ordinary production ROM length
        // and hold interval are not changed by this accelerated unit test.
        force dut.V_rom_addr = 15'd25047;
        force dut.V_rep_cnt = 4'd5;
        samples(1);
        release dut.V_rom_addr; release dut.V_rep_cnt;
        check(dut.V_state == 3 && done && !dut.V_long_alarm && dut.V_beep_on,
              "voice completes before post-voice short beeps");
        samples(2);
        check(!dut.V_beep_on && dut.V_audio_out == 0,
              "original short beep silent gap before countdown zero");
        expired = 1; cycles(6);
        check(dut.V_long_alarm &&
              dut.V_audio_out === dut.S_alarm_out,
              "actual countdown expiry removes the silent gap");
        samples(2);
        check(!dut.S_tone_sel && !dut.S_sw_pend,
              "siren bypasses the original two-tone beep switch");
        saved_phase = dut.S_phase_acc; saved_inc = dut.S_siren_inc; samples(1);
        check(dut.S_phase_acc == saved_phase + saved_inc,
              "siren keeps phase continuous");
        samples(24);
        check(dut.S_siren_inc > dut.FIRE_INC_MIN &&
              dut.S_siren_inc < dut.FIRE_INC_MAX && !dut.S_siren_descending,
              "siren initially sweeps upward");
        samples(10000);
        check(dut.S_siren_descending && dut.S_siren_inc <= dut.FIRE_INC_MAX &&
              dut.S_siren_inc >= dut.FIRE_INC_MIN,
              "siren reaches upper bound and sweeps downward");
        samples(10000);
        check(!dut.S_siren_descending && dut.S_siren_inc <= dut.FIRE_INC_MAX &&
              dut.S_siren_inc >= dut.FIRE_INC_MIN,
              "siren reaches lower bound and repeats upward sweep");
        emergency = 0; image = 0; expired = 0; cycles(8);
        check(!dut.V_long_alarm && dut.V_state == 2 && !done,
              "exit stops long alarm and starts normal-image voice");
        force dut.V_finish_pending = 1'b1;
        force dut.V_rep_cnt = 4'd5;
        samples(1);
        release dut.V_finish_pending; release dut.V_rep_cnt;
        check(dut.V_state == 4 && done && dut.V_audio_out == 0,
              "normal-image voice still ends in silence");
        emergency = 1; image = 3; cycles(8);
        check(dut.V_state == 1 && !dut.V_long_alarm && !done,
              "reentry starts fresh prealarm, not stale long alarm");
        samples(4); expired = 1; cycles(6);
        check(dut.V_state == 2 && !dut.V_long_alarm,
              "expiry cannot interrupt narration");
        reset = 1; cycles(3);
        check(!dut.V_long_alarm && !done && dut.V_state == 0,
              "reset clears long alarm");
        $display("IMG4_FIRE_SIREN_CONTROL_TEST_PASSED");
        $finish;
    end
    initial begin
        #1000000;
        $display("IMG4_LONG_ALARM_TEST_FAILED: timeout");
        $stop; $finish;
    end
endmodule

// Test-only mock ROMs. The TD project still uses the original real ROMs.
module voice_adpcm_rom(input wire clk, input wire [1:0] voice_sel,
    input wire [14:0] addr, output reg [3:0] dout);
    always @(posedge clk) dout <= 4'd0;
endmodule
module voice4_pcm_rom(input wire clk, input wire [14:0] addr,
    output reg [7:0] dout);
    always @(posedge clk) dout <= 8'h90;
endmodule
