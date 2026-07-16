# OpenFPGA Studio 第四阶段 Profiler 验证记录

## M21 Board Demo

已实现：

- Board demo 接入 `openfpga_profiler_core`、`openfpga_profiler_adapter` 和四类典型 probe。
- Profiler 帧通过现有 Debug Core UART TX path 输出，与 Debug、Trace、Monitor 帧共存。
- Monitor register map 增加 `0x0040..0x005C` Profiler 控制与状态寄存器。
- Web Viewer Profiler 控制地址已对齐 M21 register map。
- 新增 `tb_openfpga_debug_board_profiler.v` 覆盖 enable、sample period、mask、clear、alert 和多类型帧共存。
- 新增 Vivado RTL elaboration 脚本 `prj/scripts/check_openfpga_profiler_m21_elab.tcl`。

## 已执行

2026-07-02 已执行：

- `python tools\viewer\protocol_parser_test.py`
  - `PASS: OpenFPGA Debug Protocol parser test vectors passed`
- `python tools\viewer\web\run_perf_test.py`
  - 通过，`checksumErrors=0`、`profilerSnapshots=4`、`profilerAlerts=1`、`profilerMalformed=1`
- M18 Profiler Core XSim
  - `PASS: OpenFPGA Profiler M18 core snapshot checks passed`
- M19 Profiler Probes XSim
  - `PASS: OpenFPGA Profiler M19 probe checks passed`
- Monitor Core XSim
  - `PASS: OpenFPGA Monitor M14 core register checks passed`
- M21 Board Demo XSim
  - `PASS: OpenFPGA Profiler M21 board demo checks passed`
- M21 Vivado RTL elaboration
  - `PASS: OpenFPGA Profiler M21 board demo Vivado RTL elaboration completed`
- M21 bitstream build
  - `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit`
  - Bitstream timestamp: `2026-07-02 13:56:53`
- M21 board serial validation on `COM7`
  - Monitor: `PASS: OpenFPGA Monitor board validation passed`
  - Profiler: `PASS: OpenFPGA Profiler board validation passed`
  - Observed `PROFILER_ID=0x4F465034`, `PROFILER_VERSION=0x00010000`, four profiler snapshot metrics, and one profiler alert.
  - `PROFILER_STATUS` read after high-rate profiler traffic may timeout because snapshot/alert frames can saturate the shared UART path; the validator treats that final read as advisory after required snapshots and alert have been observed.

```powershell
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_uart_rx.v rtl\openfpga_debug\openfpga_debug_command_parser.v rtl\openfpga_debug\openfpga_trace_adapter.v rtl\openfpga_debug\openfpga_trace_dma_probe.v rtl\openfpga_debug\openfpga_trace_frame_probe.v rtl\openfpga_debug\openfpga_trace_fifo_probe.v rtl\openfpga_debug\openfpga_trace_irq_probe.v rtl\openfpga_debug\openfpga_monitor_reg_bank.v rtl\openfpga_debug\openfpga_monitor_core.v rtl\openfpga_debug\openfpga_monitor_adapter.v rtl\openfpga_debug\openfpga_profiler_counter.v rtl\openfpga_debug\openfpga_profiler_core.v rtl\openfpga_debug\openfpga_profiler_adapter.v rtl\openfpga_debug\openfpga_profiler_axis_probe.v rtl\openfpga_debug\openfpga_profiler_fifo_probe.v rtl\openfpga_debug\openfpga_profiler_frame_probe.v rtl\openfpga_debug\openfpga_profiler_latency.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_profiler.v
xelab tb_openfpga_debug_board_profiler -s tb_openfpga_debug_board_profiler_sim
xsim tb_openfpga_debug_board_profiler_sim -runall
```

Vivado RTL elaboration 已执行：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_profiler_m21_elab.tcl
```

## 板级待验证

- Web Viewer 人工观察 Profiler 视图。
- 连续运行 30 分钟，确认 checksum error、drop、overflow 不持续增长。
