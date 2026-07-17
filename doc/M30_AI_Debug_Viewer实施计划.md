# M30 AI Debug Viewer 实施计划

M30 将 M27–M29 的数据、规则和 Provider 能力整合为可用的诊断工作流。用户应能从异常证据创建 scope、运行本地分析、可选请求 AI、跳回原始证据并导出完整复盘包。

## 1. 目标与边界

- Web Viewer 新增 `AI Debug` 标签页。
- 完成 Scope、Evidence Preview、Findings、Hypotheses、Actions、Feedback、History 和 Export。
- 支持从 Trace、Profiler、Monitor 和 Logic Analyzer 视图发起诊断。
- 实现跨视图 evidence 跳转和高亮。
- 清晰展示本地分析与远程分析状态、错误、取消和恢复。
- 在无硬件、无网络环境通过 Inject Sample/fixture 完成完整工作流。

M30 不自动执行建议，不自动写寄存器、arm LA、下载 bitstream、运行构建或修改工程文件。

## 2. 修改文件

```text
tools/viewer/web/index.html
tools/viewer/web/app.js
tools/viewer/web/styles.css
tools/viewer/web/ai_debug_model.js
tools/viewer/web/diagnostic_snapshot.js
tools/viewer/web/diagnostic_rules.js
tools/viewer/web/ai_provider.js
tools/viewer/web/diagnosis_validator.js
tools/viewer/web/run_perf_test.py
doc/YiFPGA_AI_Debug_使用说明.md
doc/M30_AI_Debug_Viewer实施计划.md
```

## 3. 页面结构

| 区域 | 内容 |
| --- | --- |
| Scope | 当前会话、时间窗、Trace span、Profiler 异常、LA capture |
| Evidence Preview | 数量、来源、完整性、时间质量、脱敏与裁剪 |
| Analyze | Run Local Analysis、Ask AI、Cancel、状态 |
| Findings | M28 规则事实、阈值、证据和检查项 |
| Hypotheses | 支持/反证、置信度、信息缺口和验证步骤 |
| Actions | 可复制建议及“返回原功能页确认”入口 |
| Feedback | useful、not useful、实际根因和本地备注 |
| History | 当前页面会话的 snapshot/report |
| Export | snapshot JSON、diagnosis JSON、Markdown |

页面优先显示证据与结论，不复制完整 Trace/Profiler/LA 控件。

## 4. 状态与数据模型

建议状态：

```text
idle -> building_snapshot -> local_analyzing -> local_complete
     -> awaiting_consent -> queued -> running -> validating
     -> completed | failed | cancelled
```

约束：

- 新 scope 使旧的 pending request 失效，但历史中的已完成报告仍可查看。
- 当前 report 与 snapshot ID、rule version、prompt version 和 request generation 绑定。
- 切换 tab 不丢失当前分析；Clear Session 时按统一清理策略处理。
- History P0 仅保证页面会话内存在，不承诺浏览器持久化。
- 本地 finding 与 AI hypothesis 分区显示，模型结果不能覆盖规则事实。

## 5. 任务拆分

### M30.1 Scope 与预览

- 在各原始视图增加 `Diagnose` 入口并传递稳定 source_ref。
- 支持手工时间窗和当前会话 scope。
- 显示 evidence 来源计数、完整性、time alignment、脱敏和 omitted 数量。
- Ask AI 前展示 M29 的最终外发预览和 consent 开关。

### M30.2 Findings 与 Hypotheses

- finding 展示 severity、observed fact、actual/threshold、候选原因和 checks。
- hypothesis 展示低/中/高及原 confidence、支持证据、反证和 information gaps。
- 未校验、无证据或冲突结果使用明确的视觉状态。
- evidence 点击通过 M27 source_ref 跳转并短暂高亮原记录/capture/sample。

### M30.3 请求控制与错误恢复

- 按 M29 状态显示进度并提供 Cancel。
- 无密钥、离线、timeout、非法响应和迟到响应给出不同错误信息。
- Provider 失败后允许重试或继续使用本地报告。
- 分析期间不阻塞串口解析、波形交互和 Monitor 响应处理。

### M30.4 Feedback、History 与导出

- Feedback 默认只保存在本地 report 中，不自动发送给 Provider。
- Markdown 报告包含 scope、完整性、规则 finding、AI hypothesis、验证步骤、反馈和版本元数据。
- diagnosis JSON 与 snapshot 分离但引用 snapshot ID/evidence IDs。
- 重新导入导出包后，引用完整性可验证；失效链接显示为不可定位而非崩溃。

### M30.5 无硬件演示与性能

- `Inject Sample` 增加包含五类来源和可预期异常的 AI Debug 场景。
- Mock Provider 演示成功、stream、cancel 和 error。
- 为大 snapshot、快速切换 scope 和串口持续输入增加 headless 性能回归。

## 6. 验收流程

