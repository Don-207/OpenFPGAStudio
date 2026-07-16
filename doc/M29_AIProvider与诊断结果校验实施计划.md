# M29 AI Provider 与诊断结果校验实施计划

M29 把不可控的模型调用限制在可替换、可取消、可校验的边界内。它负责上下文选择、脱敏预览、Provider 生命周期和结构化结果校验，不负责最终页面布局。

## 1. 目标与边界

- 实现 `DisabledProvider`、`MockProvider` 和一个配置隔离的 `RemoteProviderAdapter`。
- 实现证据排序、波形摘要、预算裁剪和外发预览。
- 固化 prompt version 与 `diagnosis_result` v1 schema。
- 覆盖 queued、running、validating、completed、failed、cancelled 状态。
- 拦截非法 JSON、未知 evidence ID、越界 confidence 和无依据结论。
- 确保凭据不进入 snapshot、日志、错误、fixture 或导出报告。

M29 不要求网络成为自动测试依赖，不允许 Provider 直接访问串口、Monitor 写、LA 控制、文件写或构建命令。

## 2. 交付物

```text
tools/viewer/web/ai_provider.js
tools/viewer/web/diagnosis_validator.js
tools/viewer/fixtures/ai_debug/provider/
tools/viewer/fixtures/ai_debug/expected/
tools/viewer/ai_debug_validate.py
doc/M29_AIProvider与诊断结果校验实施计划.md
```

公共接口建议：

```text
analyze(snapshotSummary, ruleFindings, selectedEvidence, options, signal)
  -> diagnosisResult
```

Provider 配置只保存 provider/model/endpoint、预算、timeout、retry 和凭据引用；凭据值只存在于请求边界的内存中。

## 3. Context Builder

选择优先级：

1. snapshot integrity 和 data-quality 告警。
2. 本地 finding 直接引用的证据。
3. 严重度高且靠近 scope 中心的异常证据。
4. 跨来源关联所需的相邻证据。
5. 正常基线和反证。

裁剪规则：

- 波形转换为边沿、稳定区间和触发附近窗口，不逐 sample 无上限发送。
- 保留 `selected_evidence_ids`、`omitted_evidence_count`、预算和裁剪原因。
- finding 及其证据必须作为一个原子单元保留或共同移除。
- 脱敏发生在预算计算和请求序列化之前。
- 请求预览显示字段类别、证据数量、估算大小和脱敏摘要，不显示凭据。

## 4. Prompt 与输出契约

Prompt 必须要求模型：

- 只依据提供的 evidence 和 finding。
- 区分 observed facts、hypotheses、counter evidence 和 information gaps。
- 每项 hypothesis 引用输入中的 evidence ID。
- 给出只读、可人工执行的 verification steps。
- 不声称已运行未提供的工具、仿真、构建或硬件操作。

`diagnosis_result` 至少包含：

```text
schema_version, summary, observed_facts, hypotheses,
recommended_actions, insufficient_evidence, metadata
```

`metadata` 记录 prompt version、provider/model、请求 ID、开始/结束时间、裁剪统计和校验状态，不记录 secret。

## 5. Result Validator

校验顺序：

1. 响应大小和 JSON 解析。
2. schema 必需字段与类型。
3. confidence 范围及枚举。
4. evidence ID 白名单。
5. 无证据 hypothesis 降级为待验证猜测。
6. recommended action 安全分类。
7. 与本地 finding 的冲突标记。

非法结果不得进入正式报告。可保留经过脱敏和限长的错误摘要用于排查，但不得把自由文本响应冒充诊断结果。

## 6. Provider 生命周期

- 每次分析分配单调 request generation；只有当前 generation 可提交结果。
- `AbortSignal` 或等价机制贯穿 context build、fetch、stream parse 和 validation。
- retry 仅用于明确可重试错误，使用有上限退避；取消和 schema 错误不重试。
- timeout 后进入 failed/timeout，保留 M28 本地 finding。
- 迟到响应被丢弃并记录状态，不覆盖新请求。
- Disabled Provider 返回明确 disabled 原因而非异常堆栈。

## 7. Mock 与自动测试矩阵

Mock Provider 至少支持：

