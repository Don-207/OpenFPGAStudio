# OpenFPGA Studio 第六阶段 AI Debug 发布 Checklist

## 自动门禁

- [x] M27 snapshot schema、hash、导入导出回归通过。
- [x] M28 P0 rules 与 12 个 Golden Cases 通过。
- [x] M29 Mock Provider 生命周期和非法输出矩阵通过。
- [x] M30 Viewer 无硬件完整工作流通过。
- [x] 正式结果 evidence 引用无悬空项。
- [x] 未授权时不调用 Provider。
- [x] Disabled/timeout/cancel/invalid output 保留本地结果。
- [x] Provider API 不暴露 Monitor write、LA command、program、build 或文件写能力。
- [x] Fixture/expected/文档敏感模式扫描通过。
- [x] Protocol parser 与 Viewer 压力回归通过。
- [x] README、使用说明、验证记录和可复现命令齐备。

## 板级与发布签署

- [x] 记录 JTAG target、device、bitstream、build ID、协议和 Viewer 版本；板卡商品型号仍待补。
- [x] FIFO/backpressure 场景完成注入、采集、人工根因和恢复闭环。
- [x] Throughput/latency 场景完成注入、采集、人工根因和恢复闭环。
- [x] LA trigger missing 场景完成注入、采集、人工根因和恢复闭环。
- [ ] Transport 或离线派生损坏场景绑定同一次脱敏板级原始捕获。
- [ ] LA 缺 chunk 派生场景绑定同一次脱敏板级原始捕获。
- [ ] 每个板级 snapshot schema/hash 通过，规则命中且引用有效。
- [ ] 每个注入场景恢复到记录的正常 baseline。
- [ ] 完成不少于 30 分钟持续接收与周期诊断并记录数据量、drop、内存和取消次数。
- [x] AI Disabled 条件下复测 UART/JTAG 数据面，UART checksum/version error 为 0。
- [ ] 发布负责人复核已知限制并签署第六阶段板级发布。

发布结论：当前自动门禁通过；板级条目未签署，不得标记为完整板级发布。
