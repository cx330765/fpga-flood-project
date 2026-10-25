# In the TD Tcl Console: source {absolute/path/to/open_packaged_project.tcl}
# Establish the extracted project directory before resolving relative paths.
set packaged_project_root [file dirname [file normalize [info script]]]
cd $packaged_project_root
import_device eagle_s20.db -package EG4S20BG256
open_project HDMI1.4b_Transmitter_v1.0.al
