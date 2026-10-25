onerror {quit -code 1}
onbreak {resume}
set sim_root [file dirname [file normalize [info script]]]
cd $sim_root
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../user_source/hdl_source/ui_controller.v tb_ui_controller.v
vsim -onfinish stop work.tb_ui_controller
run -all
