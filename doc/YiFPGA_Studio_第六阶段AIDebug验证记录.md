# OpenFPGA Studio 第六阶段 AI Debug 验证记录

## 1. 验证状态

日期：2026-07-16

- 硬件无关发布门禁：通过。
- Chromium 大数据工作流：通过。
- 真实板级故障注入：部分通过；Profiler/FIFO/性能和 LA trigger missing 已执行。
- 真实远程 Provider：非 P0 门禁，未执行。

## 2. 自动回归结果

| 项目 | 结果 |
| --- | --- |
| M27 Snapshot schema/hash | 4 fixtures 通过 |
| M28 本地规则 | 12 Golden Cases、10 rules 通过 |
| M29 Provider | 12 生命周期/非法输出 case 通过 |
| Protocol parser | 通过 |
| Viewer 压力 | 11,192 frames，checksum/sync drop 为 0 |
| AI Debug 大 snapshot | 5,919 evidence，本地和 Mock AI 完成 |
| Evidence 引用 | 0 个悬空引用 |
| Provider 上下文 | 59,023 bytes，低于 64 KiB 预算 |

执行命令：

```text
python3 tools/viewer/ai_debug_validate.py all
python3 tools/viewer/protocol_parser_test.py
python3 tools/viewer/web/run_perf_test.py
```

Schema version 为 1，rule set version 为 1，prompt version 为 `openfpga-diagnosis-v1`。自动测试仅使用 Disabled/Mock Provider，没有网络和真实凭据。

## 3. 板级场景记录

板级场景定义保存在 `tools/viewer/fixtures/ai_debug/board/qualification_manifest.json`。以下硬件字段必须在执行时填写，不得用离线 fixture 代替：board、part、bitstream、build ID、协议版本、连接、基线参数、注入 tick、恢复 tick 和人工确认根因。

| 场景 | 当前状态 | 人工根因 | 恢复结果 |
| --- | --- | --- | --- |
| Transport error | 同一份脱敏板级捕获的离线派生 snapshot 通过 | 人工注入 checksum/malformed 计数 | 未修改 baseline 复放无 finding |
| FIFO backpressure | 实板通过：Profiler 低阈值受控注入 | demo FIFO/latency alert | enable/period/threshold 逐值恢复 |
| Throughput/latency degradation | 实板通过：有界 Profiler 场景 | demo stall/latency 超过临时阈值 | 配置恢复，UART 持续接收 |
| LA trigger missing | 实板通过：固定为 0 的 channel 31 配置 level-high | trigger 条件确定不成立 | stop 后 9 个配置寄存器逐值恢复 |
| LA data integrity | 同一份脱敏板级捕获删除 chunk 6 的派生 snapshot 通过 | 缺失 samples 30..34 | 未修改 baseline 为 13/13 chunks、无 finding |

## 4. 降级、权限与隐私

- Disabled Provider、timeout、cancel、retry、迟到响应和非法输出已有自动向量。
- Provider 失败时 snapshot、本地 finding、证据跳转和导出仍保留。
- Provider 接口没有 Monitor write、LA command、program、build 或文件写能力。
- Ask AI 需要页面显式 consent；默认 Mock Provider 不访问网络。
- 自动 fixture 不包含凭据值、绝对设备路径或用户工程元数据。

## 5. 板级执行填写模板

每个场景复制以下字段填写，并附脱敏 snapshot、diagnosis JSON 和 Markdown：

```text
scenario:
date/operator:
board/part:
bitstream/build_id/protocol/viewer_version:
connection:
baseline:
recovery_point:
injection_parameters:
start_tick/end_tick:
snapshot_id/integrity:
rule_ids/evidence_ids:
provider/model/prompt_version/request_id:
hypotheses/counter_evidence/information_gaps:
human_confirmed_root_cause:
false_positive/false_negative:
recovery_steps/result:
```

在这些板级字段和恢复结果完成前，第六阶段只能视为“自动发布门禁通过、板级发布待签署”。

## 6. 2026-07-16 实板执行记录

