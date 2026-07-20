# Deprecated compatibility entry point; use build_yifpga_jtag_m36_ila_bitstream.tcl.
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir build_yifpga_jtag_m36_ila_bitstream.tcl]
