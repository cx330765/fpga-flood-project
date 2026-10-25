set script_dir [file dirname [file normalize [info script]]]
cd $script_dir
onerror {abort}
onfinish stop
if {![file exists work]} {vlib work}
vmap work work
vlog ../user_source/hdl_source/hdmi_audio_tone_i2s_64fs.v tb_img4_long_alarm.v
vsim work.tb_img4_long_alarm
run -all