| 模式 | 预期 |
| --- | --- |
| valid | 正常通过 schema 与引用校验 |
| streamed | 分片组合后结果一致 |
| retry-once | 第一次 5xx，第二次成功 |
| timeout | 状态可见，本地结果保留 |
| cancel | 快速结束，迟到响应无效 |
| invalid-json | 拒绝正式报告 |
| missing-field | schema 校验失败 |
| bad-confidence | 越界值被拒绝或按契约规范化 |
| unknown-evidence | 拒绝未知/未发送 ID |
| unsafe-action | 标记为需人工确认，不提供自动执行 |
| secret-echo | 日志与导出中不出现测试 secret |

建议验收命令：

```text
python tools/viewer/ai_debug_validate.py provider
python tools/viewer/ai_debug_validate.py all
node --check tools/viewer/web/ai_provider.js
node --check tools/viewer/web/diagnosis_validator.js
```

真实 Provider 只用非敏感 fixture 做手工兼容验证，不作为离线发布门禁。

## 8. 完成定义

- 无网络、无真实密钥可完成全部自动回归。
- 所有非法输出测试向量均被拦截，未知 evidence 引用不会进入正式报告。
- timeout、cancel、retry 和迟到响应行为确定且可测试。
- context 裁剪不产生悬空引用，完整性告警始终保留。
- 测试 secret 在 snapshot、日志、错误和报告中的出现次数为 0。
- Provider 失败时 M27/M28 本地能力保持完整。

## 9. 留给 M30

- M30 只消费 Provider 状态和已校验结果，不直接解析厂商响应。
- UI 必须在 Ask AI 前展示 M29 请求预览并获取显式授权。
- UI 的取消和新请求操作必须使用 M29 generation/abort 语义。

## 10. 实施记录（2026-07-16）

M29 已完成硬件无关、网络无关实现。

### 10.1 已交付实现

- `tools/viewer/web/ai_provider.js`
  - 实现 `buildContext`、请求预览和固定 `PROMPT_VERSION`/`SYSTEM_PROMPT`。
  - 上下文在预算计算前脱敏；finding 与其 evidence 作为原子单元保留；data-quality finding 具有最高优先级。
  - 原始波形 sample 被转换为有界稳定区间摘要，不逐 sample 无上限外发。
  - 实现 `DisabledProvider`、多模式 `MockProvider` 和只保存凭据引用的 `RemoteProviderAdapter`。
  - `AnalysisController` 覆盖 queued、running、validating、completed、failed 和 cancelled，并使用单调 generation、AbortSignal、timeout、有界 retry 和迟到结果丢弃语义。
- `tools/viewer/web/diagnosis_validator.js`
  - 按响应大小、JSON、必需字段、类型、confidence、evidence 白名单和 action safety 顺序校验。
  - 无 evidence hypothesis 降级为低置信度 `unverified`；与本地 rule 冲突时保留并标记。
  - 未知 evidence、非法 schema、越界 confidence 和测试 secret echo 不得进入正式结果。
- `tools/viewer/fixtures/ai_debug/provider/mock_cases.json`
  - 覆盖 valid、streamed、retry-once、invalid-json、missing-field、bad-confidence、unknown-evidence、unsafe-action 和 secret-echo。
- `tools/viewer/fixtures/ai_debug/expected/provider_mock_cases.json`
  - 独立保存 Mock case 预期状态、失败原因和安全分类。
- `tools/viewer/web/ai_provider_test.js`
  - 额外覆盖 timeout、cancel、stale generation、Disabled Provider、波形摘要、原子裁剪和脱敏预览。
- `tools/viewer/ai_debug_validate.py` 与 `justfile`
  - 新增 `provider` 验证入口和 `m29-check` 发布门禁；`all` 同时执行 M27、M28、M29 回归。

### 10.2 验证结果

```text
python3 tools/viewer/ai_debug_validate.py all
  snapshot validation: PASS (4 fixtures, 6 kinds)
  diagnostic rules: PASS (12 golden cases, 10 rules)
  AI provider: PASS (12 lifecycle/validation cases)

python3 tools/viewer/protocol_parser_test.py
  PASS: OpenFPGA Debug Protocol parser test vectors passed

node --check tools/viewer/web/ai_provider.js
node --check tools/viewer/web/diagnosis_validator.js
python3 -m py_compile tools/viewer/ai_debug_validate.py
  PASS
```

验收结论：自动回归不需要网络或真实密钥；非法 Provider 输出全部被拦截；取消、超时、重试和迟到响应均有确定状态；上下文裁剪不产生悬空引用；Provider 失败时 M27 snapshot 和 M28 本地 findings 保留。
