# M8 Trace Viewer 时间轴实施计划

## 1. 目标

M8 承接 M7 已完成的 Trace 协议解析和数据模型，在 Web Viewer 中提供可直接验收的 Trace 时间轴：

- 增加 Trace 视图入口。
- 按 `trace_id` 分泳道显示 span、mark、drop。
- 显示 `TRACE_VALUE` 的最新值。
- 支持按泳道、status/problem 和 timestamp 范围过滤。
- 支持点击时间轴元素查看详情。
- JSONL 导出继续包含 Trace 数据。
- `Inject Sample` 覆盖 DMA、Frame、FIFO、Interrupt 典型场景。

M8 不引入复杂图表库，第一版使用 DOM/CSS 实现，便于保持单文件 viewer 的部署方式。

## 2. 交付文件

| 文件 | 内容 |
| --- | --- |
| `tools/viewer/web/index.html` | 增加 Trace 面板、过滤器、统计区、时间轴容器、详情面板和 Latest Values 表格 |
| `tools/viewer/web/app.js` | 实现 Trace 渲染、过滤、选择详情、统计计算和 sample 注入 |
| `tools/viewer/web/styles.css` | 增加 Trace 时间轴、泳道、span、mark、drop、异常状态和响应式样式 |
| `doc/OpenFPGA_Web_Viewer_使用说明.md` | 增加 Trace 视图使用说明 |

## 3. Trace 视图设计

### 3.1 泳道

时间轴按 `trace_id` 分泳道显示。Viewer 内置常用名称：

| trace_id | 名称 |
| --- | --- |
| `0x0001` | DMA |
| `0x0002` | Frame |
| `0x0003` | FIFO |
| `0x0004` | Interrupt |

未知 `trace_id` 使用十六进制显示。

### 3.2 元素

- 完成 span：使用横条显示，宽度由 `endTimestamp - startTimestamp` 决定。
- open span：使用灰色横条显示，表示只收到 begin 尚未收到 end。
- orphan span：使用异常色显示，表示收到 end 但没有匹配 begin。
- mark：使用竖向标记显示，warning/error 级别高亮。
- drop：作为 problem 标记显示。
- value：不进入时间轴第一版曲线，显示在 Latest Values 表格中。

### 3.3 过滤

过滤器包括：

- Lane：全部或指定 `trace_id`。
- Status：全部、problem、OK、WARN、ERROR、TIMEOUT。
- From/To：timestamp 范围。

problem 包含 WARN、ERROR、TIMEOUT、orphan span 和 drop。

### 3.4 详情

点击 span/mark/drop 后在详情面板显示：

- span：trace、instance、start、end、duration、status、arg0、orphan。
- mark：trace、timestamp、level、arg0。
- drop：trace、timestamp、drop_count。

## 4. Inject Sample

`Inject Sample` 覆盖以下场景：

- Frame span 开始和正常结束。
- DMA span 开始和正常结束。
- FIFO almost_full mark。
- FIFO level value。
- Interrupt mark。
- DMA timeout span。
- Trace drop。

该 sample 用于无硬件验收 Trace 面板、异常高亮、详情面板、过滤器和 JSONL 导出。

## 5. 验收

### 5.1 无硬件验收

打开 `tools/viewer/web/index.html`，点击 `Inject Sample`：

- Trace 面板出现 DMA、Frame、FIFO、Interrupt 泳道。
- Frame 和 DMA 正常 span 可见。
- FIFO almost_full mark 可见。
- Latest Values 显示 FIFO value。
- DMA timeout span 被高亮为 problem。
- Trace drop 在 problem 过滤下可见。
- 点击 span/mark/drop 后详情面板显示对应字段。
- `Export JSONL` 包含 `trace_span`、`trace_mark`、`trace_value`、`trace_drop`。

### 5.2 回归

运行：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

## 6. 风险与后续

| 风险 | 对策 |
| --- | --- |
| 长时间运行后 DOM 元素过多 | M8 保持第一版实现，后续可引入 canvas 或虚拟列表 |
| `TRACE_VALUE` 数据量较大 | M8 只显示最新值，完整历史仍可通过 JSONL 导出 |
| begin/end 不匹配 | 保留 orphan span 并在详情中标记 |
| 与 Profiler 边界混淆 | M8 只展示过程和状态，不做吞吐率、延迟分布等复杂性能分析 |
