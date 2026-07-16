# OpenFPGA Studio 第六阶段 AI Debug 实施计划

## 1. 阶段目标

根据 `OpenFPGA_Studio_发展规划.docx`，第六阶段定位为 `AI Debug`。

第六阶段承接前五阶段已经形成的结构化观测能力：

- Debug Core 提供日志、事件、Watch 和状态。
- Trace 提供带时间戳的过程时间线。
- Monitor 提供寄存器快照和受控读写记录。
- Profiler 提供吞吐、占用、延迟和帧率等统计指标。
- Open Logic Analyzer 提供触发前后的位级波形证据。

第六阶段的目标不是增加一个可以自由聊天的侧栏，而是建立一条可复现、可审计、可验证的诊断链路：把一次故障相关的日志、时间线、寄存器、性能指标、波形和工程元数据整理成统一证据包，先由本地确定性规则完成事实提取和异常检测，再由可替换的 AI Provider 生成带证据引用、置信度、验证步骤和修复建议的诊断报告。

P0 完成后，开发者应能从 Viewer 中选择一个异常时间窗或一次 Logic Analyzer capture，生成诊断快照，得到“观察到什么、可能原因是什么、证据在哪里、下一步如何验证”的结构化结果，并将输入证据和诊断报告一起导出供复盘。

## 2. 阶段原则与边界

### 2.1 必须完成

- 定义统一 `Diagnostic Snapshot` 数据模型，关联 Debug、Trace、Monitor、Profiler 和 Logic Analyzer 数据。
- 为事件、指标、寄存器和波形通道建立稳定标识，诊断结论必须能反向定位到原始证据。
- 实现本地证据提取和确定性规则引擎，P0 不依赖外部 AI 服务也能给出基础诊断。
- 提供第一批典型规则：UART/协议异常、FIFO 堵塞、吞吐下降、延迟升高、Monitor 超时、LA 触发异常和跨模块因果关联。
- 定义 Provider-neutral AI 接口，支持 `disabled`、本地 Mock 和至少一种真实 Provider 配置，但核心数据模型不得绑定某一模型厂商。
- 实现结构化提示词、输入裁剪、输出 schema 校验、超时、取消、重试和错误可见性。
- Viewer 新增 `AI Debug` 视图，支持证据选择、诊断执行、结论与证据联动、验证步骤、反馈和导出。
- 建立离线诊断数据集与 golden cases，对规则命中率、证据引用有效性、输出稳定性和降级路径进行回归。
- 完成无网络、无密钥、Provider 超时、非法输出、敏感数据保护和大证据包场景验收。
- 在真实 board demo 上注入可控故障，完成至少一轮从故障发生到诊断报告导出的闭环。

### 2.2 P0 暂不完成

- AI 自动修改 RTL、约束、Tcl、Viewer 源码或工程文件。
- AI 自动写 Monitor 寄存器、arm Logic Analyzer、下载 bitstream 或操作真实硬件。
- 把模型输出当作已验证事实，或在没有证据引用时给出确定性根因结论。
- 云端训练、用户数据聚合训练和复杂知识库平台。
- 任意厂商日志格式的全自动解析；P0 优先支持 OpenFPGA Studio 自身导出的结构化数据。
- 完整时序报告、综合网表和原理图的视觉理解；P1 再评估 Vivado/Quartus 报告适配器。
- 多用户协同、远程会话托管和企业权限系统。
- 无人工确认的修复执行。P0 只生成建议、验证步骤和可复制的操作草案。

### 2.3 安全与可信原则

- **证据优先**：每条诊断结论至少引用一条可定位证据；没有证据时必须标记为假设。
- **事实与推断分离**：报告分别展示 observed facts、inferences 和 recommended checks。
- **默认本地**：规则分析和证据包生成完全本地运行；外发 AI 请求必须由用户显式启用。
- **最小外发**：只发送当前诊断所需字段；串口号、路径、工程名和用户备注支持脱敏。
- **只读诊断**：AI 分析层不能直接访问串口、寄存器写接口、文件写接口或构建命令。
- **可复现**：记录 snapshot id、规则版本、prompt 版本、provider/model 标识和输出 schema 版本。
- **可降级**：无网络、无密钥或 Provider 故障时，规则引擎和本地报告仍可正常使用。

## 3. 总体架构

