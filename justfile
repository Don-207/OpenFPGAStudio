set windows-shell := ["C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe", "-NoProfile", "-Command"]

python := if os_family() == "windows" { "python" } else { "python3" }
vivado := env_var_or_default("VIVADO", if os_family() == "windows" { "vivado" } else { "/tools/Xilinx/Vivado/2024.2/bin/vivado" })

default:
    @just --list

# v1.0 hardware-free/no-network release-candidate gate. Vivado and board sign-off remain separate.
release-check: m27-check m28-check m29-check m30-check m32-check m36-check
    {{python}} tools/viewer/ai_debug_validate.py release
    node --check tools/viewer/web/diagnostic_snapshot.js
    node --check tools/viewer/web/diagnostic_rules.js
    node --check tools/viewer/web/ai_provider.js
    node --check tools/viewer/web/diagnosis_validator.js
    node --check tools/viewer/web/ai_debug_model.js
    node --check tools/viewer/web/app.js

# M32 hardware-free JTAG mailbox protocol/model regression.
m32-check:
    {{python}} tools/jtag/test_mailbox_model.py

# M33 hardware-free SystemVerilog transport regression.
m33-sim:
    xvlog -sv rtl/openfpga_debug/openfpga_transport_router.sv rtl/openfpga_debug/openfpga_jtag_ring_buffer.sv rtl/openfpga_debug/openfpga_jtag_mailbox.sv rtl/openfpga_debug/openfpga_jtag_transport.sv sim/openfpga_debug/tb_openfpga_jtag_transport.sv
    xelab tb_openfpga_jtag_transport -s tb_openfpga_jtag_transport_sim
    xsim tb_openfpga_jtag_transport_sim -runall

# M33/M34 generic USER-DR command and transaction regression.
m34-user-dr-sim:
    xvlog -sv rtl/openfpga_debug/openfpga_jtag_user_dr.sv sim/openfpga_debug/tb_openfpga_jtag_user_dr.sv
    xelab tb_openfpga_jtag_user_dr -s tb_openfpga_jtag_user_dr_sim
    xsim tb_openfpga_jtag_user_dr_sim -runall

# Requires Vivado; elaborates the complete BSCANE2-to-mailbox integration only.
m34-user-dr-elab:
    {{vivado}} -mode batch -source prj/scripts/check_openfpga_jtag_m34_user_dr_elab.tcl

# Hardware operation: requires the Digilent FT232H cable and programmed M34 image.
m34-board-validate:
    {{python}} tools/jtag/validate_m34_board.py

# Hardware operation: validate UART protocol without requiring pyserial.
m34-uart-validate port="/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0" baud="115200":
    {{python}} tools/viewer/validate_uart_board.py --port {{port}} --baud {{baud}}

# Hardware operation: benchmark USER2 burst reads on the FT232H cable.
m34-jtag-benchmark:
    {{python}} tools/jtag/benchmark_m34_board.py

# Requires confirmation before running (Vivado RTL elaboration/CDC gate).
m33-elab:
    {{vivado}} -mode batch -source prj/scripts/check_openfpga_jtag_m33_elab.tcl

# M34 hardware-free Host Bridge regression.
m34-check:
    {{python}} tools/jtag/test_ftdi_mpsse.py
    {{python}} tools/jtag/test_ftdi_backend.py
    {{python}} tools/jtag/openfpga_jtag_bridge.py --self-test

# Start the local-only M34 bridge with the hardware-free backend.
m34-mock:
    {{python}} tools/jtag/openfpga_jtag_bridge.py --backend mock

# Start the local-only Bridge over the direct FT232H USER2 backend (hardware operation).
m35-ftdi-bridge tck="6000000" block="1024":
    {{python}} tools/jtag/openfpga_jtag_bridge.py --backend ftdi --tck-hz {{tck}} --block-size {{block}}

