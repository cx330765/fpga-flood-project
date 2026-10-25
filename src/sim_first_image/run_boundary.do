onerror {quit -code 1}
onfinish stop
if {![file exists work]} {vlib work}
vmap work work
vlog -sv +incdir+../user_source/hdl_source/SD ../user_source/hdl_source/SD/video_timing_data.v ../user_source/hdl_source/SD/color_bar.v ../user_source/hdl_source/video_fade_smooth.v tb_first_frame_boundary.v
vsim work.tb_first_frame_boundary
run -all
