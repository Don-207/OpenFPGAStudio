# YiFPGA Studio

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

YiFPGA Studio（原 OpenFPGA Studio）是面向 FPGA 的开放调试与可观测性平台。当前 v1.1.0 以 Xilinx `xcku5p-ffvb676-2-i` 为参考平台，提供 Debug Core、Trace、Monitor、Profiler、Logic Analyzer、AI Debug，以及 UART/JTAG 数据通道和统一 Web Viewer。

当前板级 demo 已在 `xcku5p-ffvb676-2-i` 工程上跑通，默认串口参数为 `115200 8N1`。

## 当前能力

- Debug Protocol v1：`SOF + VER + TYPE + LEN + PAYLOAD + XOR checksum`
- Debug Core：packetizer、timestamp、ring buffer、UART TX/RX、事件、Watch、状态和丢包统计。
- Trace：Span/Mark/Value/Drop 模型，以及 DMA、Frame、FIFO、IRQ Probe 和时间轴视图。
- Monitor：安全寄存器窗口、读写权限、W1C/Trigger 和 Viewer 轮询；RTL 与真实板级 UART/JTAG 闭环均已通过。
- Profiler：AXI Stream、FIFO、Frame、Latency指标采集、告警、趋势和Monitor配置窗口。
- Logic Analyzer：32-bit/128-sample参考捕获、触发、分块读出、波形显示及VCD/JSONL导出。
- AI Debug：诊断快照、证据模型、10条本地规则、12个Golden Cases、受校验Provider和无网络降级。
- Transport：UART和Xilinx BSCAN/USER2 JTAG；normal、performance 和 JTAG-only+ILA 板级闭环已通过，performance 长稳达到 232,687.952 B/s。
- Web Viewer：共享协议Parser、串口/JTAG来源选择、七类视图、暂停、历史、反馈和导出。
- 板级Demo：100 MHz差分时钟、UART、JTAG、LED、可控场景和多类观测数据源。

Qt Viewer 仍保留为后续目标；当前以 Web Viewer 作为可验收上位机。

## v1.1.0 迁移状态与边界

当前源码已发布为 **v1.1.0**。YiFPGA canonical 名称、旧名兼容入口、Vivado 构建矩阵、normal/performance/JTAG-only+ILA 板级复验、干净 clone 和离线发布门禁均已完成。

v1.1.0 只承诺 Xilinx 参考实现；Intel/Lattice/国产 FPGA、PCIe/Ethernet/USB/SPI Transport 和 Qt Viewer 属于后续版本。迁移范围、门禁、兼容期和回退方法见 [v1.1.0 Release Notes](doc/YiFPGA_Studio_v1.1.0_Release_Notes.md)。

## 目录

```text
rtl/yifpga_debug/        Debug Core RTL
rtl/board/                 xcku5p board demo top
sim/yifpga_debug/        Debug Core protocol/ring-buffer tests
sim/board/                 Board demo UART test
tools/viewer/web/          Web Viewer
tools/viewer/              Parser tests and serial validation helper
doc/                       Protocol, milestone, usage, and validation docs
prj/                       Vivado project, constraints, scripts, generated runs
```

## 快速开始

1. 打开 Vivado 工程：

```powershell
vivado prj\YiFPGAStudio.xpr
```

2. 确认顶层为 `yifpga_debug_board_demo`，器件为 `xcku5p-ffvb676-2-i`。

3. 使用当前约束文件生成 bitstream：

```text
prj/constraints/yifpga_debug_board_demo.xdc
```

4. 下载 bitstream 后，打开 Web Viewer：

```text
tools/viewer/web/index.html
```

请使用 Chrome 或 Edge，因为 Web Serial API 需要 Chromium 系浏览器。

5. 选择 `115200` baud，点击 `Connect`，选择板卡串口。

## 板级串口验证

也可以用命令行验证串口输出。以 `COM6`、30 秒采样为例：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 30
```

规划中的 30 分钟长稳验收：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 1800
```

期望结果：

- `checksum_errors=0`
- `last_drop_count=0`
- `HEARTBEAT` 约为运行秒数
- `WATCH/STATUS/EVENT/DEBUG_PRINT` 按 demo 周期持续增长

