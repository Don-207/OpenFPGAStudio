# OpenFPGA Studio 第一阶段实现规划

## 1. 阶段目标

第一阶段目标是完成一个可在真实 FPGA 工程中使用的最小闭环调试系统：

- FPGA 端提供 `OpenFPGA Debug Core`，支持 Debug Print、Event、Watch、Timestamp 和 Ring Buffer。
- PC 端提供 Qt Viewer，通过 UART 接收、解析、展示调试数据。
- 定义稳定的 Debug Protocol，保证后续 UART、USB、Ethernet、PCIe、JTAG 等传输方式可以复用同一套上层协议。
- 在当前 xcku5p-ffvb676-2-i 工程上完成验证，形成可复制到其他 FPGA 工程的 RTL IP 与软件工具结构。

第一阶段不追求复杂 Trace、Profiler 或逻辑分析功能，重点是把“FPGA 内部信息实时可观测”这条链路打通。

## 2. 总体架构

```text
FPGA User Logic
    |
    | debug_print / event / watch_update
    v
OpenFPGA Debug Core
    |
    | framed debug packets
    v
UART Transport
    |
    | serial stream
    v
Qt Viewer
    |
    | decode / filter / display / export
    v
Developer
```

模块边界：

- `Debug Core`：负责收集调试信息、打时间戳、封包、缓存和流控。
- `Debug Protocol`：定义帧格式、消息类型、字段编码、校验和版本。
- `UART Transport`：只负责字节流发送，尽量不绑定调试语义。
- `Qt Viewer`：负责串口连接、协议解析、展示、过滤、暂停、保存日志。

## 3. 功能范围

### 3.1 FPGA RTL 功能

必须实现：

- Ring Buffer
  - 支持写入变长或定长调试包。
  - 支持满状态处理：丢弃新包或覆盖旧包，第一版建议默认丢弃新包并记录 drop counter。
  - 提供 buffer usage、packet count、drop count 状态。

- Timestamp
  - 使用系统时钟计数器生成时间戳。
  - 第一版使用 32 bit tick，后续可扩展 64 bit。
  - Qt Viewer 根据时钟频率换算为 us/ms。

- Event
  - 支持事件 ID。
  - 支持一个可选 32 bit 参数。
  - 用于记录状态切换、中断、FIFO 异常、帧开始结束等离散事件。

- Watch
  - 支持若干 watch channel。
  - 每个 watch channel 包含 ID、当前值、更新时间戳。
  - 第一版使用主动上报方式，不做 PC 端轮询写寄存器。

- Debug Print
  - FPGA 端不实现完整字符串格式化。
  - 推荐第一版使用 `print_id + arg0 + arg1` 形式，由 PC 端映射为文本。
  - 可额外支持短 ASCII 字符串包，但不作为性能路径依赖。

- UART TX
  - 支持可配置波特率。
  - 第一版目标波特率：115200、921600、3000000 三档。
  - 从 Debug Core Ring Buffer 取包并发送。

暂不实现：

- PC 到 FPGA 的在线寄存器读写。
- 多传输接口抽象层的完整实现。
- 复杂 printf 格式化。
- Trace 时间线、Profiler、逻辑分析采样。

### 3.2 Qt Viewer 功能

必须实现：

- 串口设备扫描、连接、断开。
- 波特率选择。
- Debug Protocol 解包、CRC/Checksum 校验、错误帧统计。
- 日志视图：
  - 时间戳
  - 类型
  - ID
  - 参数
  - 解码后的文本
- Event 视图：
  - 按事件 ID 过滤。
  - 显示最近事件和计数。
- Watch 视图：
  - 按 watch ID 显示最新值。
  - 显示更新时间和变化次数。
- 暂停显示但继续接收。
- 清空视图。
- 导出 CSV 或 JSONL 日志。

可选实现：

- 简单曲线显示 watch 值。
- 关键字过滤。
- 颜色标记不同事件等级。

## 4. Debug Protocol 第一版

### 4.1 帧格式

建议采用二进制帧，避免文本协议带来的带宽浪费。

```text
+----------+----------+---------+---------+-----------+---------+
| SOF[1]   | VER[1]   | TYPE[1] | LEN[1]  | PAYLOAD   | CRC[1]  |
+----------+----------+---------+---------+-----------+---------+
```

字段定义：

- `SOF`：固定 `0xA5`。
- `VER`：协议版本，第一版为 `0x01`。
- `TYPE`：消息类型。
- `LEN`：payload 长度，0 到 255。
- `PAYLOAD`：小端编码。
- `CRC`：第一版可使用 CRC-8；若 RTL 复杂度优先，也可先用 XOR checksum，后续升级 CRC-8。

为降低第一版 RTL 复杂度，建议先实现：