# Start Bridge for the M36 normal image and require its release build identity.
m36-ftdi-bridge tck="6000000" block="1024":
    {{python}} tools/jtag/openfpga_jtag_bridge.py --backend ftdi --tck-hz {{tck}} --block-size {{block}} --build-id 0x4d360001

# Start Bridge for the M36 performance image (M35-compatible performance build ID).
m36-perf-ftdi-bridge tck="6000000" block="1024":
    {{python}} tools/jtag/openfpga_jtag_bridge.py --backend ftdi --tck-hz {{tck}} --block-size {{block}} --build-id 0x4d350001

m35-perf-source-sim:
    xvlog -sv rtl/openfpga_debug/openfpga_jtag_perf_source.sv sim/openfpga_debug/tb_openfpga_jtag_perf_source.sv
    xelab tb_openfpga_jtag_perf_source -s tb_openfpga_jtag_perf_source_sim
    xsim tb_openfpga_jtag_perf_source_sim -runall

# Long Vivado build for the dedicated M35 sustained-throughput image.
m35-perf-bitstream:
    {{vivado}} -mode batch -source prj/scripts/build_openfpga_jtag_m35_perf_bitstream.tcl

# Hardware operation; exact cable target filter is mandatory.
m35-perf-program target:
    {{vivado}} -mode batch -source prj/scripts/program_openfpga_jtag_m35_perf.tcl -tclargs {{target}}

# M35 Viewer/JTAG source and bridge WebSocket regression.
m35-check: m34-check parser-test viewer-test

# M36 hardware-free release regression. Vivado synthesis is a separate gate.
m36-check: m35-check
    {{python}} tools/jtag/validate_m36_release.py --self-test

# Requires confirmation before running (five Vivado synthesis configurations).
m36-matrix:
    {{vivado}} -mode batch -source prj/scripts/check_openfpga_jtag_m36_matrix.tcl

# Long implementation/bitstream build; requires separate confirmation.
m36-ila-bitstream:
    {{vivado}} -mode batch -source prj/scripts/build_openfpga_jtag_m36_ila_bitstream.tcl

# Long M36 performance+ILA implementation build; explicitly authorized hardware image.
m36-perf-ila-bitstream:
    {{vivado}} -mode batch -source prj/scripts/build_openfpga_jtag_m36_ila_bitstream.tcl -tclargs perf

# Hardware operation; exact cable target filter and separate confirmation required.
m36-program target:
    {{vivado}} -mode batch -source prj/scripts/program_openfpga_jtag_m36_ila.tcl -tclargs {{target}}

# Hardware operation: program the M36 performance+ILA image on one exact target.
m36-perf-program target:
    {{vivado}} -mode batch -source prj/scripts/program_openfpga_jtag_m36_ila.tcl -tclargs {{target}} perf

# Hardware operation: exact target suffix and output file name are mandatory.
m36-ila-capture target output="m36_ila_capture.csv":
    {{vivado}} -mode batch -source prj/scripts/capture_openfpga_jtag_m36_ila.tcl -tclargs {{target}} {{output}}

# Validate a running real-board Bridge; defaults to the 30-minute release gate.
m36-soak seconds="1800" reconnects="3" output="prj/OpenFPGAStudio.runs/m36/m36_soak.csv":
    {{python}} tools/jtag/validate_m36_release.py --seconds {{seconds}} --client-reconnects {{reconnects}} --csv {{output}}

# M26 fast, hardware-free release regression.
m26-check: parser-test viewer-test la-validator-self-test la-core-sim la-board-sim

# M27 hardware-free Diagnostic Snapshot schema, fixture and integrity regression.
m27-check: parser-test
    {{python}} tools/viewer/ai_debug_validate.py snapshot
    node --check tools/viewer/web/diagnostic_snapshot.js

# M28 deterministic local diagnostics and golden-case regression.
m28-check: parser-test
    {{python}} tools/viewer/ai_debug_validate.py all
    node --check tools/viewer/web/diagnostic_rules.js