## 仿真

v1.0统一无硬件、无网络门禁：

```text
just release-check
```

该命令不会综合、生成或下载bitstream，也不会连接真实板卡。Vivado和硬件门禁必须按收口计划独立执行。

M2 协议/UART 基础测试：

```powershell
xvlog -i rtl\yifpga_debug rtl\yifpga_debug\yifpga_debug_pkg.vh rtl\yifpga_debug\yifpga_debug_timestamp.v rtl\yifpga_debug\yifpga_debug_ring_buffer.v rtl\yifpga_debug\yifpga_debug_packetizer.v rtl\yifpga_debug\yifpga_debug_uart_tx.v rtl\yifpga_debug\yifpga_debug_core.v rtl\yifpga_debug\yifpga_debug_top.v sim\yifpga_debug\tb_yifpga_debug_protocol.v
xelab tb_yifpga_debug_protocol -s tb_yifpga_debug_protocol_sim
xsim tb_yifpga_debug_protocol_sim -runall
```

M3 ring buffer/debug core 测试：

```powershell
xvlog -i rtl\yifpga_debug rtl\yifpga_debug\yifpga_debug_pkg.vh rtl\yifpga_debug\yifpga_debug_timestamp.v rtl\yifpga_debug\yifpga_debug_ring_buffer.v rtl\yifpga_debug\yifpga_debug_packetizer.v rtl\yifpga_debug\yifpga_debug_uart_tx.v rtl\yifpga_debug\yifpga_debug_core.v rtl\yifpga_debug\yifpga_debug_top.v sim\yifpga_debug\tb_yifpga_debug_m3.v
xelab tb_yifpga_debug_m3 -s tb_yifpga_debug_m3_sim
xsim tb_yifpga_debug_m3_sim -runall
```

M5 board demo UART 输出测试：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\yifpga_debug rtl\yifpga_debug\yifpga_debug_pkg.vh rtl\yifpga_debug\yifpga_debug_timestamp.v rtl\yifpga_debug\yifpga_debug_ring_buffer.v rtl\yifpga_debug\yifpga_debug_packetizer.v rtl\yifpga_debug\yifpga_debug_uart_tx.v rtl\yifpga_debug\yifpga_debug_core.v rtl\yifpga_debug\yifpga_debug_top.v rtl\board\yifpga_debug_board_demo.v sim\board\tb_yifpga_debug_board_demo.v
xelab tb_yifpga_debug_board_demo -s tb_yifpga_debug_board_demo_sim
xsim tb_yifpga_debug_board_demo_sim -runall
```

M9 Trace Adapter 测试：

```powershell
xvlog -i rtl\yifpga_debug rtl\yifpga_debug\yifpga_trace_pkg.vh rtl\yifpga_debug\yifpga_trace_adapter.v sim\yifpga_debug\tb_yifpga_trace_adapter.v
xelab tb_yifpga_trace_adapter -s tb_yifpga_trace_adapter_sim
xsim tb_yifpga_trace_adapter_sim -runall
```

M10 Trace board demo 测试：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\yifpga_debug rtl\yifpga_debug\yifpga_debug_pkg.vh rtl\yifpga_debug\yifpga_trace_pkg.vh rtl\yifpga_debug\yifpga_debug_timestamp.v rtl\yifpga_debug\yifpga_debug_ring_buffer.v rtl\yifpga_debug\yifpga_debug_packetizer.v rtl\yifpga_debug\yifpga_debug_uart_tx.v rtl\yifpga_debug\yifpga_trace_adapter.v rtl\yifpga_debug\yifpga_trace_dma_probe.v rtl\yifpga_debug\yifpga_trace_frame_probe.v rtl\yifpga_debug\yifpga_trace_fifo_probe.v rtl\yifpga_debug\yifpga_trace_irq_probe.v rtl\yifpga_debug\yifpga_debug_core.v rtl\yifpga_debug\yifpga_debug_top.v rtl\board\yifpga_debug_board_demo.v sim\board\tb_yifpga_debug_board_demo.v
xelab tb_yifpga_debug_board_demo -s tb_yifpga_debug_board_demo_m10_sim
xsim tb_yifpga_debug_board_demo_m10_sim -runall
```

