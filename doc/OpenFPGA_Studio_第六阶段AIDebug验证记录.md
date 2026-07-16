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
| Transport error | 离线派生向量通过；板级可选 | 待板级记录 | 待执行 |
| FIFO backpressure | 实板通过：Profiler 低阈值受控注入 | demo FIFO/latency alert | enable/period/threshold 逐值恢复 |
| Throughput/latency degradation | 实板通过：有界 Profiler 场景 | demo stall/latency 超过临时阈值 | 配置恢复，UART 持续接收 |
| LA trigger missing | 实板通过：固定为 0 的 channel 31 配置 level-high | trigger 条件确定不成立 | stop 后 9 个配置寄存器逐值恢复 |
| LA data integrity | 离线派生向量通过；板级原始捕获待提供 | 待板级记录 | 待执行 |

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
