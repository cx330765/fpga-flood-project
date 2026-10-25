onerror {abort}
onbreak {resume}
onfinish stop
set sim_root [file dirname [file normalize [info script]]]
cd $sim_root
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../user_source/hdl_source/hazard_policy.v ../user_source/hdl_source/hazard_overlay.v ../user_source/hdl_source/ui_controller.v ../user_source/hdl_source/SD/sd_card_bmp.v player_stubs.v tb_hazard_policy.v tb_hazard_player.v tb_hazard_overlay.v
vlog -sv ../user_source/hdl_source/hdmi_audio_tone_i2s_64fs.v ../sim_img4_alarm/tb_img4_long_alarm.v tb_hazard_audio.v
vlog -sv tb_hazard_large_text.v
foreach bench {tb_hazard_policy tb_hazard_player tb_hazard_overlay tb_hazard_large_text tb_hazard_audio tb_img4_long_alarm} {
    vsim work.$bench
    run -all
    quit -sim
}
puts "Look for six HAZARD/IMG4 *_TEST_PASSED lines; pauses at finish are normal."
