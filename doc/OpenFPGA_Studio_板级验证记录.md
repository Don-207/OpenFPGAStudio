# OpenFPGA Studio 板级验证记录

## 1. 环境

| 项目 | 内容 |
| --- | --- |
| FPGA 器件 | `xcku5p-ffvb676-2-i` |
| 工程 | `prj/OpenFPGAStudio.xpr` |
| 顶层 | `openfpga_debug_board_demo` |
| 时钟 | 100 MHz 差分输入，`clk_p=J23`、`clk_n=J24` |
| 串口 | `COM6` |
| UART | `115200 8N1` |
| Viewer | Web Viewer / PowerShell serial validation |

## 2. 当前 XDC 映射

| 板级信号 | Demo 端口 | 管脚 | IOSTANDARD |
| --- | --- | --- | --- |
| `sys_clk_p` | `clk_p` | `J23` | `DIFF_HSTL_I_12` |
| `sys_clk_n` | `clk_n` | `J24` | `DIFF_HSTL_I_12` |
| `sys_rst_n` | `reset_n` | `L23` | `LVCMOS18` |
| `key` | `demo_trigger` | `N22` | `LVCMOS18` |
| `uart_txd` | `uart_tx` | `F15` | `LVCMOS18` |
| `led[0]` | `led0` | `G26` | `LVCMOS18` |
| `led[1]` | `led1` | `G25` | `LVCMOS18` |

`uart_rxd` 暂未使用，第一阶段仅实现 FPGA 到 PC 的 UART TX。

## 3. 2026-06-29 短时串口验证

命令行验证 `COM6`，采样 30 秒：

```text
duration_sec=30
frames_total=4978
HEARTBEAT=30
DEBUG_PRINT=150
EVENT=300
WATCH=2999
STATUS=1499
status_frames=1499
checksum_errors=0
sync_drops=0
pending_bytes=1
max_buffer_used=3
last_drop_count=0
```

结论：

- UART baud 和协议帧正确。
- 五类消息均持续输出。
- `checksum_errors=0`。
- `drop_count=0`。
- `pending_bytes=1` 是采样结束时截在下一帧中间，属于正常现象。

## 4. 待完成长稳验收

规划中的 M5 完整验收要求连续运行 30 分钟：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 1800
```

验收标准：

- `checksum_errors=0`。
- `last_drop_count=0` 或不持续增长。
- Web Viewer 无崩溃。
- 断开/复位后 Viewer parser 能重新同步。

## 5. 2026-06-30 JTAG 下载与短时串口复验

使用 Vivado batch 通过 JTAG 下载现有 bitstream：

```powershell
vivado -mode batch -source prj/scripts/program_openfpga_debug_board_demo.tcl
```

下载结果：

```text
PASS: Programmed xcku5p_0 with D:/code/fpga/xc7a35t/OpenFPGAStudio/prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit
```

随后使用 `COM6`、`115200 8N1` 采样 30 秒：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 30
```

结果：

```text
duration_sec=30
frames_total=4980
HEARTBEAT=30
DEBUG_PRINT=150
EVENT=300
WATCH=3000
STATUS=1500
status_frames=1500
checksum_errors=0
sync_drops=0
unknown_frames=0
pending_bytes=1
max_buffer_used=3
last_drop_count=0
last_packet_count=255
```

## 6. 2026-06-30 M10 Trace Probe 板级验证

基于 M10 当前 RTL 重新生成 bitstream：

```powershell
vivado -mode batch -source prj/scripts/build_openfpga_debug_board_demo.tcl
```

构建结果：

```text
PASS: Rebuilt OpenFPGA Debug board demo bitstream: D:/code/fpga/xc7a35t/OpenFPGAStudio/prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit
```

实现摘要：

```text
Synthesis finished with 0 errors, 0 critical warnings and 0 warnings.
place_design completed successfully
route_design completed successfully
write_bitstream completed successfully
Post Router Timing: WNS=7.074, TNS=0.000, WHS=0.029, THS=0.000
```

通过 JTAG 下载：

```powershell
vivado -mode batch -source prj/scripts/program_openfpga_debug_board_demo.tcl
```

下载结果：

```text
PASS: Programmed xcku5p_0 with D:/code/fpga/xc7a35t/OpenFPGAStudio/prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit
```

使用 `COM6`、`115200 8N1` 采样 30 秒：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 30
```

结果：

```text
port=COM6
baud=115200
duration_sec=30
frames_total=10976
HEARTBEAT=30
DEBUG_PRINT=150
EVENT=300
WATCH=2999
STATUS=1499
TRACE_SPAN_BEGIN=1799
TRACE_SPAN_END=1800
TRACE_MARK=1800
TRACE_VALUE=599
status_frames=1499
checksum_errors=0
sync_drops=0
unknown_frames=0
pending_bytes=1
max_buffer_used=4
last_drop_count=0
last_packet_count=160
```

结论：

- JTAG 下载链路正常。
- UART Debug Protocol v1 输出稳定。
- 第一阶段 `HEARTBEAT/DEBUG_PRINT/EVENT/WATCH/STATUS` 消息保持可见。
- M10 `TRACE_SPAN_BEGIN/TRACE_SPAN_END/TRACE_MARK/TRACE_VALUE` 消息保持可见。
- `checksum_errors=0`、`sync_drops=0`、`unknown_frames=0`。
- `last_drop_count=0`，短时运行未观察到发送队列丢包。
- `pending_bytes=1` 为采样窗口结束时截断到下一帧中间，属于正常现象。

验证过程中发现并修正：

- 初版 M10 demo 的 `TRACE_SCENARIO_INTERVAL_TICKS = CLK_FREQ_HZ / 200` 与 heartbeat/event/watch/status 周期存在整数对齐，Trace 优先级可能在固定相位挤掉部分旧 debug 脉冲。
- 已调整为 `(CLK_FREQ_HZ / 200) + 17`，避免固定相位碰撞；重新构建、下载后验证通过。

结论：

- JTAG 下载链路正常。
- UART Debug Protocol v1 输出稳定。
- 五类第一阶段消息均持续输出。
- `checksum_errors=0`、`sync_drops=0`、`unknown_frames=0`。
- `last_drop_count=0`，短时运行未观察到发送队列丢包。
- `pending_bytes=1` 为采样窗口结束时截断到下一帧中间，属于正常现象。
