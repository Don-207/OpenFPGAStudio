# OpenFPGA Studio 第二阶段 Trace 验证记录

## 1. 验证范围

本记录覆盖第二阶段 Trace 的 M7-M11 验收：

- Trace 协议消息 `0x10..0x14`。
- Web Viewer Trace parser、state model、时间线、过滤、详情和 JSONL 导出。
- RTL `openfpga_trace_adapter`。
- DMA、Frame、FIFO、IRQ 典型 probe。
- `openfpga_debug_board_demo` Trace 场景。
- 发布文档和验收流程。

## 2. 当前实现状态

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 协议文档 | 已完成 | `OpenFPGA_Debug_Protocol_v1.md` 定义 Trace payload |
| PC parser 回归 | 已完成 | `protocol_parser_test.py` 覆盖 begin/end/mark/value/drop 和 orphan end |
| Web Viewer Trace | 已完成 | Trace 视图、样例注入、过滤、详情、JSONL 导出、性能冒烟脚本 |
| RTL Adapter | 已完成 | payload 编码、优先级、背压、drop 计数 |
| 典型 Probe | 已完成 | DMA、Frame、FIFO、IRQ probe |
| 板级 Demo | 已完成 | 周期性 Trace 场景，包含 DMA timeout |
| 发布文档 | 已完成 | Trace 使用说明、验证记录、发布 checklist |

## 3. 无硬件验收

### 3.1 PC parser

命令：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

覆盖点：

- 分片输入后再完成解析。
- checksum 错误计数。
- SOF 重同步。
- unknown type 计数。
- Trace begin/end 合成 span。
- Trace mark/value/drop 解码。
- 未匹配 end 保留为 orphan span。

### 3.2 Web Viewer 样例

动作：

1. 打开 `tools/viewer/web/index.html`。
2. 点击 `Inject Sample`。
3. 切换到 `Trace` 视图。
4. 导出 JSONL。

期望：

- 出现 Frame、DMA、FIFO、Interrupt 泳道。
- DMA span 有 duration。
- FIFO almost_full mark 可见。
- DMA timeout span 被 problem 样式高亮。
- Latest Values 显示 FIFO level。
- JSONL 包含 `trace_span`、`trace_mark`、`trace_value`、`trace_drop`。

### 3.3 Web Viewer 性能冒烟

命令：

```powershell
python tools\viewer\web\run_perf_test.py
```

期望：

- `checksumErrors = 0`
- `syncDrops = 0`
- `unknownFrames = 0`
- 输出中包含 span、mark、value 数量和渲染摘要。

## 4. RTL 仿真验收

### 4.1 M9 Trace Adapter

命令：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_trace_adapter.v sim\openfpga_debug\tb_openfpga_trace_adapter.v
xelab tb_openfpga_trace_adapter -s tb_openfpga_trace_adapter_sim
xsim tb_openfpga_trace_adapter_sim -runall
```

期望：

```text
PASS: OpenFPGA Trace Adapter payload and handshake checks passed
```

覆盖点：

- `TRACE_SPAN_BEGIN`、`TRACE_SPAN_END`、`TRACE_MARK`、`TRACE_VALUE`、`TRACE_DROP` payload 长度和字段。
- 输入优先级。
- `trace_ready`、`trace_accepted`、`trace_dropped` 握手。

### 4.2 M10 Board Demo

命令：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_trace_adapter.v rtl\openfpga_debug\openfpga_trace_dma_probe.v rtl\openfpga_debug\openfpga_trace_frame_probe.v rtl\openfpga_debug\openfpga_trace_fifo_probe.v rtl\openfpga_debug\openfpga_trace_irq_probe.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_demo.v
xelab tb_openfpga_debug_board_demo -s tb_openfpga_debug_board_demo_m10_sim
xsim tb_openfpga_debug_board_demo_m10_sim -runall
```

期望：

```text
PASS: OpenFPGA Debug board demo emitted debug and trace frames
```

覆盖点：

- 原有 HEARTBEAT、DEBUG_PRINT、EVENT、WATCH、STATUS 帧仍输出。
- Trace span begin/end、mark、value 帧输出。
- payload 长度符合协议。

## 5. Vivado Elaboration

命令：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl
```

期望：

```text
PASS: OpenFPGA Trace M10 probe and demo Vivado RTL elaboration completed
```

说明：

- 该检查不生成 bitstream，只做 RTL elaboration，适合发布前快速确认文件列表、端口连接和基本语法。
- 器件当前为 `xcku5p-ffvb676-2-i`，与现有 Vivado 工程一致。

## 6. 板级验收

板级 demo 默认：

- 顶层：`openfpga_debug_board_demo`
- 约束：`prj/constraints/openfpga_debug_board_demo.xdc`
- 串口：`115200 8N1`
- Viewer：Chrome 或 Edge 打开 `tools/viewer/web/index.html`

验收步骤：

1. 生成并下载 bitstream。
2. 连接 UART TX 到 PC RX，并确认共地。
3. Web Viewer 连接串口。
4. 确认 Log/Watch/Events/Status 仍持续更新。
5. 切换 Trace 视图，确认 Frame、DMA、FIFO、Interrupt 泳道持续出现。
6. 观察 DMA timeout 是否周期性高亮。
7. 运行 30 分钟，记录 checksum error、drop_count 和异常现象。

命令行长稳可选：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM6 -Baud 115200 -DurationSec 1800
```