- 固定头。
- payload 最大 16 或 32 字节。
- checksum 使用 XOR。

协议升级时保持 `VER` 字段，不破坏 Viewer 的多版本解析能力。

### 4.2 消息类型

```text
0x01 HEARTBEAT
0x02 DEBUG_PRINT
0x03 EVENT
0x04 WATCH
0x05 STATUS
```

`HEARTBEAT` payload：

```text
u32 timestamp
```

`DEBUG_PRINT` payload：

```text
u32 timestamp
u16 print_id
u32 arg0
u32 arg1
```

`EVENT` payload：

```text
u32 timestamp
u16 event_id
u8  level
u32 arg0
```

`WATCH` payload：

```text
u32 timestamp
u16 watch_id
u32 value
```

`STATUS` payload：

```text
u32 timestamp
u16 buffer_used
u16 drop_count
u16 packet_count
```

## 5. RTL 目录建议

```text
rtl/
  openfpga_debug/
    openfpga_debug_core.v
    openfpga_debug_pkg.vh
    openfpga_debug_packetizer.v
    openfpga_debug_ring_buffer.v
    openfpga_debug_timestamp.v
    openfpga_debug_uart_tx.v
    openfpga_debug_uart_baud.v
    openfpga_debug_top.v
sim/
  openfpga_debug/
    tb_openfpga_debug_core.v
    tb_openfpga_debug_uart_tx.v
    tb_openfpga_debug_protocol.v
tools/
  viewer/
    OpenFPGAViewer/
```

如果现有 Vivado 工程暂时不适合大改，可以先在 `src/rtl/openfpga_debug` 下建立独立模块，再逐步加入工程。

## 6. Qt Viewer 目录建议

```text
tools/viewer/
  OpenFPGAViewer/
    CMakeLists.txt
    src/
      main.cpp
      MainWindow.cpp
      MainWindow.h
      SerialPortManager.cpp
      SerialPortManager.h
      DebugProtocolParser.cpp
      DebugProtocolParser.h
      DebugMessage.h
      LogModel.cpp
      LogModel.h
      WatchModel.cpp
      WatchModel.h
      EventModel.cpp
      EventModel.h
```

建议技术栈：

- Qt 6。
- CMake。
- Qt SerialPort。
- Model/View 结构展示日志、事件和 watch。

## 7. 里程碑拆分

### M1：协议与工程骨架

目标：

- 固化 Debug Protocol v1。
- 建立 RTL、仿真、Viewer 基础目录。
- 完成 Qt Viewer 空窗口、串口扫描和连接界面。

交付物：

- `doc/OpenFPGA_Debug_Protocol_v1.md`
- RTL 模块空壳和顶层端口定义。
- Qt Viewer 可启动并能列出串口。

验收标准：

- 协议字段、大小端、checksum、消息类型有明确文档。
- Qt Viewer 可以打开和关闭串口。

### M2：UART TX 与协议解析闭环

目标：

- 完成 UART TX。
- 完成 FPGA 端 packetizer。
- 完成 PC 端协议 parser。
- 用测试数据完成 PC 端解包。

交付物：

- UART TX RTL。
- packetizer RTL。
- `DebugProtocolParser` 单元测试或最小测试程序。

验收标准：

- 仿真中 UART 输出字节与预期帧一致。
- Qt Viewer 能解析录制的测试字节流。

### M3：Ring Buffer 与 Debug Core

目标：

- 完成 ring buffer。
- 接入 timestamp。
- 实现 `debug_print`、`event`、`watch` 三类写入接口。

交付物：

- `openfpga_debug_core.v`
- `openfpga_debug_ring_buffer.v`
- `openfpga_debug_timestamp.v`

验收标准：

- 仿真覆盖 buffer 空、半满、满、溢出统计。
- 连续写入多种消息时，UART 输出顺序正确。

### M4：Qt Viewer 基础视图

目标：

- 完成日志、事件、watch 三个主要视图。
- 支持暂停显示、清空、导出。

交付物：

- Viewer 主界面。
- Log/Event/Watch models。
- CSV 或 JSONL 导出。

验收标准：

- 可连接真实或虚拟串口并实时展示数据。
- Watch 同 ID 数据会更新最新值，而不是无限追加。
- 错误帧、drop count、packet count 可见。

### M5：板级集成验证

目标：

- 将 Debug Core 接入当前 xcku5p-ffvb676-2-i Vivado 工程。
- 使用一个简单 demo 产生 heartbeat、event、watch 和 debug print。
- 完成真实板卡 UART 接收验证。

交付物：

- Vivado 工程集成文件。
- Demo 顶层或示例模块。
- 板级验证记录。

验收标准：

