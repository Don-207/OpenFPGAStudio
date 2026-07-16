# M36：ILA 共存与第七阶段发布实施计划

## 1. 里程碑目标

完成构建矩阵、ILA/debug hub 共存、板级功能、性能、断线恢复和 30 分钟长稳验收，形成第七阶段可审计的发布证据和限制说明。

## 2. 前置条件

- M32–M35 交付物、自动化测试和文档均已完成。
- 已确定目标板卡、器件、线缆、Vivado 版本、bitstream 和推荐 JTAG 参数。
- 综合、实现、bitstream、下载及板级测试分别在执行前获得用户确认。

## 3. 验收阶段

### WP1：构建矩阵

验证四种配置：UART、JTAG、`UART_AND_JTAG`、JTAG disabled；另验证 JTAG-only、ILA-only、JTAG+ILA 三种 debug 资源组合。

每种配置记录：参数、USER chain、BSCAN/debug hub 资源、BRAM/LUT/FF/BUFG、WNS/TNS、关键警告和产物哈希。

### WP2：静态与实现检查

- elaboration、综合、实现和时序通过。
- CDC 报告与设计结构一致，无未约束多 bit 跨域和无依据 false path。
- JTAG disabled 构建裁剪 BSCAN/BRAM，前六阶段功能与 UART 行为无回归。
- JTAG 与 ILA 使用独立、明确的 USER chain；工具或器件限制必须写入发布说明。

### WP3：板级功能闭环

1. 枚举并显式选择 cable、device 和 USER chain。
2. 校验 mailbox magic/version/session/build id。
3. JTAG-only 验证 Heartbeat、Debug、Trace 和 Profiler。
4. 触发 LA capture/readout，校验波形完整并可导出。
5. 生成 AI Debug snapshot，校验 transport health 和原始证据。
6. 停止并重启 Bridge，校验 overflow/drop 和合法帧恢复。
7. 断开 cable 或 hw_server，至少完成 3 次恢复。
8. ILA 与 Host Bridge 同时使用，验证枚举、触发和读取互不抢占。
9. 双输出下分别比较 UART/JTAG Parser 记录和链路统计。

### WP4：性能矩阵

对 256 B、512 B、1 KB、2 KB、4 KB block 及可用 TCK 记录：有效吞吐、P50/P99 延迟、Host CPU、buffer used、drop/overflow。

发布配置必须达到持续 100 KB/s，且给出瓶颈、推荐参数和复测命令；瞬时峰值不计入门槛。

### WP5：30 分钟长稳

- Debug/Trace/Profiler 持续输出，周期性执行 LA capture。
- Bridge/Viewer 无死锁、崩溃或持续内存增长。
- 数据源未超载时 drop/overflow 不持续增长；超载时计数准确且 UI 可见。
- 长稳期间 ILA 可触发和读取。
- 至少 3 次断线重连均恢复到合法 session/帧边界。

### WP6：发布收口

- 汇总自动化日志、构建报告、资源/时序、性能 CSV、长稳日志和截图。
- 检查协议版本、build id、使用说明、已知限制和回退步骤一致。
- 发布 checklist 每项标注通过、失败或豁免；豁免必须有责任人、原因和影响。

## 4. 发布完成判据

- M32–M35 交付完整，文档和实现一致。
- UART 与 JTAG 任一路阻塞不会拖死另一条链路。
- JTAG-only 完成 Debug/Trace/Profiler/LA/AI Debug 数据闭环。
- 自动化测试、CDC、综合、实现和时序均通过。
- ILA 共存通过，或明确记录无法共存的构建期限制，且无 USER chain 静默冲突。
- 板级持续吞吐不低于 100 KB/s，30 分钟长稳及 3 次重连通过。
- 多目标场景始终要求显式选择，未连接错误器件。

## 5. 交付物

- `doc/OpenFPGA_Studio_第七阶段JTAG高速调试传输验证记录.md`
- `doc/OpenFPGA_Studio_第七阶段JTAG高速调试传输发布Checklist.md`
- 本实施计划
- 构建、时序、CDC、资源、性能和长稳原始记录

当前自动化入口：`just m36-check`、`just m36-matrix` 和 `just m36-soak`。
验证记录和 Checklist 中未勾选的板级项不得由离线回归替代。

## 6. 停止发布条件

出现数据丢失但计数不可见、跨 session 拼帧、错误目标自动连接、无依据 CDC 豁免、ILA/Transport USER chain 冲突、持续内存增长或吞吐未达 100 KB/s 时停止发布。修复后从受影响的最早工作包重新验证，不以文档豁免代替数据完整性要求。