1. 注入或导入混合来源 fixture。
2. 从 Profiler 异常创建诊断 scope。
3. 查看证据、完整性和脱敏预览。
4. 运行 Local Analysis，确认 finding 可跳转至原视图。
5. 启用 Mock Provider 并显式同意后运行 Ask AI。
6. 检查 hypothesis 的证据、反证、置信度和验证步骤。
7. 取消一次请求后立即启动新请求，确认旧响应不覆盖新报告。
8. 导出三种文件并重新导入验证引用。

建议验收命令：

```text
node --check tools/viewer/web/app.js
python tools/viewer/protocol_parser_test.py
python tools/viewer/ai_debug_validate.py all
python tools/viewer/web/run_perf_test.py
```

## 7. 完成定义

- 无硬件、无网络可以完成 snapshot、local analysis、查看证据和导出。
- Mock Provider 可完整演示成功、取消、失败和恢复路径。
- 所有 finding/hypothesis evidence 引用均可跳转或明确显示不可定位原因。
- Ask AI 未经显式启用和预览确认不会发出请求。
- 分析期间 Viewer 核心数据接收和交互保持响应。
- 前五阶段页面、parser 和原有导出格式无回归。
- AI Debug 使用说明包含隐私、降级、证据语义和限制。

## 8. 留给 M31

- 用板级可控故障替代纯 fixture，验证 snapshot、规则和 AI 报告价值。
- 收集误报、漏报、引用有效性、恢复过程和人工确认根因。
- 对长稳、隐私、离线降级及前五阶段兼容做发布门禁。

## 9. 实施记录（2026-07-16）

M30 已完成页面会话级 AI Debug 工作流实现。

### 9.1 已交付实现

- `tools/viewer/web/ai_debug_model.js`
  - 整合 Snapshot、Local Rules、Provider Controller 和已校验 diagnosis result。
  - 支持 session、time window、latest LA capture scope，新 scope 会取消 pending request。
  - 实现本地分析、显式 consent、Mock AI、取消、Provider 失败降级、页面会话 History 和本地 Feedback。
  - 本地 finding 与 AI hypothesis 分区展示，confidence、冲突和 action safety 独立呈现。
  - evidence ID 通过 M27 `source_ref` 返回原功能区域并短暂高亮；无法定位时安全返回。
  - 提供 Snapshot JSON、Diagnosis JSON 和 Markdown 三种导出。
- `tools/viewer/web/index.html`、`styles.css`、`app.js`
  - 新增 AI Debug 页面区域及 Scope、Preview、Analyze、Findings、Hypotheses、Actions、Feedback、History 和 Export 控件。
  - Trace、Monitor、Profiler 和 Logic Analyzer 增加 Diagnose 入口。
  - `Clear` 同时清理 AI Debug 页面会话；切换普通视图不会丢失当前报告。
- `doc/YiFPGA_AI_Debug_使用说明.md`
  - 记录操作流程、证据语义、隐私授权、离线降级、导出和禁止自动操作边界。
- `tools/viewer/web/run_perf_test.py`
  - 在原有 11,192 frame Viewer 压力回归后执行真实浏览器 AI Debug 工作流。
  - 验证大 snapshot、本地分析、Mock Provider、报告历史和 evidence 引用完整性。
- `justfile`
  - 新增 `m30-check`，串联 M29 门禁、Viewer 性能回归和页面脚本语法检查。

### 9.2 联调修复

- 修复 `diagnostic_snapshot.js` 浏览器 factory 未传入 global root，Node 回归正常但浏览器 WebCrypto 路径失败的问题。
- evidence 稳定 ID 改用同步确定性双哈希，Snapshot 整体 SHA-256 完整性校验保持不变，避免大 session 对每条 evidence 单独调用 WebCrypto。
- Provider 裁剪原因改为有界样例和汇总计数，并预留元数据预算，防止 trimming metadata 反向撑破上下文限制。
- Headless CDP 等待覆盖异步大 snapshot 分析，不把浏览器调试通道默认超时误判为 Viewer 卡死。

### 9.3 验证结果

```text
python3 tools/viewer/ai_debug_validate.py all
  snapshot validation: PASS (4 fixtures, 6 kinds)
  diagnostic rules: PASS (12 golden cases, 10 rules)
  AI provider: PASS (12 lifecycle/validation cases)

python3 tools/viewer/web/run_perf_test.py
  11192 frames, 0 checksum error, 0 sync drop
  5919 diagnostic evidence
  local analysis: completed
  Mock Provider: completed
  hypothesis count: 1
  dangling references: 0
  history count: 2

node --check tools/viewer/web/ai_debug_model.js
node --check tools/viewer/web/app.js
  PASS
```

验收结论：无硬件、无网络可完成 Snapshot、Local Analysis、Mock AI、证据回跳和三类导出；未授权不调用 Provider；Provider 状态与本地 finding 分离；大 session 及前五阶段 Viewer 压力回归通过。
