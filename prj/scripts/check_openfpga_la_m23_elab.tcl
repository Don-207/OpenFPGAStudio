# Lightweight M23 Logic Analyzer RTL elaboration check.
# Usage:
#   vivado -mode batch -source prj/scripts/check_openfpga_la_m23_elab.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir .. ..]]
set rtl_debug_dir [file join $repo_root rtl openfpga_debug]
set part_name xcku5p-ffvb676-2-i

cd $repo_root
read_verilog [list \
    [file join $rtl_debug_dir openfpga_debug_pkg.vh] \
    [file join $rtl_debug_dir openfpga_la_pkg.vh] \
    [file join $rtl_debug_dir openfpga_la_probe_pack.v] \
    [file join $rtl_debug_dir openfpga_la_trigger.v] \
    [file join $rtl_debug_dir openfpga_la_core.v] \
    [file join $rtl_debug_dir openfpga_la_adapter.v] \
]

synth_design -rtl -name openfpga_la_m23_core_rtl -top openfpga_la_core -part $part_name
close_design

synth_design -rtl -name openfpga_la_m23_adapter_rtl -top openfpga_la_adapter -part $part_name
close_design

puts "PASS: OpenFPGA Logic Analyzer M23 core and adapter Vivado RTL elaboration completed"