```text
Debug / Trace / Monitor / Profiler / Logic Analyzer
                         |
                         v
              Diagnostic Snapshot Builder
              - time window alignment
              - stable evidence ids
              - metadata / redaction
                         |
              +----------+-----------+
              |                      |
              v                      v
      Local Rule Engine       AI Context Builder
      - facts/anomalies       - select / rank / trim
      - correlations          - structured prompt
              |                      |
              |                      v
              |              AI Provider Adapter
              |              - disabled / mock / remote
              |              - timeout / cancel / retry
              |                      |
              +----------+-----------+
                         v
              Diagnosis Result Validator
              - schema validation
              - evidence-id validation
              - confidence normalization
                         |
                         v
                 AI Debug Viewer
              - findings / evidence
              - hypotheses / checks
              - feedback / export
```

模块职责：

- `Snapshot Builder`：从 Viewer 当前会话或导入的 JSONL/VCD 中提取指定时间窗，统一时间基准并生成不可变证据项。
- `Rule Engine`：基于明确阈值和状态机做确定性分析，输出事实、异常、关联关系和建议检查项。
- `Context Builder`：按相关性和预算选择证据，生成模型可消费但仍可追溯的上下文。
- `Provider Adapter`：隔离具体模型 API，统一请求、流式响应、取消、错误和使用量元数据。
- `Result Validator`：拒绝非法 schema、未知 evidence id、越界置信度和缺失依据的结论。
- `AI Debug Viewer`：负责用户授权、诊断状态、证据联动、反馈和报告导出，不在 GUI 主线程执行长耗时分析。

## 4. Diagnostic Snapshot 数据模型

### 4.1 顶层结构

建议使用版本化 JSON：

```json
{
  "schema": "openfpga.diagnostic_snapshot",
  "schema_version": 1,
  "snapshot_id": "ds-000001",
  "created_at": "2026-07-10T12:00:00Z",
  "time_range": { "start_tick": 1000, "end_tick": 5000 },
  "timebase": { "unit": "debug_clock", "frequency_hz": 100000000 },
  "target": {},
  "session_summary": {},
  "evidence": [],
  "redaction": {},
  "integrity": {}
}
```

`target` 建议包含：

- board、FPGA part、bitstream/build id。
- Debug Protocol version、各 feature version。
- Viewer version、channel manifest version、register map version。
- 可选 commit id；本地绝对路径默认不外发。

### 4.2 Evidence Item

所有证据统一使用：

```json
{
  "evidence_id": "ev-la-000042",
  "kind": "la_sample_range",
  "source": "logic_analyzer",
  "timestamp": 3200,
  "severity": "warning",
  "summary": "debug_tx_valid asserted while debug_tx_ready stayed low",
  "data": {},
  "source_ref": {}
}
```

P0 `kind` 至少包括：

| kind | 来源 | 说明 |
| --- | --- | --- |
| `debug_message` | Debug | 日志、Event、Watch、Status |
| `trace_span` | Trace | begin/end、duration、timeout、error |
| `monitor_transaction` | Monitor | read/write、response、timeout、error |
| `register_snapshot` | Monitor | 指定时刻的寄存器和值 |
| `profiler_metric` | Profiler | 指标窗口、当前值、基线和阈值 |
| `la_trigger` | Logic Analyzer | capture、trigger index、条件和状态 |
| `la_sample_range` | Logic Analyzer | 压缩后的关键样本区间和通道变化 |
| `transport_health` | Viewer | checksum、malformed、drop、重连统计 |
| `user_annotation` | 用户 | 现象、预期行为、复现步骤 |

`source_ref` 必须足以让 Viewer 定位到原始页面、记录、capture、sample 或寄存器事务。Snapshot 内保留原始值；给 AI 的派生摘要不能替代原始证据。

### 4.3 时间对齐

P0 遵循以下规则：

- 优先使用 Debug Core 公共 timestamp。
- Profiler window、Trace event、LA capture 均保留原始 timestamp 和换算后的统一 tick。
- 无法可靠换算的来源标记 `time_alignment = approximate/unknown`，不得伪造严格先后关系。
- 发生 timestamp wrap 时由 Snapshot Builder 显式展开，并记录 wrap count。
- 串口接收时间只作为辅助字段，不能替代 FPGA timestamp 推断硬件因果。

### 4.4 完整性与脱敏

- 对 snapshot canonical JSON 计算 SHA-256，报告中保存摘要。
- 记录缺帧、缺 chunk、capture partial、counter overflow 和未知通道。
- 导出前提供预览，列出将发送给 Provider 的字段、估算大小和已脱敏项。
- Provider 请求默认排除绝对路径、串口设备名、自由文本备注和用户自定义信号值；用户可逐项启用。

