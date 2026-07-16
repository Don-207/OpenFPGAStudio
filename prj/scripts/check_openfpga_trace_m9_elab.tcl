# Lightweight M9 Trace Adapter elaboration check.
# Usage:
#   vivado -mode batch -source prj/scripts/check_openfpga_trace_m9_elab.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir .. ..]]
set trace_rtl_dir [file join $repo_root rtl openfpga_debug]

cd $trace_rtl_dir
read_verilog [list \
    openfpga_trace_pkg.vh \
    openfpga_trace_adapter.v \
]

synth_design -rtl -name openfpga_trace_m9_rtl -top openfpga_trace_adapter -part xcku5p-ffvb676-2-i

puts "PASS: OpenFPGA Trace M9 Vivado RTL elaboration completed"
