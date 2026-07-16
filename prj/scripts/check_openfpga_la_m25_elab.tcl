# Lightweight M25 Logic Analyzer board demo elaboration check.
# Usage:
#   vivado -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir .. ..]]
set rtl_debug_dir [file join $repo_root rtl openfpga_debug]
set rtl_board_dir [file join $repo_root rtl board]
set constraints_dir [file join $repo_root prj constraints]
set part_name xcku5p-ffvb676-2-i

cd $repo_root
read_verilog [list \
    [file join $rtl_debug_dir openfpga_debug_pkg.vh] \
    [file join $rtl_debug_dir openfpga_trace_pkg.vh] \
    [file join $rtl_debug_dir openfpga_monitor_pkg.vh] \
    [file join $rtl_debug_dir openfpga_profiler_pkg.vh] \
    [file join $rtl_debug_dir openfpga_la_pkg.vh] \
    [file join $rtl_debug_dir openfpga_debug_timestamp.v] \
    [file join $rtl_debug_dir openfpga_debug_ring_buffer.v] \
    [file join $rtl_debug_dir openfpga_debug_packetizer.v] \
    [file join $rtl_debug_dir openfpga_debug_uart_tx.v] \
    [file join $rtl_debug_dir openfpga_debug_uart_rx.v] \
    [file join $rtl_debug_dir openfpga_debug_command_parser.v] \
    [file join $rtl_debug_dir openfpga_trace_adapter.v] \
    [file join $rtl_debug_dir openfpga_trace_dma_probe.v] \
    [file join $rtl_debug_dir openfpga_trace_frame_probe.v] \
    [file join $rtl_debug_dir openfpga_trace_fifo_probe.v] \
    [file join $rtl_debug_dir openfpga_trace_irq_probe.v] \
    [file join $rtl_debug_dir openfpga_monitor_reg_bank.v] \
    [file join $rtl_debug_dir openfpga_monitor_core.v] \
    [file join $rtl_debug_dir openfpga_monitor_adapter.v] \
    [file join $rtl_debug_dir openfpga_profiler_counter.v] \
    [file join $rtl_debug_dir openfpga_profiler_core.v] \
    [file join $rtl_debug_dir openfpga_profiler_adapter.v] \
    [file join $rtl_debug_dir openfpga_profiler_axis_probe.v] \
    [file join $rtl_debug_dir openfpga_profiler_fifo_probe.v] \
    [file join $rtl_debug_dir openfpga_profiler_frame_probe.v] \
    [file join $rtl_debug_dir openfpga_profiler_latency.v] \
    [file join $rtl_debug_dir openfpga_la_probe_pack.v] \
    [file join $rtl_debug_dir openfpga_la_trigger.v] \
    [file join $rtl_debug_dir openfpga_la_core.v] \
    [file join $rtl_debug_dir openfpga_la_adapter.v] \
    [file join $rtl_debug_dir openfpga_debug_core.v] \
    [file join $rtl_debug_dir openfpga_debug_top.v] \
    [file join $rtl_board_dir openfpga_debug_board_demo.v] \
]
read_xdc [file join $constraints_dir openfpga_debug_board_demo.xdc]

synth_design -rtl -name openfpga_la_m25_board_rtl -top openfpga_debug_board_demo -part $part_name

puts "PASS: OpenFPGA Logic Analyzer M25 board demo Vivado RTL elaboration completed"