- JTAG target `Digilent/210512180081`，device `xcku5p_0`，Vivado 2024.2；M36 normal build `0x4d360001` 下载成功，startup HIGH，ILA 数量 1。
- UART `/dev/ttyUSB1` 10 秒基线：25,240 bytes、1,660 frames、0 checksum/version error，包含 Debug、Status、Trace 和 Watch。
- JTAG Bridge 两次 30 秒约 2,524 B/s。历史 `overflow_count/dropped_bytes=46149` 在第二窗口没有增长，不作为持续链路故障。
- Profiler：原值 enable 0、period 100000、threshold 96；临时 threshold 1。15 秒得到 120 个 snapshot、510 个 alert；结束后三个原值读取一致。
- LA trigger-missing：清除粘滞状态后对固定为 0 的 channel 31 配置 level-high；5 秒后 `la_status=0x11`（ARMED），无 trigger event；stop 后全部配置读取一致。
- 控制脚本 `tools/viewer/ai_debug_board_scenario.py` 采用固定写地址白名单、显式 `--confirm-safe-writes` 和 `finally` 恢复。

## 7. 2026-07-17 派生损坏证据绑定

- Transport 和 LA Integrity 均绑定 `artifacts/manual/openfpga-debug-1784268897418.jsonl`，原始捕获 SHA-256 为 `f161dd54cac33a7a237d5700305047ad3d9e9c25808228046d6ab3c4753ad4d8`。
- 原始捕获包含 1,567 frames、0 checksum/sync/unknown error，以及 capture `0x42` 的 64 samples、13/13 chunks、0 malformed/missing/out-of-order/drop。
- 保存一个未修改 baseline snapshot、一个 checksum/malformed 计数派生 snapshot，以及一个删除 chunk 6（samples 30..34）的派生 snapshot。
- `ai_debug_validate.py board` 现在实际校验原始文件哈希、三个 snapshot 的 schema/hash、派生到 baseline 的关系、预期/禁止 rule、finding evidence 引用和 baseline 无 finding 恢复结果。
- 两类派生场景的证据绑定已完成；30 分钟周期诊断长稳和最终发布负责人签署仍待执行。

## 8. 2026-07-17 板卡恢复复测与 LA_STATUS 修复

- 重新枚举到 CH340 `/dev/ttyUSB1` 和 Digilent FT232H `/dev/ttyUSB0`；Monitor ID 只读冒烟返回 `0x4F464D30`，checksum error 为 0。
- 15 秒 Profiler 受控场景通过：61 snapshots、31 alerts；`PROFILER_CONTROL/SAMPLE_PERIOD/ALERT_THRESHOLD0` 三项恢复值与 baseline 完全一致。
- LA trigger-missing 复测没有收到 `LA_TRIGGER_EVENT`，但 `LA_STATUS=0x1B`，未满足保持 ARMED 的验收条件；9 个 LA 配置寄存器均在 `finally` 中恢复。
- 根因是 Monitor bank 将互斥的 `LA_STATUS[2:0] state` 与历史值持续 OR，导致 `ARMED(1)` 和后续状态被累积成错误枚举。修复后仅 `[31:3]` 保持粘滞/W1C，`[2:0]` 始终来自实时 core state。
- `just la-board-sim` 已新增不可能触发条件下的实时 ARMED 断言并通过；当前板上旧镜像仍包含缺陷，需重新构建和下载后才能重做 trigger-missing 签署及 30 分钟长稳。

## 9. 2026-07-17 修复镜像实板确认

- M36 UART+JTAG+ILA 修复候选构建通过：part `xcku5p-ffvb676-2-i`、WNS `+2.907 ns`、BSCANE2 1、ILA 1、Vivado 0 warning/critical warning/error。
- bitstream SHA-256：`3461b2cef34e2102aba74d46b8e707c5df0421d7c885983590a544dd9008595b`；LTX SHA-256：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
- 指定 Digilent target `210512180081` 下载成功，device `xcku5p_0`，ILA 枚举 1。
- 下载后 10 秒纯接收通过：563 frames、checksum/version error 0、`drop_count 0->0`；首次 Monitor 请求从流中间接入产生的单次 checksum error 未在纯接收窗口复现。
- Profiler 15 秒场景通过：63 snapshots、32 alerts，三个临时配置全部恢复到 baseline。
- LA trigger-missing 修复复测通过：5 秒无 `LA_TRIGGER_EVENT`，`LA_STATUS=0x11`（实时 ARMED + overflow sticky），9 个 LA 配置寄存器全部恢复到 baseline。
- 剩余门槛为不少于 30 分钟持续接收与周期诊断，以及发布负责人最终签署。

## 10. 2026-07-17 修复镜像 30 分钟长稳

