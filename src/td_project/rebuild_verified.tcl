set fast_project_dir [file dirname [file normalize [info script]]]
cd $fast_project_dir
if {[catch {
import_device eagle_s20.db -package EG4S20BG256
open_project HDMI1.4b_Transmitter_v1.0.al
elaborate -top top
read_adc ../user_source/constraints_source/pin.adc
read_sdc ../user_source/constraints_source/timing.sdc
read_sdc -ip rfifo_32_32_512 ../user_source/hdl_source/ip/afifo_32_16_256.tcl
read_sdc -ip wfifo_32_32_512 ../user_source/hdl_source/ip/afifo_16_32_256.tcl
optimize_rtl
optimize_gate -packarea first_fast_gate.area
legalize_phy_inst
update_timing
export_db first_fast_gate.db
puts "FIRST_IMAGE_FAST_SYNTHESIS_PASSED"
commit_param -step place
set_param place seed 2
place
report_area -io_info -file first_fast_place.area
export_db first_fast_place.db
puts "FIRST_IMAGE_FAST_PLACEMENT_PASSED"
commit_param -step route
route
export_db first_fast_route.db
fix_hold
report_area -io_info -file first_fast_physical.area
update_timing -mode final
report_timing_status -file first_fast_final.ts
report_timing_summary -file first_fast_final.timing
check_timing -verbose -file first_fast_check.timing
export_db first_fast_final.db
set status_file [open first_fast_final.ts r]
set status_text [read $status_file]
close $status_file
if {![regexp {SWNS:\s+(-?[0-9.]+)ns} $status_text unused setup_wns] ||
    ![regexp {HWNS:\s+(-?[0-9.]+)ns} $status_text unused hold_wns]} {
    error "Could not parse final timing status"
}
if {$setup_wns < 0 || $hold_wns < 0} {
    error "Final timing not met: setup=$setup_wns ns, hold=$hold_wns ns"
}
puts "FIRST_IMAGE_FAST_ROUTING_AND_TIMING_PASSED"
bitgen -bit HDMI1.4b_Transmitter_v1.0_final.bit
puts "FIRST_IMAGE_FAST_VERIFIED_BIT_GENERATED"
} build_error]} {
    puts "FIRST_IMAGE_FAST_BUILD_FAILED: $build_error"
    error $build_error
}
puts "Rebuild script finished; TD remains open."
