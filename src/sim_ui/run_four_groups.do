onerror {abort}
onbreak {resume}
onfinish stop
set sim_root [file dirname [file normalize [info script]]]
cd $sim_root
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../user_source/hdl_source/ui_controller.v ../user_source/hdl_source/SD/sd_card_bmp.v player_stubs.v tb_four_group_menu.v tb_playback_order.v tb_ui_player.v
vlog -sv ../user_source/hdl_source/hdmi_audio_tone_i2s_64fs.v ../sim_img4_alarm/tb_img4_long_alarm.v tb_volume_control.v
vlog -sv ../user_source/hdl_source/scroll_text.v tb_subtitle_speed.v
vlog -sv ../user_source/hdl_source/font_rom.v ../user_source/hdl_source/font_rom_ascii.v ../user_source/hdl_source/video_osd.v video_osd_baseline.v tb_ui_osd.v
foreach bench {tb_four_group_menu tb_playback_order tb_volume_control tb_subtitle_speed tb_ui_player tb_ui_osd tb_img4_long_alarm} {
    vsim work.$bench
    run -all
    quit -sim
}
puts "Check all seven TEST_PASSED lines. Hazard regressions: do run_hazard.do"
