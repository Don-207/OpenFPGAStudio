# Deprecated compatibility entry point; use yifpga_jtag_discover.tcl.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir yifpga_jtag_discover.tcl]
