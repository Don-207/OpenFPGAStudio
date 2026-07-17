# OpenFPGA Studio 第二阶段 Trace 实施计划

## 1. 阶段目标

根据 `YiFPGA_Studio_发展规划.docx` 中的第二阶段目标，第二阶段定位为 `OpenFPGA Trace`：

- 模块时间轴可视化。
- DMA、Frame、FIFO、Interrupt 过程可视化。
- 在第一阶段 Debug Core、Debug Protocol v1 和 Web Viewer 的基础上扩展，不推翻现有 Event/Watch/Status 能力。

第二阶段的核心交付不是做完整性能分析器，而是先把 FPGA 内部“什么时候开始、什么时候结束、哪里发生阻塞或异常”呈现为可读时间线，为后续 Monitor、Profiler 和 AI Debug 打基础。

## 2. 阶段边界

必须完成：

- 定义 Trace 协议扩展，使用 `0x10..0x1F` 保留类型空间。
- RTL 侧提供轻量 Trace API，用于上报模块区间、瞬时标记和关键计数。
- Web Viewer 增加 Trace 时间轴视图，支持按模块、类型和时间范围查看。
- 提供 DMA、Frame、FIFO、Interrupt 四类典型场景的 demo 或样例帧。
- 增加 parser 回归测试和 Trace 样例导出能力。

暂不完成：

- 在线寄存器读写和变量修改，此项属于第三阶段 Monitor。
- DDR、PCIe、AXI 的吞吐率和延迟统计，此项属于第四阶段 Profiler。
- 替代厂商 ILA 的波形级采样，此项属于第五阶段 Open Logic Analyzer。
- AI 自动诊断，此项属于第六阶段 AI Debug。

## 3. 总体架构

```text
FPGA User Logic
    |
    | trace_begin / trace_end / trace_mark / trace_value
    v
OpenFPGA Trace Adapter
    |
    | TRACE_* payload
    v
OpenFPGA Debug Core
    |
    | OpenFPGA Debug Protocol v1 frames
    v
UART Transport
    |
    | serial stream
    v
Web Viewer Trace View
    |
    | timeline / lanes / filters / export
    v
Developer
```

模块边界：

- `Trace Adapter`：把用户逻辑中的模块状态、帧边界、中断和 FIFO 状态转换成 Trace 消息。
- `Debug Core`：继续负责 timestamp、packetizer、ring buffer 和 UART TX，不感知具体业务语义。
- `Viewer Trace Model`：把 begin/end/mark/value 消息合成为时间轴对象。
- `Trace View`：提供时间线、泳道、详情面板、过滤和导出。

## 4. 协议扩展建议

沿用 Debug Protocol v1 帧格式，新增 Trace 消息类型：

| Type | 名称 | 说明 |
| --- | --- | --- |
| `0x10` | `TRACE_SPAN_BEGIN` | 模块或事务开始 |
| `0x11` | `TRACE_SPAN_END` | 模块或事务结束 |
| `0x12` | `TRACE_MARK` | 瞬时事件标记 |
| `0x13` | `TRACE_VALUE` | Trace 相关数值采样 |
| `0x14` | `TRACE_DROP` | Trace 侧丢弃或限流提示 |

### 4.1 TRACE_SPAN_BEGIN

```text
u32 timestamp
u16 trace_id
u16 instance_id
u32 arg0
```

说明：

- `trace_id` 表示模块或事务类型，例如 DMA、Frame、FIFO、Interrupt。
- `instance_id` 表示同类事务实例，便于匹配 begin/end。
- `arg0` 可存放 frame_id、dma_desc_id、fifo_level 或业务状态。

### 4.2 TRACE_SPAN_END

```text
u32 timestamp
u16 trace_id
u16 instance_id
u8  status
u32 arg0
```

`status` 建议值：

| Status | 名称 | 说明 |
| --- | --- | --- |
| `0` | `OK` | 正常结束 |
| `1` | `WARN` | 结束但存在告警 |
| `2` | `ERROR` | 异常结束 |
| `3` | `TIMEOUT` | 超时 |

### 4.3 TRACE_MARK

```text
u32 timestamp
u16 trace_id
u8  level
u32 arg0
```

