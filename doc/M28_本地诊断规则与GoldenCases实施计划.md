# M28 本地诊断规则与 Golden Cases 实施计划

M28 在 M27 统一证据模型之上建立确定性诊断基线。即使没有网络、密钥或 AI Provider，用户也应得到可复现的异常事实、候选原因和下一步检查建议。

## 1. 目标与边界

- 定义版本化 rule 和 finding 数据模型。
- 实现 Transport、Monitor、FIFO、Throughput、Latency、Frame、LA 和跨来源关联规则。
- 建立不少于 10 个正常/异常 golden cases。
- 每个 finding 展示阈值来源、实际值、证据引用、候选原因和验证步骤。
- 对相同输入和规则版本产生稳定结果。

M28 不使用自然语言模型，不自动修改阈值，不把时间重叠表述为已证明因果，也不提供可视化规则编辑器。

## 2. 交付物

```text
tools/viewer/web/diagnostic_rules.js
tools/viewer/fixtures/ai_debug/
  snapshots/
  expected/
tools/viewer/ai_debug_validate.py
doc/M28_本地诊断规则与GoldenCases实施计划.md
```

建议 finding 结构：

```json
{
  "finding_id": "finding-transport-001",
  "rule_id": "transport.error_rate.v1",
  "rule_version": 1,
  "severity": "warning",
  "title": "Transport errors increased in the selected window",
  "observed_fact": "...",
  "evidence_ids": ["ev-transport-001"],
  "threshold": {"value": 1, "source": "default"},
  "actual": {"value": 4},
  "possible_causes": [],
  "recommended_checks": []
}
```

## 3. 规则执行模型

- 输入为不可变 snapshot、规则配置和可选 session baseline。
- 输出按 severity、timestamp、rule id、finding id 稳定排序。
- 阈值优先级为工程配置 > 当前会话基线 > 固定默认值。
- 缺少必需证据时返回 skipped reason 或信息缺口，不伪造正常结论。
- 完整性严重不足时先输出 data-quality finding，并抑制依赖缺失数据的强结论。
- 跨来源规则只能表述“时间相关”或“共同出现”，除非规则条件本身证明状态传递。
- finding 不得引用 snapshot 中不存在的 evidence ID。

## 4. P0 规则集

| 规则组 | 最小条件 | 主要输出 |
| --- | --- | --- |
| Transport Health | checksum、malformed 或 drop 增长 | 先排除链路与 parser 问题 |
| Monitor Timeout | request 无 response、seq 不匹配 | 请求窗口、decoder/response 路径检查 |
| FIFO Backpressure | level 高、valid 持续、ready 低 | 堵塞区间和上下游证据 |
| Throughput Drop | 当前值低于 baseline/threshold | 下降幅度、window、stall/drop 关联 |
| Latency Spike | average/max 超阈值 | Trace span 和 LA 邻近窗口 |
| Frame Stall | frame tick 缺失或周期异常 | 最后正常帧、状态寄存器和事件 |
| LA Trigger Missing | armed 后超时未触发 | trigger 配置、信号活动和采样设置 |
| LA Data Integrity | chunk 缺失或 sample count 不一致 | 降低结论强度并建议重采 |
| Cross-source Correlation | 两类异常窗口重叠 | 时间差、共同证据和验证步骤 |

## 5. 任务拆分

### M28.1 Rule Registry

- 固化 rule id、版本、适用 evidence kind、默认阈值和严重度。
- 支持按规则组启停和工程级阈值覆盖。
- 未知配置字段报警，非法阈值拒绝执行。

### M28.2 Evaluator 与关联器

- 实现窗口聚合、计数增量、连续状态、baseline 比较和时间重叠工具。
- 每项规则同时生成 observed fact 与 recommended checks。
- 对重复或从属 finding 做确定性合并，保留全部有效证据。

### M28.3 Golden Cases

至少覆盖：

1. 全来源正常会话。
2. Transport checksum/malformed 增长。
3. Monitor response timeout。
4. FIFO 持续 backpressure。
5. Throughput 明显下降。
6. Latency spike。
7. Frame tick stall。
8. LA 已 arm 但 trigger missing。
9. LA 缺 chunk/partial capture。
10. Trace timeout 与 FIFO/Profiler 异常重叠。
11. 时间未知时禁止强关联。
12. 数据完整性不足时规则降级。

每个 case 保存输入 snapshot、期望 rule ids、severity、evidence ids、threshold source 及明确禁止出现的 finding。

### M28.4 自动回归与报告

- 为 `ai_debug_validate.py` 增加 `rules` 和 `all` 入口。
- 支持单 case 诊断、golden 更新预览和机器可读失败 diff。
- golden 变更必须显式更新，不允许测试自动覆盖 expected 文件。

## 6. 验收指标

