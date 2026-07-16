# M17 Profiler 协议与指标模型实施计划

M17 是第四阶段 Profiler 的起点，目标是先把 FPGA 与 Viewer 对性能指标的字节级理解固定下来。M17 不实现 RTL Profiler Core，也不做完整 UI；这些分别放到 M18 和 M20。

## 1. 目标

- 固化 Debug Protocol v1 中 `0x30..0x3F` Profiler 类型空间。
- 定义 `PROFILER_SNAPSHOT` 和 `PROFILER_ALERT` payload。
- 定义 `metric_id`、单位、flags、alert code 和 `value0..value3` 语义。
- 在 Web Viewer 中加入 Profiler parser/model/test hook。
- 增加无硬件 parser 回归测试。

## 2. 协议范围

M17 正式启用：

| Type | 方向 | 名称 | M17 状态 |
| --- | --- | --- | --- |
| `0x30` | FPGA -> PC | `PROFILER_SNAPSHOT` | 定义并解析 |
| `0x31` | FPGA -> PC | `PROFILER_ALERT` | 定义并解析 |

M17 预留：

| Type | 名称 | 后续里程碑 |
| --- | --- | --- |
| `0x32` | `PROFILER_COUNTER` | P1 或 M20 后 |
| `0x33` | `PROFILER_LATENCY` | P1，P0 可并入 snapshot |
| `0x34` | `PROFILER_DISCOVER` | P1 动态 metric manifest |
| `0x35/0x36` | `PROFILER_CFG_REQ/RESP` | P1，P0 通过 Monitor 配置 |

## 3. Payload

`PROFILER_SNAPSHOT`：

```text
u32 timestamp
u16 metric_id
u16 flags
u32 sample_cycles
u32 value0
u32 value1
u32 value2
u32 value3
u16 overflow_count
u16 reserved
```

长度：32 字节，正好等于 Debug Protocol v1 当前 `LEN <= 32` 的最大 payload。

`PROFILER_ALERT`：

```text
u32 timestamp
u16 metric_id
u8  level
u8  code
u32 arg0
u32 arg1
```

## 4. Metric Model

Viewer 内部建议维护：

```text
state.profiler = {
  metrics: Map(metric_id -> definition),
  latest: Map(metric_id -> snapshot),
  history: Map(metric_id -> snapshot[]),
  alerts: [],
  counters: {
    snapshots,
    alerts,
    overflowSnapshots
  }
}
```

P0 静态 metric manifest：

| metric_id | 名称 | 类型 | 单位 |
| --- | --- | --- | --- |
| `0x0001` | `AXIS_DEMO_THROUGHPUT` | Throughput | bytes/window |
| `0x0101` | `FIFO_DEMO_LEVEL` | FIFO | level |
| `0x0201` | `DEMO_LATENCY` | Latency | cycles |
| `0x0301` | `FRAME_RATE` | Frame Rate | frames/window |

## 5. Parser 行为

- `PROFILER_SNAPSHOT` 长度必须为 32 字节，否则计入 malformed。
- `PROFILER_ALERT` 长度必须为 16 字节，否则计入 malformed。
- 未知 `metric_id` 仍保留原始数据，并以 `metric_0xNNNN` 显示。
- `flags.SATURATED` 或 `overflow_count > 0` 时必须进入 alert/notice 路径。
- `history` 按 metric 限长，避免长时间运行内存无界增长。
- JSONL 导出包含 snapshot、alert 和 parser counters 快照。

## 6. 测试向量

`tools/viewer/protocol_parser_test.py` 增加：

- 解析 Throughput snapshot，确认 `metric_id/value/sample_cycles` 正确。
- 解析 FIFO snapshot，确认 overflow flag 被记录。
- 解析 Latency snapshot，确认 min/max/avg 字段映射正确。
- 解析 Alert，确认 level/code/arg0/arg1 正确。
- 注入未知 metric，确认不会丢帧。
- 注入错误长度和 checksum 错误，确认 parser counters 增加。

## 7. 交付物

| 文件 | 内容 |
| --- | --- |
| `doc/OpenFPGA_Debug_Protocol_v1.md` | Profiler 类型、payload、flags、alert code、示例帧 |
| `tools/viewer/protocol_parser_test.py` | Profiler parser 回归测试 |
| `tools/viewer/web/app.js` | Profiler parser/model/test hook |
| `doc/M17_Profiler_协议与指标模型实施计划.md` | 本实施计划 |

## 8. 当前实现状态

- 已在 `doc/OpenFPGA_Debug_Protocol_v1.md` 补齐 Profiler 类型、payload、flags、alert code、parser 行为和示例帧。
- 已在 `tools/viewer/web/app.js` 增加 Profiler 静态 metric manifest、parser、latest/history/alert model、malformed counters、JSONL 导出和 `injectProfilerSample()` 测试钩子。
- 已在 `tools/viewer/protocol_parser_test.py` 增加 Throughput/FIFO/Latency/Alert/未知 metric/错误长度/checksum 错误测试向量。

## 9. 验收

运行：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

浏览器侧通过测试钩子验证：

```javascript
const api = window.openfpgaViewerTest;
api.clearAll();
api.injectProfilerSample();
```

期望 Profiler model 中出现至少 4 类 metric 和 1 条 alert。

## 10. 留给 M18

- 实现 `openfpga_profiler_pkg.vh`。
- 实现 `openfpga_profiler_core.v` 和 adapter。
- 让 RTL 能生成符合 M17 定义的 snapshot/alert payload。