## 5. 本地规则引擎

### 5.1 规则输出

规则使用版本化 JSON/YAML 描述或等价的静态 JavaScript 对象，P0 不要求可视化规则编辑器。每次命中至少输出：

- `finding_id` 和 `rule_id`。
- severity、title 和 observed fact。
- evidence ids。
- threshold/baseline 与实际值。
- possible causes，明确标注为候选原因。
- recommended checks。

### 5.2 P0 规则集

| 规则组 | 典型条件 | 输出重点 |
| --- | --- | --- |
| Transport Health | checksum/malformed/drop 持续增长 | 先排除链路问题，避免误判 RTL |
| Monitor Timeout | request 无 response 或 seq 不匹配 | RX、decoder、response queue 路径 |
| FIFO Backpressure | FIFO level 高且 valid 持续、ready 低 | 堵塞窗口、上游/下游证据 |
| Throughput Drop | 当前吞吐显著低于基线 | 时间窗、busy ratio、drop 与 stall |
| Latency Spike | max/average latency 越阈值 | 对应 Trace span 和 LA 窗口 |
| Frame Stall | frame tick 缺失或周期异常 | 帧率、状态寄存器和最后事件 |
| LA Trigger Missing | 已 arm 但未触发/超时 | trigger 配置、通道变化、采样分频 |
| LA Data Integrity | chunk 缺失、sample count 不一致 | capture 完整性，不继续做强根因推断 |
| Cross-source Correlation | Trace timeout 与 FIFO/LA/Profiler 异常重叠 | 给出时间关联，避免宣称必然因果 |

阈值支持三种来源：固定默认值、工程配置和当前会话基线。报告必须显示最终使用的阈值来源。

## 6. AI 分析接口

### 6.1 Provider 抽象

建议接口语义：

```text
analyze(snapshot_summary, rule_findings, selected_evidence, options)
  -> diagnosis_result
```

Provider 配置至少包含：

- enabled、provider id、model id。
- endpoint（若适用）和凭据引用；凭据不得写入 snapshot、日志或导出报告。
- request timeout、maximum retries、evidence/token budget。
- data sharing consent 和 redaction profile。

P0 必须提供：

- `DisabledProvider`：仅运行本地规则。
- `MockProvider`：用于无网络回归、流式 UI 和错误注入。
- `RemoteProviderAdapter`：真实服务适配入口，具体实现与配置隔离。

### 6.2 输入策略

- 先发送 session summary、规则 finding 和高相关证据摘要。
- 波形不得逐 sample 无上限发送；先转换为边沿、稳定区间、触发附近窗口和关键通道变化。
- 超出预算时按完整性告警、异常严重度、时间接近度和跨来源相关性排序裁剪。
- 裁剪结果必须记录 omitted evidence count；模型不得被告知未提供证据的具体内容。
- 提示词明确要求模型只依据输入证据，不虚构未观测信号、寄存器、时序或工具结果。

### 6.3 结构化输出

`diagnosis_result` 至少包含：

```json
{
  "schema_version": 1,
  "summary": "",
  "observed_facts": [],
  "hypotheses": [
    {
      "title": "",
      "confidence": 0.0,
      "evidence_ids": [],
      "reasoning_summary": "",
      "counter_evidence_ids": [],
      "verification_steps": []
    }
  ],
  "recommended_actions": [],
  "insufficient_evidence": [],
  "metadata": {}
}
```

校验规则：

- 引用的 evidence id 必须存在于本次 Provider 输入中。
- `confidence` 只表示当前证据支持度，不显示成统计概率；UI 使用低/中/高并显示原值。
- 没有 evidence id 的 hypothesis 降级为“待验证猜测”。
- 输出解析失败时保留原始错误摘要但不把非结构化文本冒充正式报告。
- Provider 结论不得覆盖本地 rule finding；两者冲突时并列显示并标记冲突。

## 7. Viewer 实施计划

Web Viewer 新增 `AI Debug` 视图：

