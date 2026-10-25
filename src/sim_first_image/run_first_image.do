onerror {quit -code 1}
onfinish stop
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../user_source/hdl_source/SD/sd_card_bmp.v ../user_source/hdl_source/SD/bmp_read.v tb_first_image_fast.v
vsim work.tb_first_image_fast
run -all
