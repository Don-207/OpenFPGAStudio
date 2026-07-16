# OpenFPGA Studio 第三阶段 Monitor 验证记录

## 已覆盖

| 类别 | 命令/入口 | 结果 |
| --- | --- | --- |
| Viewer parser | `python tools/viewer/protocol_parser_test.py` | PASS |
| M13 仿真 | `tb_openfpga_debug_command_parser` | PASS |
| M14 仿真 | `tb_openfpga_monitor_core` | PASS |
| M16 仿真 | `tb_openfpga_debug_board_monitor` | PASS |
| M13 elaboration | `prj/scripts/check_openfpga_monitor_m13_elab.tcl` | PASS |
| M16 elaboration | `prj/scripts/check_openfpga_monitor_m16_elab.tcl` | PASS |
| Bitstream 构建 | `vivado -mode batch -source prj/scripts/build_openfpga_debug_board_demo.tcl` | PASS |
| JTAG 下载 | `vivado -mode batch -source prj/program.tcl -tclargs prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit` | PASS |
| 30 秒 TX 长稳 | `powershell -ExecutionPolicy Bypass -File tools/viewer/serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 30` | PASS |
| Monitor 双向命令 | `powershell -ExecutionPolicy Bypass -File tools/viewer/monitor_validate.ps1 -Port COM6 -Baud 115200 -TimeoutMs 4000` | FAIL: read response timeout |

## 2026-06-30 顶层 RX 重构后复测

- `openfpga_debug_top` 已增加 `uart_rx` 入口，并在该层实例化 `openfpga_debug_uart_rx`、`openfpga_debug_command_parser`、`openfpga_monitor_core` 和 `openfpga_monitor_adapter`。
- `openfpga_debug_board_demo` 仅保留板级引脚和 demo 逻辑，将 `uart_rx` 传入 `openfpga_debug_top`。
- `tb_openfpga_debug_board_monitor`、`tb_openfpga_debug_protocol`、`check_openfpga_monitor_m16_elab.tcl`、`check_openfpga_trace_m10_elab.tcl` 复测 PASS。
- 重建 bitstream PASS，route 后估算 WNS=5.444ns、WHS=0.022ns；JTAG 下载到 `xcku5p_0` PASS。
- COM6 10 秒 TX 复测 PASS：1659 frames，checksum_errors=0，sync_drops=0，unknown_frames=0。
- COM6 Monitor 双向命令仍 FAIL：等待首个 `MONITOR_READ_RESP` 超时。

## 板级待验证

- 读取 `MONITOR_ID/MONITOR_VERSION`。
- 写 `LED_CONTROL` 后确认 LED 行为变化。
- 写 `DEMO_PERIOD` 后确认 Event/Trace 周期变化。
- 写 `CLEAR_COUNTERS` 后确认计数器清零。
- 非法地址和 RO 写入返回错误。
- 长稳 30 分钟，checksum error 不持续增加。

## 限制

`uart_rx` 已在 `prj/constraints/openfpga_debug_board_demo.xdc` 中补充，且与 vendor `pin.xdc` 中 `uart_rxd` 的 B16/LVCMOS18 一致。`uart_rx` 入口也已上移到 `openfpga_debug_top`，仿真和 elaboration 能覆盖 RX 到 Monitor response 的 RTL 路径。当前板级结果表明 FPGA 到 PC 的 `uart_tx` 链路稳定，PC 到 FPGA 的 `uart_rx` 命令链路尚未收到 Monitor response，需要继续检查 COM6 TX 到 B16 的线缆方向、电平和实际板级连接。Vivado 期间出现本机 Tcl store 写权限 warning，但构建、下载和 RTL/XDC 处理成功。