- 上电后 Viewer 能稳定收到 heartbeat。
- 触发 FPGA 内部事件后 Viewer 能实时显示。
- 运行 30 分钟无解析失步、无 Viewer 崩溃。

### M6：第一阶段整理发布

目标：

- 清理接口、文档和示例。
- 固化第一阶段版本。

交付物：

- `README.md` 快速开始。
- Debug Core 使用说明。
- Viewer 使用说明。
- Protocol v1 文档。
- v0.1 tag 或 release 包。

验收标准：

- 新工程按文档接入 Debug Core 可以在 30 分钟内跑通 UART Viewer。
- 示例工程、仿真、Viewer 三者版本一致。

## 8. 推荐开发顺序

1. 先写协议文档，避免 RTL 和 Viewer 各自理解不一致。
2. 先做 PC parser，再做 RTL packetizer，因为 PC 端更容易调试。
3. 先打通固定测试帧，再接 UART。
4. 先做单向 FPGA 到 PC，不引入 PC 控制命令。
5. 先使用 `print_id + args`，不要在 FPGA 内做字符串格式化。
6. 先保证丢包可见，再优化不丢包。

## 9. 测试规划

### 9.1 RTL 仿真

覆盖场景：

- 单个 Event 包。
- 连续 Debug Print 包。
- Watch 同 ID 高频更新。
- Ring Buffer 写满。
- UART 忙时继续写入。
- checksum 正确性。
- reset 后状态清零。

建议输出仿真日志：

- 原始 packet bytes。
- UART serialized bytes。
- drop count。
- packet count。

### 9.2 Viewer 测试

覆盖场景：

- 正常帧解析。
- 半帧输入。
- 多帧连续输入。
- 错误 SOF 恢复。
- checksum 错误统计。
- 未知版本或未知 type。
- 大量日志持续刷新。

### 9.3 板级测试

覆盖场景：

- 不同波特率。
- 长时间 heartbeat。
- 高频 Event。
- Watch 值变化。
- FPGA reset 后 Viewer 自动恢复解析。

## 10. 主要风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| UART 带宽不足 | 高频日志丢失 | 第一版记录 drop count，限制 payload，后续支持 USB/PCIe |
| FPGA 字符串格式化复杂 | RTL 面积和开发周期上升 | 使用 print_id + args，由 Viewer 映射文本 |
| 协议失步 | Viewer 显示异常 | SOF + LEN + checksum，parser 支持重同步 |
| Ring Buffer 溢出策略不清晰 | 调试结果误判 | 明确 drop-new 策略并上报 drop count |
| Qt UI 高频刷新卡顿 | 长时间使用体验差 | 接收与 UI 分线程，批量刷新模型 |
| 后续接口扩展困难 | 第二阶段以后重构成本高 | Debug Protocol 与 Transport 分层 |

## 11. 第一阶段完成定义

满足以下条件即可认为第一阶段完成：

- Debug Core 能在 FPGA 内部接收 Event、Watch、Debug Print。
- Debug Core 能为所有消息添加 timestamp。
- Ring Buffer 能缓存消息并统计溢出。
- UART 能持续发送协议帧。
- Qt Viewer 能连接串口、解析协议、展示日志、事件和 watch。
- 至少一个板级 demo 能稳定运行。
- 协议、接入方式、Viewer 使用方式有文档。

## 12. 建议时间安排

按个人项目节奏，建议 8 到 10 周完成第一阶段：

| 周期 | 任务 |
| --- | --- |
| 第 1 周 | 协议文档、目录结构、Qt Viewer 骨架 |
| 第 2 周 | PC 端 parser、串口收发、测试字节流 |
| 第 3 周 | UART TX、packetizer 仿真 |
| 第 4 周 | Ring Buffer、timestamp、status |
| 第 5 周 | Event、Watch、Debug Print RTL 接口 |
| 第 6 周 | Viewer 日志、事件、watch 视图 |
| 第 7 周 | Vivado 工程集成和板级 demo |
| 第 8 周 | 长稳测试、文档、第一版整理 |
| 第 9-10 周 | 预留修复、UI 优化、release 准备 |

## 13. 第一版优先级

P0：

- 协议文档。
- UART TX。
- Packetizer。
- Ring Buffer。
- Timestamp。
- Event、Watch、Debug Print。
- Qt 串口连接。
- Qt 协议解析。
- Log/Event/Watch 基础展示。

P1：

- 导出日志。
- 错误帧统计。
- drop count/status 展示。
- 多波特率支持。
- 板级 demo。

P2：

- Watch 曲线。
- 文本映射配置文件。
- 颜色和等级过滤。
- 长时间性能优化。

## 14. 后续阶段预留点

第一阶段实现时需要为后续能力预留接口：