## 7. 本轮记录

| 日期 | 项目 | 结果 | 备注 |
| --- | --- | --- | --- |
| 2026-06-30 | M11 文档整理 | PASS | 新增 Trace 使用说明、验证记录、发布 checklist |
| 2026-06-30 | PC parser 回归 | PASS | `PASS: OpenFPGA Debug Protocol parser test vectors passed` |
| 2026-06-30 | Web Viewer 性能冒烟 | PASS | 11180 frames，checksum/sync/unknown 均为 0，Trace nodes 1200 |
| 2026-06-30 | M9 Trace Adapter 仿真 | PASS | `PASS: OpenFPGA Trace Adapter payload and handshake checks passed` |
| 2026-06-30 | M10 Board Demo 仿真 | PASS | `PASS: OpenFPGA Debug board demo emitted debug and trace frames` |
| 2026-06-30 | Vivado elaboration | PASS | `PASS: OpenFPGA Trace M10 probe and demo Vivado RTL elaboration completed`；Vivado 启动时报告 Tcl store 写权限 warning，不影响 RTL elaboration |
| 2026-06-30 | 板级长稳 | 待硬件复测 | 需记录 COM 口、bitstream 日期和运行时长 |

## 8. 已知限制

- UART 单向链路，第二阶段不支持 PC 到 FPGA 控制。
- checksum 仍为 XOR，不是 CRC。
- timestamp 为 32 bit tick，长时间运行会回绕。
- Trace 是事件级观测，不是波形采样。
- 高密度 Trace 会受 UART 带宽和 ring buffer 深度限制，需要通过节流和 drop 统计解释。

## 9. WP3复核记录（2026-07-16）

- Parser与Viewer压力回归PASS：11,192 frames、2,400 spans、2,400 marks、800 values，checksum/sync/unknown均为0。
- M9 Adapter当前源码XSim PASS。
- M10 Board Demo首次复跑FAIL：Trace begin/end/mark/value均未在测试窗口出现。
- 根因是Monitor接入后`openfpga_debug_top`固定使用`CLK_FREQ_HZ/10`初始化`DEMO_PERIOD`，覆盖Board Demo的`EVENT_INTERVAL_TICKS`仿真参数。
- 修复为新增`MONITOR_DEFAULT_DEMO_PERIOD`参数并由Board Demo传入`EVENT_INTERVAL_TICKS`；真实板默认值仍为10,000,000 ticks，功能配置不变。
- 修复后M10 XSim PASS：Debug与Trace帧共存。
- 原M10 elaboration脚本因后续阶段新增Profiler/LA/JTAG后文件清单陈旧而FAIL；更新为读取当前完整RTL/vendor依赖后PASS，84 infos、13 warnings、0 critical warnings、0 errors。
- 执行`just m36-ila-bitstream`重新生成当前WP3候选镜像PASS：Vivado 2024.2，器件`xcku5p-ffvb676-2-i`，单个USER2 BSCANE2和单个ILA均通过构建断言。
- 实现结果：WNS `+3.298 ns`、TNS `0`、WHS `+0.017 ns`、THS `0`，11,305个可布线网络全部完成；DRC为0 error、4个来自`dbg_hub`生成IP的warning，CDC为4个`dbg_hub`生成IP CDC-15 warning，无用户RTL新增CDC warning。
- 产物：bitstream 15,431,260 bytes，SHA-256 `b30d7cdd1b6e61d2744d13b0e6d460b8c37dd4437a31be3d557c85bd5c6811c0`；LTX 13,686 bytes，SHA-256 `019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
- 执行`just m36-program 'Digilent/210512180081'`下载PASS：精确匹配唯一Digilent目标，器件`xcku5p_0`，End of startup status为HIGH，刷新后枚举1个ILA；普通M36镜像JTAG build ID为`0x4D360001`。
- 下载后UART 10秒基线PASS：1,664帧，Trace begin/end/mark/value均持续出现，checksum/version/sync error均为0。
- 扩展`validate_uart_board.py`输出Trace ID、span end状态和STATUS中的drop计数；15秒板级采样PASS：2,493帧，Trace ID `0x0001..0x0004`全部出现，DMA timeout（status 3）15次，750个STATUS帧的`drop_count`首值/末值/最大值均为0。
- 数据侧已证明四类泳道输入和DMA timeout输入。
- Windows Chrome板级截图确认91个span、93个mark、31个value，Frame/DMA/FIFO/Interrupt四泳道均可见，DMA timeout为红色problem高亮。
- 截图发现`Avg Duration`为负数；根因是span跨32位timestamp回绕时使用普通减法。Viewer与Python参考Parser均改为无符号32位差值，并新增`0xFFFFFFF0 -> 0x00000020`用例，期望duration为48 ticks。
- 修复后Parser回归PASS；Viewer压力门禁PASS：11,194帧、2,401 spans、回绕duration 48、checksum/sync/unknown均为0。
- 当前仅需补录本次Windows Chrome精确版本号。
