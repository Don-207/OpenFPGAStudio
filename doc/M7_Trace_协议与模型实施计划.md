# M7 Trace 协议与模型实施计划

## 1. 目标

M7 是第二阶段 OpenFPGA Trace 的第一个里程碑，目标是先固化 Trace 协议和上位机数据模型，让后续 Viewer 时间轴、RTL Trace Adapter 和典型 probe 可以并行开发：

- 固化 `0x10..0x14` Trace 消息类型和 payload 布局。
- 保持 Debug Protocol v1 帧格式、字节序、checksum 和 parser 行为不变。
- Web Viewer parser 能识别 Trace 帧，不再把 Trace 类型计为 unknown。
- Viewer 内部建立 `span/mark/value/drop` 四类 Trace 数据模型。
- 增加 Trace parser 回归测试向量，覆盖正常配对和异常孤立区间。

M7 只处理协议与模型，不实现完整时间轴 UI。Trace 视图入口、筛选、详情面板和图形化展示留给 M8。

## 2. 协议变更

### 2.1 `doc/OpenFPGA_Debug_Protocol_v1.md`

消息类型表新增：

| Type | 名称 | 说明 |
| --- | --- | --- |
| `0x10` | `TRACE_SPAN_BEGIN` | Trace 区间开始 |
| `0x11` | `TRACE_SPAN_END` | Trace 区间结束 |
| `0x12` | `TRACE_MARK` | Trace 瞬时事件标记 |
| `0x13` | `TRACE_VALUE` | Trace 低频数值采样 |
| `0x14` | `TRACE_DROP` | Trace 丢弃或限流提示 |

`0x15..0x1F` 继续作为 Trace 保留空间。

### 2.2 Payload 布局

`TRACE_SPAN_BEGIN`：

```text
u32 timestamp
u16 trace_id
u16 instance_id
u32 arg0
```

长度：12 字节。

`TRACE_SPAN_END`：

```text
u32 timestamp
u16 trace_id
u16 instance_id
u8  status
u32 arg0
```

长度：13 字节。

`status` 建议值：

| Status | 名称 | 说明 |
| --- | --- | --- |
| `0` | `OK` | 正常结束 |
| `1` | `WARN` | 结束但存在告警 |
| `2` | `ERROR` | 异常结束 |
| `3` | `TIMEOUT` | 超时 |

`TRACE_MARK`：

```text
u32 timestamp
u16 trace_id
u8  level
u32 arg0
```

长度：11 字节。`level` 复用 EVENT 的 Debug/Info/Warning/Error 建议值。

`TRACE_VALUE`：

```text
u32 timestamp
u16 trace_id
u16 value_id
u32 value
```

长度：12 字节。

`TRACE_DROP`：

```text
u32 timestamp
u16 trace_id
u32 drop_count
```

长度：10 字节。`trace_id = 0` 表示全局 Trace 丢弃统计。

## 3. Viewer 模型变更

### 3.1 `tools/viewer/web/app.js`

M7 新增 Trace 类型常量：

```javascript
0x10: "TRACE_SPAN_BEGIN"
0x11: "TRACE_SPAN_END"
0x12: "TRACE_MARK"
0x13: "TRACE_VALUE"
0x14: "TRACE_DROP"
```

新增内部状态：

```text
state.trace.spans
state.trace.openSpans
state.trace.marks
state.trace.values
state.trace.latestValues
state.trace.drops
```

Parser 行为：

- `TRACE_SPAN_BEGIN` 按 `trace_id + instance_id` 写入 `openSpans`。
- `TRACE_SPAN_END` 匹配 open span 并生成完整 span，记录开始时间、结束时间、持续时间、状态和参数。
- 无法匹配 begin 的 end 保留为 orphan span，供 M8 详情视图提示异常。
- `TRACE_MARK` 写入 `marks`。
- `TRACE_VALUE` 写入 `values`，并按 `trace_id/value_id` 更新 `latestValues`。
- `TRACE_DROP` 写入 `drops`。
- `Inject Sample` 增加一组最小 Trace 样例帧。
- JSONL 导出新增：
  - `trace_span`
  - `trace_open_span`
  - `trace_mark`
  - `trace_value`
  - `trace_drop`

当前 Log 表会显示 Trace 帧的基础记录，完整时间轴 UI 留给 M8。

## 4. 测试变更

### 4.1 `tools/viewer/protocol_parser_test.py`

M7 回归测试新增 Trace 类型和最小模型解码，覆盖：

- `TRACE_SPAN_BEGIN` 是已知类型。
- `TRACE_SPAN_END` 是已知类型。
- begin/end 能按 `trace_id + instance_id` 配对。
- span duration 能由 end timestamp 减 begin timestamp 得到。
- span status 能保留。
- `TRACE_MARK` 能解析 `level` 和 `arg0`。
- `TRACE_VALUE` 能解析 `trace_id/value_id/value`。
- `TRACE_DROP` 能解析 `drop_count`。
- unmatched `TRACE_SPAN_END` 保留为 orphan span。

## 5. 验收命令

协议 parser 回归测试：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望结果：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

如果安装了 Node.js，可额外做 JavaScript 语法检查：

```powershell
node --check tools\viewer\web\app.js
```

## 6. 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample`：

- Log 中应出现 `TRACE_SPAN_BEGIN`、`TRACE_MARK`、`TRACE_VALUE`、`TRACE_SPAN_END`。
- parser counters 中 `Unknown` 不应因 Trace 帧增加。
- `Export JSONL` 下载结果中应包含 `trace_span`、`trace_mark` 和 `trace_value` 记录。

M7 不要求页面出现独立 Trace 时间轴；该能力由 M8 验收。

## 7. 留给 M8/M9 的事项

- M8 增加 Trace 视图入口、时间轴 lane、筛选、详情面板和 JSONL 交互验证。
- M8 的 `Inject Sample` 应扩展到 Frame、DMA、FIFO、Interrupt 四类典型场景。
- M9 RTL Trace Adapter 按本文件和 Debug Protocol v1 的 payload 布局封装 Trace 帧。
- M9/M10 需要在 RTL testbench 中覆盖 begin/end 配对、timeout/error status、FIFO mark/value 和 drop 行为。

