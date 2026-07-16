# M4 Viewer 基础视图实施计划

## 1. 目标

M4 将 M3 已经输出的 `HEARTBEAT/DEBUG_PRINT/EVENT/WATCH/STATUS` 协议帧接入上位机视图，形成第一阶段可用的调试观察界面：

- 实时接收 UART 字节流并按 OpenFPGA Debug Protocol v1 解包。
- 提供 Log、Event、Watch、Status 四类基础视图。
- Watch 按 ID 合并显示最新值，同时 Log 保留时间顺序记录。
- 显示 `buffer_used/drop_count/packet_count` 和 parser 错误计数，便于判断 UART 带宽或协议同步问题。
- 支持暂停显示、清空和导出，保证长时间调试时可以保留现场数据。

总规划中的 Qt Viewer 目标继续保留。当前仓库已经先落地 Web Viewer 骨架，因此 M4 先以 `tools/viewer/web` 作为可验收实现；后续 Qt Viewer 可以复用同一套协议解析行为和视图模型定义。

## 2. Viewer 变更

### 2.1 `tools/viewer/web/index.html`

工具栏补齐 M4 操作入口：

- `Pause/Resume`：暂停或恢复界面刷新。
- `Export CSV`：导出 Log 表。
- `Export JSONL`：导出 Log、Event、Watch、Status 和 parser counters 快照。

原有串口连接、波特率选择、样例帧注入和清空能力保持不变。

### 2.2 `tools/viewer/web/app.js`

M4 新增行为：

- Parser 在暂停显示时继续接收和解析串口数据，只是不刷新 DOM。
- 恢复显示时一次性刷新 Log/Event/Watch/Status/counters。
- Status 状态集中保存在 `state.status`，避免暂停期间直接改写界面。
- `drop_count > 0` 时在 Status 视图中高亮，提示已有丢包。
- CSV 导出按接收顺序输出 Log。
- JSONL 导出包含：
  - `kind: "log"`
  - `kind: "event"`
  - `kind: "watch"`
  - `kind: "status"`
  - `kind: "counters"`

### 2.3 `tools/viewer/web/styles.css`

新增暂停按钮按下态和 drop count 警示样式，保持现有轻量仪表盘风格。

## 3. 验收场景

### 3.1 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample`：

- Log 增加 Heartbeat、Event、Watch、Debug Print、Status 记录。
- Event 视图按 event ID 统计次数。
- Watch 视图按 watch ID 显示最新值和更新次数。
- Status 显示 buffer used、drop count、packet count 和 timestamp。
- 点击 `Pause` 后继续点击 `Inject Sample`，界面不刷新。
- 点击 `Resume` 后，暂停期间收到的数据一次性显示。
- `Export CSV` 能下载 Log 表。
- `Export JSONL` 能下载完整调试快照。

### 3.2 真实串口验收

使用 Chrome 或 Edge 打开 Web Viewer：

1. 选择与 FPGA Debug Core 一致的 baud rate。
2. 点击 `Connect` 并授权串口。
3. 运行 M3 或后续板级 demo，让 FPGA 输出协议帧。
4. 确认 Log/Event/Watch/Status 实时变化。
5. 故意提高事件上报频率或降低 baud rate，确认 `drop_count` 增长时可见。

## 4. 验收命令

当前 M4 Web Viewer 不需要构建步骤。协议 parser 的最小回归测试仍使用：

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

## 5. 留给 M5/M6 的事项

- M5 板级 demo 接入后，用真实 UART 长时间验证 Web Viewer。
- M6 整理 Viewer 使用说明，并明确 Web Viewer 与 Qt Viewer 的角色边界。
- Qt Viewer 后续实现时，建议沿用 M4 的模型语义：Log 追加、Watch 按 ID 合并、Event 计数、Status 独立快照。
- 大数据量场景后续可加入批量 DOM 刷新或虚拟列表，避免长时间运行时界面卡顿。
