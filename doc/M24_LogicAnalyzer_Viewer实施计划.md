# M24 Logic Analyzer Viewer 实施计划

M24 目标是在 Web Viewer 中交付可用的 Logic Analyzer 视图。它基于 M22 的 parser/model，不要求真实硬件已经接入；无硬件注入样例必须先跑通显示、游标和导出。

## 1. 目标

- Web Viewer 新增 Logic Analyzer 标签页。
- 支持数字波形绘制、通道列表、trigger marker、游标、缩放和平移。
- 支持通过 Monitor 寄存器配置和控制 LA capture。
- 支持 VCD/JSONL 导出和无硬件注入样例。
- 对 malformed、missing chunk、overflow 和 partial capture 做可见提示。

## 2. 修改文件

```text
tools/viewer/web/
  index.html
  app.js
  styles.css

doc/
  OpenFPGA_Web_Viewer_使用说明.md
  M24_LogicAnalyzer_Viewer实施计划.md
```

## 3. UI 区域

Logic Analyzer 标签页建议划分为：

| 区域 | 内容 |
| --- | --- |
| Capture 控制 | arm、stop、force trigger、clear、start readout |
| 配置 | sample divisor、capture depth、pre-trigger depth、trigger channel、trigger mode、value、mask |
| 状态 | capture_id、state、samples、chunks、overflow、dropped frames、malformed |
| 通道列表 | 名称、bit index、显示开关、颜色、当前游标值 |
| 波形区 | 数字轨道、trigger marker、时间刻度、缩放、平移 |
| 游标 | cursor A/B、delta samples、delta cycles、换算时间 |
| 导出 | VCD、JSONL，可选 CSV |

UI 应保持工程工具风格：波形区域优先，控件紧凑，避免大面积说明文字和装饰性卡片。

## 4. Waveform Model

从 M22 capture model 派生 Viewer 展示数据：

```text
waveform = {
  captureId,
  samplePeriodCycles,
  sampleCount,
  triggerIndex,
  channels: [
    { name, bit, width, color, visible }
  ],
  samples: [
    { index, value }
  ],
  viewport: {
    startSample,
    samplesPerPixel,
    cursorA,
    cursorB
  }
}
```

P0 静态通道 manifest 可先内置：

| bit | 名称 |
| --- | --- |
| `0` | `uart_tx_busy` |
| `1` | `uart_rx_valid` |
| `2` | `debug_tx_valid` |
| `3` | `debug_tx_ready` |
| `4` | `trace_valid` |
| `5` | `monitor_resp_valid` |
| `6` | `profiler_snapshot_valid` |
| `7` | `demo_frame_tick` |
| `15:8` | `debug_buffer_used_lsb` |
| `23:16` | `demo_fifo_level_lsb` |
| `31:24` | `la_state_debug` |

## 5. 绘制行为

- 数字 1-bit 信号绘制为高低电平阶梯线。
- 多 bit bus P0 可以显示为紧凑文本值或小型总线轨道，不要求模拟波形样式。
- trigger marker 固定在 `trigger_index`，滚动和缩放时保持对齐。
- zoom 以 sample 为单位，不使用亚 sample 插值。
- cursor A/B 吸附到 sample index。
- viewport 改变不重排通道列表，不改变 capture 数据。

## 6. Monitor 控制

Viewer 通过现有 Monitor 读写路径访问：

| 地址 | 名称 | Viewer 行为 |
| --- | --- | --- |
| `0x0060` | `LA_ID` | 连接后读取并显示可用性 |
| `0x0064` | `LA_VERSION` | 显示版本 |
| `0x0068` | `LA_CONTROL` | enable、auto_readout、trigger_enable |
| `0x006C` | `LA_STATUS` | 轮询状态和错误 |
| `0x0070` | `LA_SAMPLE_DIVISOR` | 配置采样分频 |
| `0x0074` | `LA_CAPTURE_DEPTH` | 配置捕获深度 |
| `0x0078` | `LA_PRETRIGGER_DEPTH` | 配置预触发深度 |
| `0x007C` | `LA_TRIGGER_MODE` | 配置触发模式 |
| `0x0080` | `LA_TRIGGER_CHANNEL` | 配置触发通道 |
| `0x0084` | `LA_TRIGGER_VALUE` | 配置触发值 |
| `0x0088` | `LA_TRIGGER_MASK` | 配置触发 mask |
| `0x008C` | `LA_COMMAND` | arm、stop、clear、force_trigger、start_readout |
| `0x0090` | `LA_CAPTURE_ID` | 校验当前 capture |
| `0x0094` | `LA_CHANNEL_MASK` | P0 可选 |