M10 Trace Vivado elaboration：

```powershell
vivado -mode batch -source prj/scripts/check_yifpga_trace_m10_elab.tcl
```

PC parser 测试：

```powershell
python tools\viewer\protocol_parser_test.py
```

Web Viewer Trace 性能冒烟：

```powershell
python tools\viewer\web\run_perf_test.py
```

## AI Debug（第六阶段）

Web Viewer 的 `AI Debug` 区域可以从当前 session、时间窗或最新 Logic Analyzer capture 创建诊断快照，运行本地确定性规则，并在显式确认脱敏预览后使用无网络 Mock Provider。AI 结果经过 schema、confidence、evidence 白名单和安全分类校验，不会覆盖本地 finding，也不会自动写寄存器、控制 LA、下载 bitstream 或运行构建。

硬件无关发布门禁：

```text
just ai-debug-regression
```

分项验证：

```text
python3 tools/viewer/ai_debug_validate.py snapshot
python3 tools/viewer/ai_debug_validate.py rules
python3 tools/viewer/ai_debug_validate.py provider
python3 tools/viewer/ai_debug_validate.py board
python3 tools/viewer/ai_debug_validate.py release
```

`board` 命令只验证板级场景元数据和离线向量，不代表真实硬件已经执行。完整第六阶段发布还必须完成验证记录和 Checklist 中未勾选的板级故障注入、恢复及长稳项目。

## 文档

### 品牌与版本

- [v1.1.0 Release Notes](doc/YiFPGA_Studio_v1.1.0_Release_Notes.md)
- [YiFPGA 品牌与代码兼容迁移计划](doc/YiFPGA_品牌与代码兼容迁移计划.md)
- [YF.WP0 YiFPGA 名称与资产冻结记录](doc/YF_WP0_YiFPGA名称与资产冻结记录.md)
- [YiFPGA 品牌迁移与兼容说明](doc/YiFPGA_品牌迁移说明.md)
- [v1.0 收口阶段实施计划](doc/YiFPGA_Studio_v1.0收口阶段实施计划.md)

### 协议与使用说明

- [Debug Protocol v1](doc/YiFPGA_Debug_Protocol_v1.md)
- [Debug Core 使用说明](doc/YiFPGA_Debug_Core_使用说明.md)
- [Trace 使用说明](doc/YiFPGA_Trace_使用说明.md)
- [Monitor 使用说明](doc/YiFPGA_Monitor_使用说明.md)
- [Profiler 使用说明](doc/YiFPGA_Profiler_使用说明.md)
- [Profiler Probe 接入说明](doc/YiFPGA_Profiler_Probe接入说明.md)
- [Logic Analyzer 使用说明](doc/YiFPGA_LogicAnalyzer_使用说明.md)
- [Web Viewer 使用说明](doc/YiFPGA_Web_Viewer_使用说明.md)
- [JTAG Transport 设计说明](doc/YiFPGA_JTAG_Transport_设计说明.md)
- [JTAG Transport 使用说明](doc/YiFPGA_JTAG_Transport_使用说明.md)
- [JTAG Bridge 使用说明](doc/YiFPGA_JTAG_Bridge_使用说明.md)
- [板级验证记录](doc/YiFPGA_Studio_板级验证记录.md)
- [AI Debug 使用说明](doc/YiFPGA_AI_Debug_使用说明.md)
- [第六阶段 AI Debug 验证记录](doc/YiFPGA_Studio_第六阶段AIDebug验证记录.md)
- [第六阶段 AI Debug 发布 Checklist](doc/YiFPGA_Studio_第六阶段AIDebug发布Checklist.md)
- [第二阶段 Trace 验证记录](doc/YiFPGA_Studio_第二阶段Trace验证记录.md)
- [第二阶段 Trace 发布 Checklist](doc/YiFPGA_Studio_第二阶段Trace发布Checklist.md)
- [第三阶段 Monitor 实施计划](doc/YiFPGA_Studio_第三阶段Monitor实施计划.md)
- [第一阶段实现规划](doc/YiFPGA_Studio_第一阶段实现规划.md)
- [第二阶段 Trace 实施计划](doc/YiFPGA_Studio_第二阶段Trace实施计划.md)

