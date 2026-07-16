# M20 Profiler Viewer 实施计划

M20 目标是在现有 Web Viewer 中加入可用的 Profiler 视图，让第四阶段的统计指标可以被浏览、比较、导出和配置。

## 1. 目标

- 新增 `Profiler` 标签页。
- 解析并展示 `PROFILER_SNAPSHOT/ALERT`。
- 支持指标卡、趋势图、统计表、alert 面板。
- 通过 Monitor 控制 Profiler enable、sample period、clear。
- 支持 JSONL/CSV 导出。
- 保持 Log、Trace、Monitor 现有能力不回退。

## 2. 修改文件

```text
tools/viewer/web/
  index.html
  app.js
  styles.css

doc/
  OpenFPGA_Web_Viewer_使用说明.md
```

## 3. UI 能力

### 指标卡

显示：

- Throughput：窗口 bytes、beats、stall cycles。
- FIFO：current/max/min level、overflow/underflow。
- Latency：count、min、max、avg cycles。
- Frame Rate：frames/window、drop、min/max interval。

### 趋势图

- 按 metric_id 绘制最近 N 个 snapshot。
- 默认显示 value0，用户可切换 value1/value2/value3。
- 不使用大量 DOM 节点，避免长时间运行卡顿。

### 统计表

列：

| 列 | 说明 |
| --- | --- |
| Metric | 名称和 ID |
| Type | Throughput/FIFO/Latency/Frame |
| Latest | 最新主值 |
| Window | sample_cycles |
| Min/Max/Avg | 根据类型显示 |
| Flags | VALID/SATURATED/ALERT |
| Updated | 最新 timestamp |

### Alert 面板

显示 threshold、overflow、underflow、timeout、drop，并支持按 level 过滤。

### 控制区

通过现有 Monitor encoder 生成：

- 写 `PROFILER_CONTROL` 启停。
- 写 `PROFILER_SAMPLE_PERIOD` 调整窗口。
- 触发 `PROFILER_CLEAR` 清零。
- 读 `PROFILER_STATUS` 查看 overflow/drop。

## 4. 数据模型

```text
state.profiler = {
  definitions: [],
  latest: new Map(),
  history: new Map(),
  alerts: [],
  selectedMetricId: null,
  maxHistoryPerMetric: 600,
  counters: {
    snapshots: 0,
    alerts: 0,
    malformed: 0
  }
}
```

## 5. Inject Sample

`Inject Sample` 增加：

- Throughput snapshot：bytes、beats、active/stall。
- FIFO snapshot：level/max/min/overflow。
- Latency snapshot：count/min/max/avg。
- Frame Rate snapshot：frame_count/drop/min_interval/max_interval。
- Alert：threshold high 或 overflow。

## 6. 导出

JSONL 新增：

- `profiler_snapshot`
- `profiler_alert`

CSV 支持：

- 当前筛选 metric 的 snapshot 历史。
- 包含 timestamp、metric_id、sample_cycles、value0..value3、flags、overflow_count。

## 7. 验收

无硬件：

1. 打开 `tools/viewer/web/index.html`。
2. 点击 `Inject Sample`。
3. 切换到 `Profiler`。
4. 确认指标卡、趋势图、统计表和 alert 面板均有数据。
5. 点击 `Export JSONL`，确认包含 `profiler_snapshot/profiler_alert`。
6. 使用测试钩子写入错误长度 Profiler 帧，确认 malformed 计数增加且 UI 不崩溃。

命令行：

```powershell
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
```

期望 parser 和性能冒烟测试通过。

## 8. 留给 M21

- 接入真实 board demo Profiler 帧。
- 通过 Monitor 控制板级 Profiler enable、period、clear。
- 补充 Profiler 使用说明、验证记录和发布 checklist。

## 9. 实施记录

- 已在 Web Viewer 新增 `Profiler` 区块，包含指标卡、趋势图、统计表、alert 面板和控制区。
- 已复用 M17 Profiler model 展示 M19 四类 probe 指标：Throughput、FIFO、Latency、Frame Rate。
- 已通过 Monitor 请求生成 Profiler enable、disable、sample period、clear 和 status read 操作。
- `Inject Sample` 已覆盖四类 snapshot 和 alert；headless smoke test 额外注入错误长度 Profiler 帧验证 malformed 计数。
- `Export JSONL` 已包含 `profiler_snapshot`、`profiler_alert`、`profiler_counters`；`Export CSV` 在当前 metric 有历史时导出该 metric 的 snapshot 历史。

验收：

```powershell
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
```

当前两项均通过。