用于记录 IRQ 触发、FIFO almost_full、DMA descriptor done、frame sync 等瞬时事件。

### 4.4 TRACE_VALUE

```text
u32 timestamp
u16 trace_id
u16 value_id
u32 value
```

用于记录 FIFO level、pending descriptor 数量、frame counter 等低频采样值。

## 5. RTL 实施计划

### 5.1 新增模块

建议新增：

```text
rtl/openfpga_debug/
  openfpga_trace_pkg.vh
  openfpga_trace_adapter.v
  openfpga_trace_dma_probe.v
  openfpga_trace_frame_probe.v
  openfpga_trace_fifo_probe.v
  openfpga_trace_irq_probe.v
```

职责：

- `openfpga_trace_pkg.vh`：定义 Trace type、status、level 和常用 trace_id。
- `openfpga_trace_adapter.v`：提供统一输入接口，并封装为 Debug Protocol payload。
- `openfpga_trace_dma_probe.v`：把 DMA start/done/error 转成 span 和 mark。
- `openfpga_trace_frame_probe.v`：把 frame start/end/drop 转成 span 和 mark。
- `openfpga_trace_fifo_probe.v`：把 FIFO level、almost_full、overflow 转成 value 和 mark。
- `openfpga_trace_irq_probe.v`：把 interrupt assert/clear 转成 mark 或短 span。

### 5.2 资源与限流策略

- Trace 默认采用事件驱动，不做连续波形采样。
- 每类 probe 增加 `ENABLE` 参数，便于综合时裁剪。
- `TRACE_VALUE` 默认低频采样，避免 UART 带宽被 FIFO level 等高频数据占满。
- 当 Trace 事件超过 ring buffer 能力时，上报 `TRACE_DROP` 或复用现有 `STATUS.drop_count` 观察。

### 5.3 仿真要求

新增仿真建议：

```text
sim/openfpga_debug/
  tb_openfpga_trace_adapter.v
  tb_openfpga_trace_dma_probe.v
  tb_openfpga_trace_fifo_probe.v
```

验收点：

- begin/end 能按 `trace_id + instance_id` 匹配。
- timeout/error status 能正确编码。
- FIFO overflow、almost_full 能产生 `TRACE_MARK`。
- packetizer 对 `0x10..0x14` 类型保持兼容。

## 6. Viewer 实施计划

### 6.1 数据模型

在 `tools/viewer/web/app.js` 中新增 Trace 状态：

```text
state.trace = {
  spans: [],
  openSpans: {},
  marks: [],
  values: [],
  drops: []
}
```

模型行为：

- 收到 `TRACE_SPAN_BEGIN` 时记录 open span。
- 收到 `TRACE_SPAN_END` 时匹配 open span，并生成完整 span。
- 收到无法匹配的 end 时保留为 orphan span，并在详情中标记。
- `TRACE_MARK` 追加到 marks。
- `TRACE_VALUE` 按 `trace_id/value_id` 记录曲线或最新值。

### 6.2 视图能力

Web Viewer 新增 `Trace` 视图：

- 时间轴主视图：按 `trace_id` 分泳道显示 span 和 mark。
- 详情面板：显示选中 span 的开始时间、结束时间、持续时间、status、arg0。
- 过滤控件：按 DMA、Frame、FIFO、Interrupt、Error/Timeout 过滤。
- 概览统计：显示 span 数量、平均持续时间、最大持续时间、异常数量。
- 导出能力：JSONL 导出增加 `trace_span`、`trace_mark`、`trace_value`、`trace_drop`。

第一版时间轴可以用 DOM/CSS 实现，不必引入复杂图表库。若长时间数据量过大，再加入虚拟列表或 canvas 渲染。

### 6.3 样例帧

`Inject Sample` 增加 Trace 场景：

- Frame 进入、DMA 开始、FIFO level 变化、IRQ assert、DMA 结束、Frame 结束。
- 插入一个 FIFO almost_full mark。
- 插入一个 DMA timeout span，验证异常高亮。

## 7. 里程碑拆分

### M7：Trace 协议与模型

目标：

- 固化 Trace 消息类型和 payload。
- 更新协议文档中的 `0x10..0x1F` Trace 定义。
- Web Viewer parser 能解析 Trace 消息。
- 增加 Trace parser 测试向量。

