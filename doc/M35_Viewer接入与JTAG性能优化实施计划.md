# M35：Viewer 接入与 JTAG 性能优化实施计划

## 1. 里程碑目标

将 JTAG Bridge 作为 Viewer 的新 byte-stream 数据源接入，复用 Serial 的 Parser 和业务模型，并通过可重复测量选择 block、polling、BRAM 和 socket batching 参数。

## 2. 前置条件

- M34 的 Bridge 握手、socket framing、状态和错误语义已稳定。
- 现有 Serial Parser 回归基线可运行。
- 有 Mock 回放环境；真实板级调优在用户确认后进行。

## 3. 实现顺序

### WP1：统一数据源接口

- 抽象 Serial/JTAG source 的 connect、disconnect、bytes、status 和 error 生命周期。
- JTAG payload 直接进入现有 Parser，不建立第二套 Debug/Trace/Profiler/LA 模型。
- 断开时保留已解析记录；重连依据 session id 清理半帧并等待 SOF。

### WP2：连接和状态界面

- 默认地址 `127.0.0.1`，端口可配置。
- 显示 bridge version、cable/device/USER chain、session/build id 和连接状态。
- 显示当前/平均吞吐、buffer used、overflow、dropped bytes、reconnect 和最近错误。
- 默认单会话选择单数据源；UART/JTAG 双输出仅用于独立对比，不无标识合并。

### WP3：回归与回放

- 同一 fixture 经 Serial 和 JTAG source 后生成等价 Parser 记录。
- 覆盖 socket 粘包/拆包、空块、短块、断线、重连、session 变化和慢 UI。
- raw capture 可离线重放，结果与在线解析一致。

### WP4：性能测量

- 分别测量 256 B、512 B、1 KB、2 KB、4 KB block 和可用 TCK。
- 记录有效吞吐、P50/P99 延迟、Host CPU、buffer occupancy、drop/overflow。
- 分别改变一个变量，禁止同时调整 TCK、block、poll 和 BRAM 后归因不清。
- 以持续有效吞吐和 P99 为选择依据，不以瞬时峰值作为发布结论。

### WP5：参数收敛

- 先扩大 block、减少 host round-trip，再调整 polling 与 socket batching。
- 在延迟、CPU 和溢出之间选出默认配置及保守配置。
- 100 KB/s 为最低门槛；500 KB/s–1 MB/s 为冲刺目标。

## 4. 全链路验证

- Debug、Trace、Profiler、LA 数据通过 JTAG-only 路径正确展示。
- AI Debug 继续消费 Viewer 已解析数据，仅在 snapshot target 中记录 transport health。
- JTAG disabled 时 Serial/UI 行为无回归。
- 断线恢复后不拼接不同 session 的半帧，不重复历史记录。
- UI 渲染慢时 Bridge/Viewer 队列有界，统计能反映丢弃或积压。

## 5. 验收门禁

- Parser 和 Viewer 自动化测试通过，Serial/JTAG 基准记录语义等价。
- Mock 连续运行无死锁、无持续内存增长。
- 在可重复环境达到至少 100 KB/s；记录工具、TCK、block、BRAM、CPU 和瓶颈。
- 推荐配置、保守配置及已知限制写入使用说明。
- 真板性能、下载和探测操作必须在用户明确确认后执行。

## 6. 交付物

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/YiFPGA_JTAG_Transport_使用说明.md`
- 本实施计划、性能原始数据与结论

## 7. 回退策略

若 Hardware Manager backend 无法达到门槛，保留 Viewer/source 接口和 Mock 回归，回退评估常驻 XSDB、XVC 或正式 API；不得通过无界缓存掩盖吞吐不足。

## 8. 实施记录（2026-07-14）

- WP1–WP3 已实现：Serial/JTAG 单来源选择、共享 Parser、WebSocket bridge、session 半帧隔离、
  transport health 和 raw replay 已接入。
- Bridge 保留原始 TCP `48534`，新增 Viewer WebSocket `48535`；两者传输相同 socket record。
- 自动门禁为 `just m35-check`，不访问硬件。
- `just m35-check` 已在 Google Chrome 150 headless 环境通过：11,192 帧，checksum/sync/unknown
  均为 0，2,400 spans、2,400 marks、800 values，Viewer 压测解析与渲染耗时 628 ms。
- Direct FTDI/MPSSE 已封装为常驻 Bridge backend，支持参数化 TCK 和 1..1024 B block；离线
  backend/commit 回归已通过。FPGA USER-DR payload shift 已真板验证，256 B 短窗口曾达到
  约 151.89 KiB/s，但持续门槛仍待高速数据源和用户明确确认后执行。Mailbox v1 的
  2 KiB/4 KiB 测点因 ABI 最大 1 KiB 明确记为不支持。
- 新 backend 真板全链路已复测：10 MHz、1024 B 满块短窗口达到 214,115.7 B/s；常驻 Bridge
  hello/DATA/status 输出正确。当前业务源持续约 2.66 KB/s，仍不能宣称持续 100 KB/s；原始
  数据与结论见 `M35_JTAG性能验证记录_2026-07-14.md`。
- 专用合法帧持续源、独立 build ID、仿真/构建/下载流程已完成。实际 10 MHz TCK 下每档
  1 MiB 测得 256/512/1024 B 分别为 85,391.9/238,392.7/206,631.6 B/s，矩阵后 drop/
  overflow 为 0；M35 的可重复 100 KB/s 门槛已由 512 B 和 1024 B 配置达到。30 分钟长稳、
  P50/P99 和 Host CPU 留作 M36 发布门禁。