- `Scope`：选择当前会话、时间窗、Trace span、Profiler 异常或 LA capture。
- `Evidence Preview`：显示证据数量、完整性问题、外发字段、裁剪和脱敏结果。
- `Analyze`：分别提供 `Run Local Analysis` 和显式授权的 `Ask AI`。
- `Findings`：按严重度展示本地规则命中，点击 evidence id 跳转到对应视图。
- `Hypotheses`：展示置信度、支持证据、反证、信息缺口和验证步骤。
- `Actions`：只提供可复制建议；涉及寄存器写、下载或构建时必须返回原功能页由用户确认。
- `Feedback`：支持 useful/not useful、实际根因和备注，默认只保存在本地导出中。
- `History`：保存本次页面会话中的 snapshot/report；P0 不承诺跨浏览器持久化。
- `Export`：导出 snapshot JSON、diagnosis JSON 和 Markdown 复盘报告。

UI 与执行约束：

- Snapshot 构建、规则分析和远程请求不得阻塞 GUI 主线程。
- 远程分析必须显示 queued/running/validating/completed/failed/cancelled 状态。
- 用户可以取消请求；迟到响应不得覆盖较新的诊断结果。
- 无密钥、离线或 Provider 失败时，AI 按钮给出明确原因，本地分析保持可用。
- 诊断页不复制完整波形控件，证据点击后联动现有 Logic Analyzer/Trace/Profiler 视图。

## 8. 工程布局建议

沿用当前 Web Viewer 结构，P0 建议新增：

```text
tools/viewer/web/
  ai_debug_model.js
  diagnostic_snapshot.js
  diagnostic_rules.js
  ai_provider.js
  diagnosis_validator.js

tools/viewer/
  ai_debug_validate.py
  fixtures/ai_debug/
    snapshots/
    expected/

doc/
  OpenFPGA_AI_Debug_使用说明.md
  OpenFPGA_Studio_第六阶段AIDebug验证记录.md
  OpenFPGA_Studio_第六阶段AIDebug发布Checklist.md
```

若当前 Viewer 仍保持单文件 `app.js`，M27 可以先在现有结构中落地模型和测试；M29 前再按职责拆分，避免一次性重构影响前五阶段回归。

第六阶段 P0 原则上不新增 RTL 功能。只有在现有数据缺少稳定 build id、feature version 或公共时间基准时，才允许增加只读元数据字段，并确保旧 Viewer 和旧 bitstream 兼容。

## 9. 里程碑拆分

### M27：诊断快照与证据模型

目标：

- 固化 Diagnostic Snapshot schema、Evidence Item、时间对齐、完整性和脱敏规则。
- 从现有 Debug/Trace/Monitor/Profiler/LA 模型生成 snapshot。
- 支持选择时间窗或 capture、预览证据并导出 JSON。
- 建立 snapshot schema 校验和第一批 fixture。

交付物：

- `tools/viewer/web/diagnostic_snapshot.js`
- `tools/viewer/fixtures/ai_debug/snapshots/`
- `tools/viewer/ai_debug_validate.py` snapshot 校验入口。
- `doc/M27_诊断快照与证据模型实施计划.md`

完成判据：同一份固定会话输入重复生成的 snapshot 内容稳定，所有 evidence id 可在 Viewer 中回到原始记录，缺帧和时间不确定性不会被丢失。

### M28：本地规则引擎与 Golden Cases

目标：

- 实现版本化规则模型和 finding 输出。
- 落地 Transport、Monitor、FIFO、吞吐、延迟、Frame、LA 完整性等 P0 规则。
- 建立至少 10 个正常/异常 golden cases，覆盖单来源和跨来源关联。
- 规则报告支持阈值来源、证据、候选原因和验证步骤。

交付物：

- `tools/viewer/web/diagnostic_rules.js`
- `tools/viewer/fixtures/ai_debug/expected/`
- `tools/viewer/ai_debug_validate.py` rule regression。
- `doc/M28_本地诊断规则与GoldenCases实施计划.md`

完成判据：正常样例不产生 P0 error 级误报，异常样例命中预期规则，所有 finding 的 evidence id 和 threshold 均通过自动校验。

### M29：AI Provider、上下文构建与结果校验

目标：

- 实现 Disabled/Mock/Remote Provider 抽象。
- 实现证据排序、波形摘要、预算裁剪、脱敏和请求预览。
- 固化 prompt version 和 diagnosis result schema。
- 覆盖成功、流式响应、超时、取消、重试、非法 JSON、未知 evidence id 和迟到响应。

交付物：

- `tools/viewer/web/ai_provider.js`
- `tools/viewer/web/diagnosis_validator.js`
- Mock Provider 回归 fixture。
- `doc/M29_AIProvider与诊断结果校验实施计划.md`