## 7. 导出

JSONL 新增记录类型：

- `la_capture_header`
- `la_sample`
- `la_status`
- `la_trigger_event`
- `la_parser_counters`

VCD 导出要求：

- 每个 1-bit 通道作为独立 wire。
- 多 bit bus 作为 `wire [N-1:0]`。
- 时间单位可按 sample period cycles 映射为 cycle tick。
- trigger sample 可作为注释或附加 marker 信号。

CSV 可选，只导出：

```text
sample_index,packed_value
```

## 8. 无硬件样例

`Inject Sample` 增加 LA 场景：

- 注入 header。
- 注入 trigger event。
- 注入至少 3 个 data chunks。
- 注入 status done。
- 注入一个 malformed chunk，确认 counters 增加但 UI 不崩溃。

浏览器测试钩子：

```javascript
const api = window.openfpgaViewerTest;
api.clearAll();
api.injectLogicAnalyzerSample();
```

## 9. 验收

打开 `tools/viewer/web/index.html` 后：

- Logic Analyzer 标签页可见。
- 点击 `Inject Sample` 后出现一次 capture。
- Header 显示 capture_id、sample width、sample count 和 trigger index。
- 波形区显示多通道数字波形，trigger marker 位于预期位置。
- 游标 A/B 可以测量 sample delta 和 cycle delta。
- JSONL 导出包含 LA 记录。
- VCD 导出可被 GTKWave 或其他 VCD 工具打开。
- 错误长度或缺片场景不会导致 UI 崩溃。

回归命令：

```text
python tools/viewer/protocol_parser_test.py
```

如果项目已有 Viewer 性能测试，也应补充 LA 样例后运行：

```text
python tools/viewer/web/run_perf_test.py
```

### 9.1 验收结果

截至 2026-07-06，M24 Web Viewer Logic Analyzer 已完成实现并通过无硬件验收。

已验证命令：

```text
node --check tools\viewer\web\app.js
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
```

验证结果：

- `node --check tools\viewer\web\app.js`：通过，JavaScript 语法检查无错误。
- `python tools\viewer\protocol_parser_test.py`：通过，输出 `PASS: OpenFPGA Debug Protocol parser test vectors passed`。
- `python tools\viewer\web\run_perf_test.py`：通过，headless Web Viewer 压测输出包含：
  - `frames=11192`
  - `checksumErrors=0`
  - `syncDrops=0`
  - `unknownFrames=0`
  - `laCaptures=1`
  - `laMalformed=1`
  - `laChannels=11`
  - `laCanvasWidth=683`
  - `laSummary="0x0000A501 8 samples, trigger 3"`

已确认验收项：

- Logic Analyzer 视图已加入 Web Viewer。
- `Inject Sample` 可注入一次 LA capture，并显示 capture id、sample count 和 trigger index。
- 波形 canvas 可渲染静态 P0 manifest 的 11 个通道，包含 1-bit 数字轨道和多 bit bus 文本轨道。
- trigger marker、cursor A/B、sample delta 和 cycle delta 可见。
- 通道显示开关、viewport start、samples/px、zoom in/out 可工作。
- `Arm`、`Stop`、`Force`、`Clear`、`Readout` 和 `Apply` 已复用 Monitor 写路径生成 LA 控制/配置请求。
- JSONL 导出包含 LA header/sample/status/trigger 记录和 `la_parser_counters`。
- VCD 导出支持最新 capture 的可见通道。
- malformed LA chunk 会增加 counter 并在 UI 提示，不导致页面崩溃。

## 10. 留给 M25

- board demo 接入真实 LA core。
- Monitor register map 接入 LA 配置窗口。
- Viewer 从真实 UART 链路完成 arm、trigger、readout、waveform display。
