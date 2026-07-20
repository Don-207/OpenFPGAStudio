# Deprecated compatibility entry point; use build_yifpga_debug_board_demo.tcl.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir build_yifpga_debug_board_demo.tcl]