- `TYPE` 字段保留 Trace、Monitor、Profiler 类型空间。
- `VER` 字段用于协议升级。
- Transport 不直接参与消息语义，便于后续替换成 USB、Ethernet、PCIe。
- Watch ID、Event ID、Print ID 统一命名空间，后续可由配置文件或自动生成工具管理。
- Qt Viewer 的 parser 和 UI 分离，后续 Web Viewer 或 CLI 工具也能复用解析逻辑。

## 15. M1 细化更新

M1 已拆分为独立实施计划，详见：

- `doc/M1_协议与工程骨架实施计划.md`
- `doc/OpenFPGA_Debug_Protocol_v1.md`

M1 上位机策略调整为：

- 先实现 Web Viewer 骨架，用 Web Serial API 快速打通 UART 接收、协议解析和数据展示。
- Qt Viewer 仍作为第一阶段目标保留，但放到 M2/M4 继续推进。
- Web Viewer 和 Qt Viewer 共用同一份 Debug Protocol v1，避免两个上位机协议分叉。

M1 当前新增工程骨架：

```text
rtl/openfpga_debug/
sim/openfpga_debug/
tools/viewer/web/
```

Web Viewer 第一版支持：

- 串口连接和断开。
- 115200、921600、3000000 波特率选择。
- HEARTBEAT、DEBUG_PRINT、EVENT、WATCH、STATUS 解码。
- Log、Event、Watch、Status 基础视图。
- 样例帧注入，便于无硬件时验证解析和 UI。

## 16. M4 细化更新

M4 已拆分为独立实施计划，详见：

- `doc/M4_Viewer_基础视图实施计划.md`

M4 上位机策略延续 M1 的调整：

- 先以 Web Viewer 完成基础视图验收，确保 M3 Debug Core 的真实输出可以被观察、暂停、清空和导出。
- Qt Viewer 仍作为第一阶段目标保留，后续实现时复用 M4 中固化的模型语义。

Web Viewer M4 当前新增支持：

- Pause/Resume：暂停显示但继续接收和解析串口数据。
- Export CSV：导出 Log 表。
- Export JSONL：导出 Log、Event、Watch、Status 和 parser counters 快照。
- `drop_count` 非零时在 Status 视图高亮。

## 17. M5 细化更新

M5 已拆分为独立实施计划，详见：

- `doc/M5_板级集成验证实施计划.md`

M5 当前新增工程内容：

- `rtl/board/openfpga_debug_board_demo.v`：板级 demo 顶层，周期性产生 heartbeat、event、watch、debug print 和 status。
- `sim/board/tb_openfpga_debug_board_demo.v`：板级 demo UART 输出验收仿真。
- `prj/scripts/integrate_openfpga_debug_m5.tcl`：将 Debug Core 与 board demo 接入当前 Vivado 工程。
- `prj/constraints/openfpga_debug_board_demo.xdc`：xcku5p-ffvb676-2-i 板级约束。

M5 对 Debug Core 的协议能力补充：

- `openfpga_debug_core.v` 和 `openfpga_debug_top.v` 新增 `heartbeat_valid` 与 `status_valid` 输入。
- `HEARTBEAT` payload 为 `u32 timestamp`。
- `STATUS` payload 为 `u32 timestamp + u16 buffer_used + u16 drop_count + u16 packet_count`。

当前 XDC 已根据厂家 `pin.xdc` 固化 KU5P 板级管脚：100 MHz 差分时钟 `J23/J24`，reset/key/UART/LED 均使用厂家给定的 `LVCMOS18` 管脚约束。

## 18. M6 细化更新

M6 已拆分为独立实施计划，详见：

- `doc/M6_第一阶段整理发布实施计划.md`

M6 当前新增整理内容：

- `README.md`：快速开始、仿真、板级串口验证入口。
- `doc/OpenFPGA_Debug_Core_使用说明.md`：Debug Core RTL 接入说明。
- `doc/OpenFPGA_Web_Viewer_使用说明.md`：Web Viewer 使用说明。
- `doc/OpenFPGA_Studio_板级验证记录.md`：KU5P 板级管脚和 COM6 短时验证记录。
- `tools/viewer/serial_validate.ps1`：命令行串口协议验收脚本。

第一阶段当前状态：

- Debug Core、UART、协议、Web Viewer 和 KU5P 板级 demo 已打通。
- 2026-06-29 使用 `COM6 @ 115200 8N1` 完成 30 秒实测，五类消息均稳定输出，`checksum_errors=0`，`drop_count=0`。
- Qt Viewer 仍作为后续目标保留；当前第一阶段以 Web Viewer 作为可验收上位机。
- 发布前仍建议补一次 30 分钟长稳记录，并根据需要创建 v0.1 tag/release 包。
