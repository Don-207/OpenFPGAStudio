# M22 Logic Analyzer 协议与捕获模型实施计划

M22 是第五阶段 Open Logic Analyzer 的起点，目标是先把 FPGA 与 Web Viewer 对波形捕获数据的字节级理解固定下来。M22 不实现 RTL Logic Analyzer Core，也不做完整波形 UI；这些分别放到 M23 和 M24。

## 1. 目标

- 固化 Debug Protocol v1 中 `0x40..0x4F` Logic Analyzer 类型空间。
- 定义 `LA_CAPTURE_HEADER`、`LA_SAMPLE_DATA`、`LA_CAPTURE_STATUS` 和 `LA_TRIGGER_EVENT` payload。
- 定义 capture model，包括 `capture_id`、sample width、sample count、trigger index、chunk index、缺片和 malformed 统计。
- 在 Web Viewer 中加入 LA parser、capture model 和无硬件测试钩子。
- 增加 parser 回归测试，覆盖合法捕获、分片、缺片、乱序提示和错误长度。

## 2. 协议范围

M22 正式启用：

| Type | 方向 | 名称 | M22 状态 |
| --- | --- | --- | --- |
| `0x40` | FPGA -> PC | `LA_CAPTURE_HEADER` | 定义并解析 |
| `0x41` | FPGA -> PC | `LA_SAMPLE_DATA` | 定义并解析 |
| `0x42` | FPGA -> PC | `LA_CAPTURE_STATUS` | 定义并解析 |
| `0x43` | FPGA -> PC | `LA_TRIGGER_EVENT` | 定义并解析 |

M22 预留：

| Type | 名称 | 后续里程碑 |
| --- | --- | --- |
| `0x44` | `LA_CHANNEL_MANIFEST` | M24/M25 可选，P0 可使用静态 manifest |
| `0x45` | `LA_CFG_REQ` | P1，P0 通过 Monitor 配置 |
| `0x46` | `LA_CFG_RESP` | P1，P0 通过 Monitor 配置 |
| `0x47..0x4F` | 保留 | 压缩、序列触发、多 core 扩展 |

## 3. Payload

`LA_CAPTURE_HEADER` 固定 24 字节：

```text
u32 capture_id
u32 timestamp
u16 sample_width_bits
u16 sample_count
u16 trigger_index
u16 flags
u32 sample_period_cycles
u16 channel_count
u16 reserved
```

`LA_SAMPLE_DATA` 固定 32 字节：

```text
u32 capture_id
u16 chunk_index
u16 first_sample_index
u8  sample_bytes
u8  sample_count
u16 flags
u8  data[20]
```

`LA_CAPTURE_STATUS` 固定 20 字节：

```text
u32 timestamp
u32 capture_id
u8  state
u8  error
u16 samples_written
u16 chunks_sent
u16 chunks_total
u32 status_flags
```

`LA_TRIGGER_EVENT` 固定 20 字节：

```text
u32 timestamp
u32 capture_id
u16 trigger_index
u16 trigger_channel
u32 sample_value
u32 trigger_value
```

## 4. Capture Model

Viewer 内部建议维护：

```text
state.logicAnalyzer = {
  captures: Map(capture_id -> capture),
  latestCaptureId,
  manifest,
  counters: {
    headers,
    samples,
    statuses,
    triggerEvents,
    malformed,
    missingChunks,
    outOfOrderChunks,
    droppedFrames
  }
}
```

单个 capture 建议包含：

```text
capture = {
  header,
  status,
  triggerEvent,
  chunks: Map(chunk_index -> chunk),
  samples: [],
  missingRanges: [],
  complete,
  errors: []
}
```

P0 约束：

- `sample_width_bits <= 32`。
- `sample_bytes` 只接受 1、2、4。
- 同一 `capture_id` 的 chunk 默认按顺序发送，但 Viewer 必须检查 `chunk_index` 和 `first_sample_index`。
- 缺片、乱序、长度错误不应导致 UI 崩溃，必须进入 counters 和 capture errors。

## 5. Parser 行为

- `LA_CAPTURE_HEADER` 长度不是 24 字节时计入 malformed。
- `LA_SAMPLE_DATA` 长度不是 32 字节时计入 malformed。
- `LA_CAPTURE_STATUS` 长度不是 20 字节时计入 malformed。
- `LA_TRIGGER_EVENT` 长度不是 20 字节时计入 malformed。
- 未见 header 先收到 data 时，Viewer 创建占位 capture 并标记 `missing_header`。
- `sample_count * sample_bytes > 20` 时计入 malformed。
- chunk 覆盖同一 sample 范围时标记 overlap，后到数据不静默覆盖。
- JSONL 导出包含 LA header、sample、status、trigger event 和 parser counters 快照。

## 6. 测试向量

`tools/viewer/protocol_parser_test.py` 增加：

- 解析一次完整 capture，确认 header 字段、trigger index 和 sample 数正确。
- 解析 32 bit sample 的多 chunk 捕获，确认 sample 小端还原正确。
- 注入缺失 chunk，确认 `missingChunks` 增加。
- 注入乱序 chunk，确认 capture 可恢复且 `outOfOrderChunks` 可见。
- 注入错误 payload 长度，确认 `malformed` 增加。
- 注入 `sample_count * sample_bytes > 20`，确认拒绝该 data frame。
- 注入 unknown LA type，确认 parser 不崩溃并保留原始帧计数。

## 7. 交付物

| 文件 | 内容 |
| --- | --- |
| `doc/OpenFPGA_Debug_Protocol_v1.md` | Logic Analyzer 类型、payload、flags、状态、示例帧 |
| `tools/viewer/protocol_parser_test.py` | LA parser 回归测试向量 |
| `tools/viewer/web/app.js` | LA parser、capture model、测试钩子、JSONL 导出 |
| `doc/M22_LogicAnalyzer_协议与捕获模型实施计划.md` | 本实施计划 |

## 8. 验收

运行：

```text
python tools/viewer/protocol_parser_test.py
```

期望：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

浏览器侧通过测试钩子验证：

```javascript
const api = window.openfpgaViewerTest;
api.clearAll();
api.injectLogicAnalyzerSample();
```

期望 Logic Analyzer model 中出现至少 1 次完整 capture、1 个 trigger event 和多条 sample chunk。

## 9. 当前实现状态

- 已在 `doc/OpenFPGA_Debug_Protocol_v1.md` 补齐 Logic Analyzer `0x40..0x46` 类型、payload、flags、state 和 parser 行为。
- 已在 `tools/viewer/protocol_parser_test.py` 增加 LA parser/model、payload helper 和回归向量，覆盖完整 capture、trigger event、status、分片 sample、缺片、乱序、错误长度、非法 sample packing 和保留 LA type。
- 已在 `tools/viewer/web/app.js` 增加 LA type、Monitor register map、capture model、parser、malformed/missing/out-of-order counters、JSONL 导出记录和 `injectLogicAnalyzerSample()` 测试钩子。

已通过：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

当前环境未安装 `node`，因此未执行 `node --check tools/viewer/web/app.js`。

## 10. 留给 M23

- 实现 `openfpga_la_pkg.vh` 中的 type、state、flag 和 register 常量。
- 实现 RTL capture core 和 adapter，生成符合 M22 定义的 payload。
- 用 RTL 仿真验证 header/data/status/trigger event 的字段一致性。
