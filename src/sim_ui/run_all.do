onerror {abort}
onbreak {resume}
onfinish stop
set sim_root [file dirname [file normalize [info script]]]
cd $sim_root
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../user_source/hdl_source/ui_controller.v ../user_source/hdl_source/SD/sd_card_bmp.v player_stubs.v tb_ui_controller.v tb_ui_player.v
vlog ../user_source/hdl_source/font_rom.v ../user_source/hdl_source/font_rom_ascii.v ../user_source/hdl_source/video_osd.v video_osd_baseline.v tb_ui_osd.v
vsim work.tb_ui_controller
run -all
quit -sim
vsim work.tb_ui_player
run -all
quit -sim
vsim work.tb_ui_osd
run -all
puts "Look for all three UI_STAGE1_*_TEST_PASSED lines."
