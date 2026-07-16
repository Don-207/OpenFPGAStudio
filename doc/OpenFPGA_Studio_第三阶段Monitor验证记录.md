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
| POSIX Monitor只读命令 | `just monitor-read-validate /dev/ttyUSB1 115200 0x0000` | PASS：`MONITOR_ID=0x4F464D30` |
| POSIX Monitor版本读取 | `just monitor-read-validate /dev/ttyUSB1 115200 0x0004` | PASS：`MONITOR_VERSION=0x00010000` |

## 2026-06-30 顶层 RX 重构后复测

- `openfpga_debug_top` 已增加 `uart_rx` 入口，并在该层实例化 `openfpga_debug_uart_rx`、`openfpga_debug_command_parser`、`openfpga_monitor_core` 和 `openfpga_monitor_adapter`。
- `openfpga_debug_board_demo` 仅保留板级引脚和 demo 逻辑，将 `uart_rx` 传入 `openfpga_debug_top`。
- `tb_openfpga_debug_board_monitor`、`tb_openfpga_debug_protocol`、`check_openfpga_monitor_m16_elab.tcl`、`check_openfpga_trace_m10_elab.tcl` 复测 PASS。
- 重建 bitstream PASS，route 后估算 WNS=5.444ns、WHS=0.022ns；JTAG 下载到 `xcku5p_0` PASS。
- COM6 10 秒 TX 复测 PASS：1659 frames，checksum_errors=0，sync_drops=0，unknown_frames=0。
- COM6 Monitor 双向命令仍 FAIL：等待首个 `MONITOR_READ_RESP` 超时。

## 2026-07-16 Linux板级复测

- CH340 `1a86:7523`绑定`ch341`驱动，串口节点为`/dev/ttyUSB1`；FT232H `0403:6014`同时可见。
- 10秒UART TX只读验证PASS：25272 bytes、1662 frames、约2527 B/s，`checksum_errors=0`、`version_errors=0`。
- 使用无pyserial依赖入口发送一次`MONITOR_READ_REQ`读取`0x0000`，收到合法`MONITOR_READ_RESP`：status=0、width=4、value=`0x4F464D30`。
- 读取`0x0004`同样PASS：status=0、width=4、value=`0x00010000`、`checksum_errors=0`。
- 首次读取在持续流中途打开串口，收到正确响应的同时记录1个校验候选错误；立即重复读取为0，独立10秒TX验证亦为0。该现象保留记录，不据此宣称长稳通过。
- 结论：PC到FPGA UART RX、Command Parser、Monitor Core、Response Adapter和FPGA到PC TX读响应链路已真实闭环。Monitor写操作、错误响应和30分钟长稳仍待执行。
- 安全写入suite PASS：`LED_CONTROL`从`0x00000000`临时改为`0x00000003`，读回一致，随后恢复并再次读回`0x00000000`。
- 权限/错误语义PASS：写RO `MONITOR_ID`返回`DENIED(2)`；读取`0x003C`返回`BAD_ADDR(1)`。
- 60秒双向冒烟PASS：每秒读取一次`MONITOR_ID`，共60次，timeout=0、`checksum_errors=0`；打开持续流时前导半帧产生`sync_drops=4`。
- 新增正式入口`just monitor-soak /dev/ttyUSB1 115200 1800 1`；60秒结果不替代30分钟发布门禁。

## 板级待验证

- ~~读取 `MONITOR_ID/MONITOR_VERSION`。~~ 2026-07-16 PASS。
- ~~写 `LED_CONTROL` 后确认寄存器变化并恢复。~~ 2026-07-16 PASS；人工LED视觉确认未作为自动门禁。
- 写 `DEMO_PERIOD` 后确认 Event/Trace 周期变化。
- 写 `CLEAR_COUNTERS` 后确认计数器清零。
- ~~非法地址和 RO 写入返回错误。~~ 2026-07-16 PASS。
- 长稳 30 分钟，checksum error 不持续增加。

## 限制

`uart_rx` 已在 `prj/constraints/openfpga_debug_board_demo.xdc` 中补充，且与 vendor `pin.xdc` 中 `uart_rxd` 的 B16/LVCMOS18 一致。`uart_rx` 入口也已上移到 `openfpga_debug_top`，仿真和 elaboration 能覆盖 RX 到 Monitor response 的 RTL 路径。2026-07-16 Linux板级复测已证明读请求和响应链路有效；此前COM6超时作为历史结果保留，可能与当时串口、线缆方向或环境有关。写操作、错误响应和30分钟长稳完成前，第三阶段仍不标记完整发布。Vivado期间出现的本机Tcl store写权限warning不影响既有构建、下载和RTL/XDC处理结果。