### M1–M36 实施计划

- [M1 协议与工程骨架](doc/M1_协议与工程骨架实施计划.md)
- [M2 UART TX 与协议解析闭环](doc/M2_UART_TX_与协议解析闭环实施计划.md)
- [M3 Ring Buffer 与 Debug Core](doc/M3_Ring_Buffer_与_Debug_Core实施计划.md)
- [M4 Viewer 基础视图](doc/M4_Viewer_基础视图实施计划.md)
- [M5 板级集成验证](doc/M5_板级集成验证实施计划.md)
- [M6 第一阶段整理发布](doc/M6_第一阶段整理发布实施计划.md)
- [M7 Trace 协议与模型实施计划](doc/M7_Trace_协议与模型实施计划.md)
- [M8 Trace Viewer 时间轴实施计划](doc/M8_Trace_Viewer_时间轴实施计划.md)
- [M9 RTL Trace Adapter 实施计划](doc/M9_RTL_Trace_Adapter实施计划.md)
- [M10 典型 Probe 与 Demo 实施计划](doc/M10_典型Probe与Demo实施计划.md)
- [M11 第二阶段整理与发布实施计划](doc/M11_第二阶段整理与发布实施计划.md)
- [M12 Monitor 协议与命令模型](doc/M12_Monitor_协议与命令模型实施计划.md)
- [M13 UART RX 与 Command Parser](doc/M13_UART_RX与Command_Parser实施计划.md)
- [M14 RTL Monitor Core 与寄存器窗口](doc/M14_RTL_Monitor_Core与寄存器窗口实施计划.md)
- [M15 Monitor Viewer](doc/M15_Monitor_Viewer实施计划.md)
- [M16 板级 Demo 与第三阶段发布](doc/M16_板级Demo与第三阶段发布实施计划.md)
- [M17 Profiler 协议与指标模型](doc/M17_Profiler_协议与指标模型实施计划.md)
- [M18 RTL Profiler Core 与计数窗口](doc/M18_RTL_Profiler_Core与计数窗口实施计划.md)
- [M19 典型 Profiler Probe](doc/M19_典型Profiler_Probe实施计划.md)
- [M20 Profiler Viewer](doc/M20_Profiler_Viewer实施计划.md)
- [M21 板级 Demo 与第四阶段发布](doc/M21_板级Demo与第四阶段发布实施计划.md)
- [M22 Logic Analyzer 协议与捕获模型](doc/M22_LogicAnalyzer_协议与捕获模型实施计划.md)
- [M23 RTL Logic Analyzer Core](doc/M23_RTL_LogicAnalyzer_Core实施计划.md)
- [M24 Logic Analyzer Viewer](doc/M24_LogicAnalyzer_Viewer实施计划.md)
- [M25 典型 Probe 与 Board Demo 接入](doc/M25_典型Probe与BoardDemo接入实施计划.md)
- [M26 板级验证与第五阶段发布](doc/M26_板级验证与第五阶段发布实施计划.md)
- [M27 诊断快照与证据模型](doc/M27_诊断快照与证据模型实施计划.md)
- [M28 本地诊断规则与 Golden Cases](doc/M28_本地诊断规则与GoldenCases实施计划.md)
- [M29 AI Provider 与诊断结果校验](doc/M29_AIProvider与诊断结果校验实施计划.md)
- [M30 AI Debug Viewer](doc/M30_AI_Debug_Viewer实施计划.md)
- [M31 板级故障注入与第六阶段发布](doc/M31_板级故障注入与第六阶段发布实施计划.md)
- [M32 Transport 抽象与 JTAG Mailbox 协议](doc/M32_Transport抽象与JTAGMailbox协议实施计划.md)
- [M33 JTAG RTL 与 Xilinx BSCAN](doc/M33_JTAG_RTL与XilinxBSCAN实施计划.md)
- [M34 JTAG Host Bridge](doc/M34_JTAG_HostBridge实施计划.md)
- [M35 Viewer 接入与 JTAG 性能优化](doc/M35_Viewer接入与JTAG性能优化实施计划.md)
- [M36 ILA 共存与第七阶段发布](doc/M36_ILA共存与第七阶段发布实施计划.md)
