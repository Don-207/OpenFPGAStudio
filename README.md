# OpenFPGA Studio

OpenFPGA Studio 当前提供一个 FPGA 调试与 Trace 观测闭环：FPGA 端 `OpenFPGA Debug Core` 产生二进制调试帧，经 UART 输出到 PC；PC 端使用 Web Viewer 接收、解析、展示和导出日志与 Trace 时间线。

当前板级 demo 已在 `xcku5p-ffvb676-2-i` 工程上跑通，默认串口参数为 `115200 8N1`。

## 当前能力

- Debug Protocol v1：`SOF + VER + TYPE + LEN + PAYLOAD + XOR checksum`
- 消息类型：`HEARTBEAT`、`DEBUG_PRINT`、`EVENT`、`WATCH`、`STATUS`、`TRACE_SPAN_BEGIN/END`、`TRACE_MARK`、`TRACE_VALUE`、`TRACE_DROP`
- RTL：packetizer、UART TX、timestamp、ring buffer、Trace Adapter、DMA/Frame/FIFO/IRQ probe、drop/packet/buffer 统计
- Web Viewer：串口连接、协议解析、Log/Event/Watch/Status/Trace 视图、暂停、清空、CSV/JSONL 导出
- 板级 demo：100 MHz 差分时钟、UART TX、两个 LED、按钮触发 event/print，并周期性输出 Trace 场景

Qt Viewer 仍保留为后续目标；当前以 Web Viewer 作为可验收上位机。

## 目录

```text
rtl/openfpga_debug/        Debug Core RTL
rtl/board/                 xcku5p board demo top
sim/openfpga_debug/        Debug Core protocol/ring-buffer tests
sim/board/                 Board demo UART test
tools/viewer/web/          Web Viewer
tools/viewer/              Parser tests and serial validation helper
doc/                       Protocol, milestone, usage, and validation docs
prj/                       Vivado project, constraints, scripts, generated runs
```

## 快速开始

1. 打开 Vivado 工程：

```powershell
vivado prj\OpenFPGAStudio.xpr
```

2. 确认顶层为 `openfpga_debug_board_demo`，器件为 `xcku5p-ffvb676-2-i`。

3. 使用当前约束文件生成 bitstream：

```text
prj/constraints/openfpga_debug_board_demo.xdc
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

M2 协议/UART 基础测试：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v sim\openfpga_debug\tb_openfpga_debug_protocol.v
xelab tb_openfpga_debug_protocol -s tb_openfpga_debug_protocol_sim
xsim tb_openfpga_debug_protocol_sim -runall
```

M3 ring buffer/debug core 测试：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v sim\openfpga_debug\tb_openfpga_debug_m3.v
xelab tb_openfpga_debug_m3 -s tb_openfpga_debug_m3_sim
xsim tb_openfpga_debug_m3_sim -runall
```

M5 board demo UART 输出测试：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_demo.v
xelab tb_openfpga_debug_board_demo -s tb_openfpga_debug_board_demo_sim
xsim tb_openfpga_debug_board_demo_sim -runall
```

M9 Trace Adapter 测试：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_trace_adapter.v sim\openfpga_debug\tb_openfpga_trace_adapter.v
xelab tb_openfpga_trace_adapter -s tb_openfpga_trace_adapter_sim
xsim tb_openfpga_trace_adapter_sim -runall
```

M10 Trace board demo 测试：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_trace_adapter.v rtl\openfpga_debug\openfpga_trace_dma_probe.v rtl\openfpga_debug\openfpga_trace_frame_probe.v rtl\openfpga_debug\openfpga_trace_fifo_probe.v rtl\openfpga_debug\openfpga_trace_irq_probe.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_demo.v
xelab tb_openfpga_debug_board_demo -s tb_openfpga_debug_board_demo_m10_sim
xsim tb_openfpga_debug_board_demo_m10_sim -runall
```

M10 Trace Vivado elaboration：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl
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

- [v1.0 收口阶段实施计划](doc/OpenFPGA_Studio_v1.0收口阶段实施计划.md)
- [Debug Protocol v1](doc/OpenFPGA_Debug_Protocol_v1.md)
- [Debug Core 使用说明](doc/OpenFPGA_Debug_Core_使用说明.md)
- [Trace 使用说明](doc/OpenFPGA_Trace_使用说明.md)
- [Web Viewer 使用说明](doc/OpenFPGA_Web_Viewer_使用说明.md)
- [板级验证记录](doc/OpenFPGA_Studio_板级验证记录.md)
- [AI Debug 使用说明](doc/OpenFPGA_AI_Debug_使用说明.md)
- [第六阶段 AI Debug 验证记录](doc/OpenFPGA_Studio_第六阶段AIDebug验证记录.md)
- [第六阶段 AI Debug 发布 Checklist](doc/OpenFPGA_Studio_第六阶段AIDebug发布Checklist.md)
- [第二阶段 Trace 验证记录](doc/OpenFPGA_Studio_第二阶段Trace验证记录.md)
- [第二阶段 Trace 发布 Checklist](doc/OpenFPGA_Studio_第二阶段Trace发布Checklist.md)
- [第三阶段 Monitor 实施计划](doc/OpenFPGA_Studio_第三阶段Monitor实施计划.md)
- [第一阶段实现规划](doc/OpenFPGA_Studio_第一阶段实现规划.md)
- [第二阶段 Trace 实施计划](doc/OpenFPGA_Studio_第二阶段Trace实施计划.md)
- [M7 Trace 协议与模型实施计划](doc/M7_Trace_协议与模型实施计划.md)
- [M8 Trace Viewer 时间轴实施计划](doc/M8_Trace_Viewer_时间轴实施计划.md)
- [M9 RTL Trace Adapter 实施计划](doc/M9_RTL_Trace_Adapter实施计划.md)
- [M10 典型 Probe 与 Demo 实施计划](doc/M10_典型Probe与Demo实施计划.md)
- [M11 第二阶段整理与发布实施计划](doc/M11_第二阶段整理与发布实施计划.md)
