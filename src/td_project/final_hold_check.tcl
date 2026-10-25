# Run from this project directory after completing route in TD.
# Reload the GUI-generated routed database, apply the same hold repair used
# during verification, and save reports/database without overwriting old BIT.
set finish_root [file dirname [file normalize [info script]]]
cd $finish_root
set routed_db [file join $finish_root HDMI1.4b_Transmitter_v1.0_Runs phy_1 HDMI1.4b_Transmitter_v1.0_pr.db]
if {![file exists $routed_db]} {
    error "Complete synthesis, placement and routing before this step."
}
import_device eagle_s20.db -package EG4S20BG256
open_project HDMI1.4b_Transmitter_v1.0.al -noanalyze
import_db $routed_db
fix_hold
update_timing -mode final
report_timing_status -file final_hold_checked.ts
report_timing_summary -file final_hold_checked.timing
export_db final_hold_checked.db
puts "Hold check completed. Inspect final_hold_checked.ts before bitgen."