完成判据：无真实密钥即可完成全部自动回归；非法或不可追溯的模型输出不会进入正式诊断报告；凭据不会出现在日志和导出文件中。

### M30：AI Debug Viewer 与诊断工作流

目标：

- 新增 AI Debug 标签页并完成 Scope、Evidence、Findings、Hypotheses、Actions、Feedback 和 Export。
- 实现跨视图证据跳转和诊断历史。
- 本地分析与远程分析状态清晰，支持取消和错误恢复。
- 导出 snapshot JSON、diagnosis JSON 和 Markdown 报告。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- AI Debug 相关 JavaScript 模块。
- `doc/OpenFPGA_AI_Debug_使用说明.md`
- `doc/M30_AI_Debug_Viewer实施计划.md`

完成判据：通过 Inject Sample 或导入 fixture，可以在无硬件、无网络环境下完成一次本地诊断；启用 Mock Provider 后可完成完整 AI 工作流且 UI 保持响应。

### M31：板级故障注入、评测与第六阶段发布

目标：

- 在 board demo 上通过已有安全控制注入可恢复故障，不为 AI 新增无保护写入口。
- 至少覆盖链路异常、FIFO/backpressure、性能退化和 LA trigger/数据完整性四类场景。
- 完成规则结果、AI 结果、人工确认根因的对照记录。
- 完成隐私、离线降级、长稳、前五阶段回归、验证记录和发布 checklist。

交付物：

- `doc/OpenFPGA_Studio_第六阶段AIDebug验证记录.md`
- `doc/OpenFPGA_Studio_第六阶段AIDebug发布Checklist.md`
- `doc/M31_板级故障注入与第六阶段发布实施计划.md`

完成判据：至少 4 类真实或可控板级异常均能生成完整 snapshot；本地规则给出可复现结果；AI 报告引用有效证据并提供可执行验证步骤；关闭 AI 后前五阶段功能和性能不退化。

## 10. 验收场景

### 10.1 无硬件与规则回归

```text
python tools/viewer/protocol_parser_test.py
python tools/viewer/ai_debug_validate.py
python tools/viewer/web/run_perf_test.py
```

至少验证：

- 正常 fixture 不产生 error 级诊断。
- 每个异常 fixture 命中预期 rule id 和 evidence id。
- snapshot schema、diagnosis schema 和 SHA-256 完整性通过。
- timestamp wrap、缺帧、LA 缺 chunk 和未知寄存器均被显式标记。
- 大 snapshot 经裁剪后仍保留完整性告警和最高优先级证据。
- 同一输入、同一规则版本产生稳定的本地结果。

### 10.2 Provider 可靠性验收

使用 Mock Provider 覆盖：

- 正常结构化结果。
- 分片/流式结果。
- 5xx、超时和重试后成功。
- 用户取消和迟到响应。
- 非 JSON、schema 缺字段、confidence 越界。
- 引用不存在或未发送的 evidence id。
- 输出中包含无依据根因结论。

预期：错误全部可见且可恢复，旧报告不被污染，本地规则 finding 始终保留。

真实 Provider 验收只验证接口兼容、授权预览和一组非敏感 fixture，不把网络可用性作为本地 P0 功能的发布阻塞项。

### 10.3 Viewer 工作流验收

1. 注入或导入包含 Debug/Trace/Monitor/Profiler/LA 的样例。
2. 从 Profiler 异常或 LA capture 创建诊断 scope。
3. 查看证据预览、完整性告警和脱敏结果。
4. 运行 Local Analysis，确认 finding 可跳转到原视图。
5. 启用 Mock Provider，运行 Ask AI 并观察状态变化。
6. 检查 hypothesis 的证据、反证、置信度和验证步骤。
7. 取消一次分析并立即开始新分析，确认迟到结果不覆盖新会话。
8. 导出 snapshot、diagnosis 和 Markdown，重新导入后引用仍有效。

### 10.4 板级验收

建议使用现有 board demo 的安全配置入口构造可恢复异常：

| 场景 | 注入方式 | 预期关键证据 | 预期诊断方向 |
| --- | --- | --- | --- |
| Transport error | 测试模式注入 malformed/checksum error | transport counters、parser error | 先检查链路，不误判用户 RTL |
| FIFO backpressure | 降低消费速率或启用 demo stall | FIFO level、valid/ready、Profiler stall | 下游反压或消费不足 |
| Throughput/latency degradation | 调整 demo duty/stall 参数 | Profiler window、Trace duration、LA window | 定位异常时间窗与关联模块 |
| LA trigger/readout anomaly | 配置不会命中的 trigger 或模拟缺 chunk | LA status、trigger config、integrity flags | 配置/完整性问题，不做强根因推断 |