# M29 context, Provider lifecycle, and diagnosis-result validation regression.
m29-check: parser-test
    {{python}} tools/viewer/ai_debug_validate.py all
    node --check tools/viewer/web/ai_provider.js
    node --check tools/viewer/web/diagnosis_validator.js

# M30 integrated AI Debug Viewer workflow and existing Viewer performance gate.
m30-check: m29-check viewer-test
    node --check tools/viewer/web/ai_debug_model.js
    node --check tools/viewer/web/app.js

# Sixth-stage offline/no-secret release gate. Real-board qualification remains separate.
ai-debug-regression: parser-test
    {{python}} tools/viewer/ai_debug_validate.py release
    {{python}} tools/viewer/web/run_perf_test.py
    node --check tools/viewer/web/app.js

# Validate board-qualification metadata only; this does not claim hardware execution.
m31-board-manifest:
    {{python}} tools/viewer/ai_debug_validate.py board

parser-test:
    {{python}} tools/viewer/protocol_parser_test.py

viewer-test:
    {{python}} tools/viewer/web/run_perf_test.py

la-validator-self-test:
    {{python}} tools/viewer/logic_analyzer_validate.py --self-test

la-core-sim:
    xvlog -d OPENFPGA_DEBUG_SIM -i rtl/openfpga_debug rtl/openfpga_debug/openfpga_debug_pkg.vh rtl/openfpga_debug/openfpga_la_pkg.vh rtl/openfpga_debug/openfpga_la_probe_pack.v rtl/openfpga_debug/openfpga_la_trigger.v rtl/openfpga_debug/openfpga_la_core.v rtl/openfpga_debug/openfpga_la_adapter.v sim/openfpga_debug/tb_openfpga_la_core.v
    xelab tb_openfpga_la_core -s tb_openfpga_la_core_sim
    xsim tb_openfpga_la_core_sim -runall

profiler-probes-sim:
    xvlog -d OPENFPGA_DEBUG_SIM -i rtl/openfpga_debug rtl/openfpga_debug/openfpga_profiler_pkg.vh rtl/openfpga_debug/openfpga_profiler_axis_probe.v rtl/openfpga_debug/openfpga_profiler_fifo_probe.v rtl/openfpga_debug/openfpga_profiler_frame_probe.v rtl/openfpga_debug/openfpga_profiler_latency.v sim/openfpga_debug/tb_openfpga_profiler_probes.v
    xelab tb_openfpga_profiler_probes -s tb_openfpga_profiler_probes_sim
    xsim tb_openfpga_profiler_probes_sim -runall

la-board-sim:
    $rtl = Get-ChildItem rtl/openfpga_debug -File | Where-Object { $_.Extension -in '.vh', '.v' } | ForEach-Object FullName; xvlog -d OPENFPGA_DEBUG_SIM -i rtl/openfpga_debug $rtl rtl/board/openfpga_debug_board_demo.v sim/board/tb_openfpga_debug_board_la.v
    xelab tb_openfpga_debug_board_la -s tb_openfpga_debug_board_la_sim
    xsim tb_openfpga_debug_board_la_sim -runall

# Requires confirmation before running (Vivado synthesis/elaboration gate).
la-elab:
    {{vivado}} -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl

# Long implementation/bitstream build; requires confirmation before running.
la-bitstream:
    {{vivado}} -mode batch -source prj/scripts/build_openfpga_la_m26_bitstream.tcl

# Hardware operation; requires an explicit target filter and confirmation.
la-program target:
    {{vivado}} -mode batch -source prj/scripts/program_openfpga_debug_board_demo.tcl -tclargs {{target}}

# Hardware operation; install pyserial first if unavailable.
la-board-validate port baud="115200":
    {{python}} tools/viewer/logic_analyzer_validate.py --port {{port}} --baud {{baud}}