- 同一修复镜像完成 1800 秒 LA/Profiler 共存长稳，结果 PASS。
- 共完成 62 次采集，`capture_id 1->2->3` 后周期递增至 63；前两次采集均为 header 1、data 13、status 1、trigger 1。
- `checksum_errors=0`，Debug Core `drop_count 0->0`、峰值 0，LA overflow 0、malformed 0。
- 长稳期间观测到 720 个 Profiler snapshots，证明周期 LA readout 未阻断 Profiler 共存数据面。
- 5 分钟分段门槛全部通过：300/600/900/1200/1500/1800 秒分别完成 12/22/32/42/52/62 次采集，capture ID 分别为 13/23/33/43/53/63；每个门槛的 checksum、drop、overflow 和 malformed 均为 0。
- 结束时 `restore LA and Profiler control/configuration: PASS`，证明正常退出后的 LA 与 Profiler 配置恢复成功。
- 硬件持续接收、周期采集/诊断和零丢包门槛通过；该命令未记录 Viewer RSS/heap 和取消次数，因此发布 Checklist 的组合长稳条目仍保留未勾选，待补充这两项度量。

## 11. 2026-07-17 Viewer 内存与取消生命周期补测

- Chromium 压力回归处理 11,194 frames，checksum/sync drop/unknown 均为 0；构建 5,920 evidence，Provider context 选择 132 项、裁剪 5,788 项，大小 58,720 bytes。
- CDP heap used 从 502,108 bytes 增至 21,174,608 bytes，增量 20,672,500 bytes；测试结束 total heap 为 74,186,752 bytes。
- 连续执行 5 次延迟 Mock Provider 请求并立即取消，5 次均进入 `cancelled`，每次均保留本地 finding；随后正式 Mock diagnosis 仍完成，报告无悬空 evidence 引用。
- 该结果与第 10 节 1800 秒硬件长稳合并后，已覆盖持续接收、周期诊断、数据量、drop、内存和取消次数，发布 Checklist 的组合长稳条目完成。

## 12. 2026-07-17 实板 snapshot 原始记录补采

- `ai_debug_board_scenario.py` 新增 `--record`，保存实际协议 payload、场景 baseline、恢复读回、帧计数和结果，不再从终端摘要反推指标。
- Profiler/FIFO 记录包含 63 snapshots、32 alerts 及 Trace 共存帧，baseline 与 recovery 三个寄存器完全一致；文件 SHA-256 为 `0ee9158dfa8689d385f0c913e8d0a803c7ca3e06bff3263c908676406bd8b233`。
- LA trigger-missing 记录包含 5 秒原始帧、`LA_STATUS=0x11`、无 trigger event，以及 9 个配置寄存器一致的 baseline/recovery；文件 SHA-256 为 `265a40a861877b89d0467249de0e7e6f3164d80b677d3bbe416a0108f0de4276`。
- 下一步从这两份原始记录生成并绑定 FIFO 与 LA trigger snapshot；Performance 场景需单独建立注入前后吞吐 baseline，不能用自然窗口波动代替受控下降。

## 13. 2026-07-17 五类场景 snapshot 收口

- 从实际板级运行记录生成 FIFO 与 LA trigger-missing snapshot；FIFO 保留真实 `FIFO_DEMO_LEVEL` 和同窗口 Trace payload，LA 保留实际 ARMED 状态、5 秒等待周期和零 trigger event 计数。
- 新增受控 throughput-drop 场景：相同 10 秒窗口下将 `DEMO_PERIOD` 从 1,000,000 调整为 100,000,000 ticks，实际 Profiler throughput 帧率从 10.0/s 降至 0.1/s，baseline ratio 为 0.01；`DEMO_PERIOD` 与 Profiler 配置全部恢复。
- Performance 原始运行记录 SHA-256 为 `d4996906fedf38dd2654d947c5cf24c66949a86196ab09121354c9613614f64e`。
- snapshot 生成器固定从原始 payload/运行记录解码，并为每个输入 snapshot 绑定独立 baseline snapshot；跨语言哈希使用十进制定点字符串避免 Python/JavaScript 浮点 JSON 表示差异。
- `ai_debug_validate.py release` 现通过 5/5 场景：逐一验证源文件 SHA、snapshot schema/hash、required evidence kind、预期/禁止规则、finding 引用和 baseline 无 finding 恢复。
- 第六阶段发布 Checklist 除发布负责人最终签署外已全部完成。

## 14. 发布签署

- 2026-07-17，发布负责人复核已知限制并确认第六阶段发布。
- 自动门禁、5/5 板级场景 snapshot、规则/evidence 引用、逐场景恢复、1800 秒硬件长稳、Viewer 内存与取消生命周期均为 PASS。
- 第六阶段 AI Debug 状态由“板级部分通过”更新为“完整板级发布通过”。