| 指标 | 门槛 |
| --- | --- |
| 预期 P0 rule 命中率 | 100% |
| 正常 case 的 error 级误报 | 0 |
| finding evidence 引用有效率 | 100% |
| threshold source 可追溯率 | 100% |
| 同输入同版本结果稳定性 | 100% |
| 完整性不足的强结论抑制 | 所有对应向量通过 |

建议验收命令：

```text
python tools/viewer/ai_debug_validate.py rules
python tools/viewer/ai_debug_validate.py all
python tools/viewer/protocol_parser_test.py
node --check tools/viewer/web/diagnostic_rules.js
```

## 7. 完成定义

- P0 规则组全部实现并有正、反测试向量。
- 至少 10 个 golden cases 通过，正常样例无 error 级误报。
- 所有 finding 均能显示事实、证据、阈值来源和验证步骤。
- Snapshot 不完整或时间未知时不会输出越界结论。
- 禁用全部规则时仍可构建和导出 M27 snapshot。

## 8. 留给 M29

- M29 将 rule findings 作为高优先级上下文，但 Provider 不能覆盖或改写它们。
- Context Builder 应保留 finding 使用的证据，裁剪时不得产生悬空引用。
- Provider 输出与规则冲突时交由结果校验层标记并列展示。

## 9. 实施记录（2026-07-16）

M28 已按本计划完成，并通过硬件无关回归。

### 9.1 已交付实现

- `tools/viewer/web/diagnostic_rules.js`
  - 提供 `VERSION`、`REGISTRY`、`validateConfig(config)` 和 `evaluate(snapshot, config, baseline)` 公共接口。
  - 固化 10 条 v1 规则：数据质量、Transport、Monitor、FIFO、Throughput、Latency、Frame、LA Trigger、LA Integrity 和跨来源时间关联。
  - 阈值优先级实现为工程配置、会话 baseline、固定默认值。
  - 对未知配置字段、未知 rule id、未知阈值 rule 和非法阈值直接拒绝执行。
  - finding 包含稳定 ID、规则版本、严重度、事实、证据引用、阈值来源、实际值、候选原因和人工检查步骤。
  - 输出按严重度、时间、rule id 和 finding id 稳定排序；相同输入重复执行结果一致。
  - Snapshot 或 LA 捕获不完整时先生成 data-quality finding，并抑制 LA trigger missing 强结论。
  - 缺少规则必需 evidence 时在 `skipped` 中记录 `missing_required_evidence`；时间不可比较时记录 `timestamps_not_comparable`。
  - 跨来源规则仅描述时间相关性，并明确声明不构成因果证明。
- `tools/viewer/web/diagnostic_rules_test.js`
  - 校验 Golden Cases 精确命中、禁止项、evidence 引用、threshold source、确定性、配置拒绝和全部规则禁用行为。
- `tools/viewer/fixtures/ai_debug/snapshots/rule_golden_cases.json`
  - 保存 12 个规则输入 case。
- `tools/viewer/fixtures/ai_debug/expected/rule_golden_cases.json`
  - 保存每个 case 的预期 rule ids、禁止 rule、evidence ids 和 threshold source。
- `tools/viewer/ai_debug_validate.py`
  - 新增 `rules` 和 `all` 命令。
  - 支持 `--case` 单 case、`--json` 机器可读 diff，以及只打印不写文件的 `--update-golden-preview`。
- `justfile`
  - 新增 `m28-check` 硬件无关发布门禁。

### 9.2 Golden Cases 覆盖

| Case | 主要验证点 |
| --- | --- |
| `normal_all_sources` | 正常输入无 finding |
| `transport_errors` | checksum/malformed 增长 |
| `monitor_timeout` | Monitor response timeout |
| `fifo_backpressure` | FIFO 持续 backpressure |
| `throughput_drop` | 当前吞吐低于 baseline |
| `latency_spike` | latency max 超阈值 |
| `frame_stall` | frame tick 缺失 |
| `la_trigger_missing` | armed 超时未触发 |
| `la_partial_capture` | LA 缺失范围与完整性降级 |
| `cross_source_overlap` | Trace/Profiler 异常时间邻近 |
| `unknown_time_no_correlation` | 未知时间禁止跨源强关联 |
| `incomplete_suppresses_trigger` | 数据不完整抑制 trigger missing 结论 |

### 9.3 验证结果

2026-07-16 执行结果：

```text
python3 tools/viewer/ai_debug_validate.py all
  snapshot validation: PASS (4 fixtures, 6 kinds)
  diagnostic rules: PASS (12 golden cases, 10 rules)

python3 tools/viewer/protocol_parser_test.py
  PASS: OpenFPGA Debug Protocol parser test vectors passed

node --check tools/viewer/web/diagnostic_rules.js
  PASS

python3 -m py_compile tools/viewer/ai_debug_validate.py
  PASS
```

验收结论：P0 规则 case 命中率 100%，正常 case 无 error 级误报，finding evidence 引用有效率和 threshold source 可追溯率均为 100%，同输入重复执行稳定，完整性不足场景的强结论已抑制。