交付物：

- `doc/YiFPGA_Debug_Protocol_v1.md` Trace 扩展章节。
- `tools/viewer/protocol_parser_test.py` Trace 测试。
- `tools/viewer/web/app.js` Trace parser 和 state model。

### M8：Trace Viewer 时间轴

目标：

- 增加 Trace 视图入口。
- 实现 span、mark、value 的基础显示。
- 支持过滤、详情和 JSONL 导出。
- `Inject Sample` 覆盖 DMA/Frame/FIFO/Interrupt。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/YiFPGA_Web_Viewer_使用说明.md` Trace 章节。

### M9：RTL Trace Adapter

目标：

- 新增 Trace Adapter 和基础 API。
- 完成 begin/end/mark/value payload 封装。
- 接入现有 Debug Core packetizer。
- 增加 Trace Adapter 仿真。

交付物：

- `rtl/openfpga_debug/openfpga_trace_pkg.vh`
- `rtl/openfpga_debug/openfpga_trace_adapter.v`
- `sim/openfpga_debug/tb_openfpga_trace_adapter.v`

### M10：典型 Probe 与 Demo

目标：

- 增加 DMA、Frame、FIFO、IRQ probe。
- 在板级 demo 或仿真 demo 中产生可观察 Trace。
- Web Viewer 能展示完整 frame -> dma -> irq -> fifo 过程。

交付物：

- `openfpga_trace_dma_probe.v`
- `openfpga_trace_frame_probe.v`
- `openfpga_trace_fifo_probe.v`
- `openfpga_trace_irq_probe.v`
- 更新板级 demo 或新增 Trace demo。

### M11：第二阶段整理与发布

目标：

- 补齐使用说明和验收记录。
- 完成无硬件样例、仿真、板级三类验收。
- 明确第二阶段与第三阶段 Monitor 的边界。

交付物：

- `doc/YiFPGA_Trace_使用说明.md`
- `doc/YiFPGA_Studio_第二阶段Trace验证记录.md`
- `doc/YiFPGA_Studio_第二阶段Trace发布Checklist.md`
- `doc/M11_第二阶段整理与发布实施计划.md`

## 8. 验收场景

### 8.1 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample`：

- Trace 视图出现 Frame、DMA、FIFO、Interrupt 泳道。
- DMA span 能显示持续时间。
- FIFO almost_full mark 能显示在正确 timestamp 附近。
- DMA timeout 或 error span 被高亮。
- JSONL 导出包含 Trace 数据。

### 8.2 仿真验收

运行 Trace 相关 testbench：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望结果：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

后续若补齐 RTL 仿真脚本，增加：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl
```

### 8.3 板级验收

使用 Chrome 或 Edge 打开 Web Viewer：

1. 连接 FPGA Debug Core 串口。
2. 运行 Trace demo bitstream。
3. 确认 Frame、DMA、FIFO、Interrupt 事件随板级行为实时变化。
4. 故意制造 FIFO 压力或 DMA timeout 场景，确认异常 mark/span 可见。
5. 连续运行 30 分钟，确认 parser checksum error 不持续增长，`drop_count` 可解释。

## 9. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| UART 带宽不足 | Trace 事件丢失或 Viewer 延迟 | 默认低频采样，probe 可配置，保留 drop 统计 |
| begin/end 不匹配 | 时间轴出现孤立记录 | Viewer 保留 orphan span 并提示，RTL testbench 覆盖异常路径 |
| Trace 语义过早绑定业务 | 后续跨项目复用困难 | 协议只定义通用 span/mark/value，业务文本由 Viewer 映射 |
| DOM 时间轴性能不足 | 长时间运行卡顿 | 第一版限制显示窗口，后续改 canvas 或虚拟列表 |
| 与 Profiler 边界混淆 | 第二阶段范围膨胀 | 第二阶段只展示过程和状态，不做复杂吞吐/延迟统计 |

## 10. 推荐优先级

建议先做 M7 和 M8，让 Viewer 先能解析和展示 Trace 样例；再做 M9/M10 的 RTL 接入。这样即使板级 Trace 尚未完成，也能提前固定协议和交互形态，降低 RTL 与上位机并行开发的摩擦。
