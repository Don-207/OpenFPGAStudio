# Deprecated compatibility entry point; use yifpga_jtag_read.tcl.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir yifpga_jtag_read.tcl]