每个场景记录：实际注入、人工确认根因、snapshot id、rule version、Provider/model、命中结论、有效证据、误报/漏报和恢复结果。

### 10.5 前五阶段兼容回归

- Debug/Trace/Monitor/Profiler/Logic Analyzer parser 回归全部通过。
- AI Debug 禁用时不发起任何网络请求。
- AI Debug 不改变串口收发、Monitor 写权限和 LA capture 状态机。
- 大证据包分析期间，串口接收和各 Viewer 视图保持响应。
- JSONL/VCD 原有导出格式保持兼容；新增 snapshot/diagnosis 为独立导出。


## 11. 评测指标

P0 不使用单一“AI 准确率”作为发布标准，分别评估：

| 指标 | P0 建议门槛 |
| --- | --- |
| Snapshot schema 通过率 | 自动 fixture 100% |
| Evidence 引用有效率 | 正式报告 100% |
| Golden rule 命中 | 预期 P0 rule 100% |
| 正常 golden case 的 error 级误报 | 0 |
| Provider 非法输出拦截 | 测试向量 100% |
| 无 AI 降级可用性 | 本地规则和导出 100% 可用 |
| 凭据泄漏 | 日志、snapshot、报告中为 0 |
| UI 响应性 | 分析期间串口接收和页面交互不中断 |

AI hypothesis 是否命中真实根因作为评测记录，不作为不可控的唯一发布门槛。发布门槛聚焦于证据约束、结果可追溯、错误可控和工作流价值。

## 12. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| 模型幻觉 | 给出不存在的信号或根因 | schema、evidence id 白名单、事实/推断分离、无证据降级 |
| 证据时间基准不一致 | 错误推断先后和因果 | 保留原始 timestamp、显式 alignment quality、未知时不推断 |
| 波形和日志过大 | 请求慢、费用高、上下文溢出 | 边沿/区间摘要、相关性排序、预算裁剪、遗漏计数 |
| 外发敏感数据 | 工程信息泄漏 | 默认本地、显式授权、预览、字段级脱敏、凭据隔离 |
| Provider 锁定 | 后续迁移成本高 | Provider-neutral 接口、统一 schema、Mock/Disabled Provider |
| 网络不稳定 | 核心诊断不可用 | 本地规则为基线、超时/取消/重试、清晰降级 |
| AI UI 阻塞实时数据 | 串口丢帧或界面卡顿 | Worker/异步执行、有限队列、取消、性能回归 |
| 用户把建议当自动修复 | 误操作硬件或工程 | P0 只读、操作草案与执行分离、回原功能页确认 |
| Golden cases 过于理想化 | 板级价值不足 | M31 使用真实故障注入并记录误报、漏报和人工根因 |
| 为 AI 改动 RTL 范围失控 | 破坏前五阶段稳定性 | P0 优先纯 Viewer；RTL 仅补只读版本/时间元数据 |

## 13. 推荐推进顺序

建议按 `M27 -> M28 -> M29 -> M30 -> M31` 推进：

1. 先统一证据和时间语义，使所有诊断都有稳定输入和引用目标。
2. 再建立本地规则与 golden cases，形成不依赖模型、可以自动验收的诊断基线。
3. 然后接入 Provider、裁剪和结果校验，把不可控模型限制在可替换边界内。
4. 再完成 Viewer 工作流和跨视图联动，使诊断结果真正服务于调试过程。
5. 最后用板级故障注入验证价值，并完成隐私、降级、兼容和发布收口。

这样，第六阶段交付的是一套“证据采集—确定性分析—AI 辅助推断—人工验证”的完整调试闭环。它复用前五阶段已经验证的数据面和控制面，不要求 AI 直接控制硬件，也为后续接入构建日志、时序报告、知识库和半自动修复工作流保留清晰边界。

## 14. 各里程碑独立实施计划

- `doc/M27_诊断快照与证据模型实施计划.md`
- `doc/M28_本地诊断规则与GoldenCases实施计划.md`
- `doc/M29_AIProvider与诊断结果校验实施计划.md`
- `doc/M30_AI_Debug_Viewer实施计划.md`
- `doc/M31_板级故障注入与第六阶段发布实施计划.md`
