# OpenFPGA Studio v1.0 收口阶段实施计划

## 1. 阶段目标

v1.0 收口阶段不新增大功能，目标是把现有 Debug Core、Trace、Monitor、Profiler、Logic Analyzer、AI Debug 和 JTAG Transport 从“分阶段实现完成”收敛为一套边界明确、证据可审计、可以复现和发布的 Xilinx 单板候选版本。

本阶段结束时，需要能够明确回答：发布包含什么、在哪些环境验证过、哪些限制仍存在、如何复现验证、失败后如何回退。

## 2. v1.0 发布边界

v1.0 承诺：

- 支持 Xilinx `xcku5p-ffvb676-2-i` 板级 Demo。
- Debug Protocol v1 保持向后兼容。
- UART 支持 Debug、Trace、Monitor、Profiler 和 Logic Analyzer 数据/控制闭环。
- JTAG 提供 FPGA 到 Host 的批量数据通道，并明确普通功能镜像与性能镜像的差异。
- Web Viewer 支持串口/JTAG数据源、现有六类功能视图、导出和离线样例。
- AI Debug 提供确定性本地规则、Golden Cases、受校验的可选 Provider 和无网络降级路径。
- 提供离线自动回归、Vivado构建证据、板级验证记录、已知限制和回退说明。

v1.0 不承诺：

- Intel、Lattice及国产FPGA适配。
- PCIe、Ethernet、USB或SPI Transport。
- Qt Viewer。
- JTAG反向Monitor/Logic Analyzer控制面，除非收口期间补充实现并重新完成门禁。
- AI自动修改寄存器、控制硬件、构建或下载bitstream。
- 任意用户工程无需适配即可接入。

上述能力进入v1.x或后续阶段，不阻塞v1.0 Xilinx参考版本发布。

## 3. 当前基线

截至2026-07-16：

| 能力 | 当前证据 | 收口状态 |
| --- | --- | --- |
| Debug Core/UART TX | RTL、仿真、bitstream和板级持续输出 | 基本通过 |
| Trace | 协议、Probe、Viewer、仿真和板级记录 | 待整理Checklist |
| Monitor | RTL/仿真通过，真实板级ID/version读响应通过 | 写操作、错误响应和30分钟长稳待完成 |
| Profiler | Probe、Viewer、仿真和板级记录 | 待最终Checklist复核 |
| Logic Analyzer | 自动arm/trigger/readout通过 | 待人工导出确认和长稳 |
| AI Debug | 离线门禁通过，主要板级场景已执行 | 待派生损坏场景、长稳和签署 |
| JTAG | 性能镜像达到100 KB/s门槛并完成30分钟长稳 | 普通功能闭环和共存证据待补 |
| Web Viewer | 11,192帧压力回归通过，解析错误为0 | 通过 |

任何历史PASS都必须能指向命令、环境、日志或归档产物；仅有描述而无证据的项目按PENDING处理。

## 4. 工作包

### V1.WP1：版本、仓库与文档基线

- 初始化Git仓库并建立适合RTL/Vivado/Web工程的忽略规则。
- 确认源码、约束、脚本、fixture和文档纳入版本控制。
- 排除Vivado缓存、runs、bitstream、本机日志、仿真缓存和临时捕获。
- 更新README，使当前能力、限制、快速回归和文档入口与实现一致。
- 冻结v1.0协议版本、schema版本、build ID和候选提交。
- 发布前创建候选标签，正式签署后创建`v1.0.0`标签。

### V1.WP2：Monitor板级双向闭环

1. 检查USB-UART TX到FPGA `B16` 的方向、共地和LVCMOS18电平。
2. 使用ILA依次捕获`uart_rx`、字节有效、命令有效和response有效。
3. 区分物理层、UART RX、parser、寄存器窗口和TX仲裁问题。
4. 完成ID/version读取、RW/W1C/TRIGGER、非法地址和RO写入验证。
5. 完成不少于30分钟双向运行，记录checksum、timeout、drop和恢复结果。

未经ILA或引脚波形证据，不因板级超时直接修改已通过仿真的协议逻辑。

POSIX环境可先执行无依赖、只读寄存器验证：

```text
just monitor-read-validate /dev/ttyUSB1 115200 0x0000
```

该入口只发送`MONITOR_READ_REQ`，不发送Monitor写请求。

### V1.WP3：阶段Checklist一致性整理

- 逐项复核第二至第七阶段Checklist。
- 每项只能标记为PASS、FAIL、PENDING或WAIVED。
- WAIVED必须记录责任人、原因、影响和后续版本。
- 消除“自动板级验证PASS”与“板级尚未执行”等相互矛盾的表述。
- 验证记录中的环境、命令、结果和证据路径必须可对应。

### V1.WP4：Logic Analyzer与AI Debug签署

- 人工确认Viewer波形、VCD和JSONL导出内容。
- 完成LA与其他数据面共存的30分钟周期捕获。
- 将Transport损坏和LA缺chunk样例绑定到同一次脱敏板级原始捕获。
- 验证每个板级snapshot的schema、hash、规则引用和恢复baseline。
- 完成持续接收、周期诊断、取消和内存记录。
- 由发布负责人复核隐私、权限边界和已知限制。

### V1.WP5：JTAG功能候选收口

- 在JTAG-only模式完成Debug、Trace、Profiler、LA和AI Debug数据闭环。
- 记录UART/JTAG双输出Parser结果以及drop/overflow一致性。
- 验证Hardware Manager/ILA与USER2 Bridge的实际共存。
- 完成至少3次物理cable或hw_server断线恢复。
- 单独采样Bridge RSS时间序列。
- 明确普通功能镜像吞吐低于门槛的处理：优化、限制说明或从v1.0承诺中移除。

性能专用数据源的吞吐不得代替普通功能流的功能完整性证据。

### V1.WP6：统一回归与发布包

离线门禁至少包括：

```text
just parser-test
just viewer-test
just m27-check
just m28-check
just m29-check
just m30-check
just m32-check
just m34-check
just m36-check
```

已新增`just release-check`收口上述无硬件、无网络测试。Vivado综合、实现、下载和真实板级操作继续保持独立入口，避免默认命令产生硬件副作用。

发布证据至少包括：

- 测试命令、日期、工具版本和结果。
- 候选Git提交和工作区清洁状态。
- bitstream/LTX、时序、CDC、利用率和关键日志的SHA-256。
- 板卡、器件、线缆、串口、build ID和协议版本。
- 性能、长稳、重连和内存时间序列。
- 已知限制、回退步骤和Checklist签署。

## 5. 发布门禁

以下项目全部满足后才允许标记v1.0完成：

| 门禁 | 判据 |
| --- | --- |
| Git基线 | 候选提交可检出，工作区清洁，生成物未误提交 |
| 离线回归 | 所有P0命令通过，Parser错误和悬空证据引用为0 |
| Monitor | 真实板级双向读写和30分钟长稳通过 |
| Logic Analyzer | 捕获、显示、VCD/JSONL导出和周期长稳通过 |
| AI Debug | 板级/派生场景、恢复、隐私和签署通过 |
| JTAG | 发布边界内功能闭环、吞吐、共存、重连和RSS有结论 |
| Vivado | 候选配置综合、实现、时序、DRC和CDC无阻断问题 |
| 文档 | README、使用说明、验证记录、Checklist和限制一致 |
| 发布签署 | 候选产物哈希、版本标签和负责人结论齐全 |

任一P0证据缺失、数据丢失不可见、跨session拼帧、错误器件自动连接、无依据CDC豁免或权限边界被突破时停止发布。

## 6. 推荐执行顺序

1. 完成Git与文档基线，冻结候选范围。
2. 解决Monitor UART RX板级阻塞。
3. 整理阶段Checklist，暴露剩余真实缺口。
4. 完成LA和AI Debug板级长稳及签署。
5. 完成JTAG功能、ILA共存、重连和RSS证据。
6. 运行统一离线门禁与Vivado候选构建。
7. 生成候选产物、哈希和发布说明。
8. 清洁检出复验后签署并创建`v1.0.0`标签。

## 7. 完成定义

v1.0收口完成需要同时满足：

- 本文第2节承诺均有实现和可复现证据。
- 所有发布Checklist不存在未解释的空项或相互矛盾结论。
- Monitor真实双向链路不再是阻塞项。
- 离线、Vivado和板级门禁全部通过或按规则明确豁免。
- 发布候选可从Git干净检出并按文档重建。
- 已知限制没有被测试样例或性能专用镜像掩盖。
- `v1.0.0`标签指向最终签署提交，发布产物可由哈希校验。

在这些条件满足前，版本状态统一表述为“v1.0 release candidate”，不得表述为完整正式发布。

## 8. 实施记录

### 2026-07-16：WP1与WP6离线入口

- Git仓库已在`main`分支建立并同步到`Don-207/OpenFPGAStudio`。
- `.gitignore`已排除Vivado runs/cache、bitstream、DCP/LTX、日志和仿真缓存。
- README已更新为完整能力、release candidate状态、v1.0边界和阻塞项说明。
- 新增`just release-check`统一无硬件、无网络门禁；Vivado和真实板级操作保持独立。
- 基线提交为`b60b6c0`；后续收口结果使用新的提交记录，不回写正式`v1.0.0`标签。

本轮执行`just release-check`通过：

```text
Protocol parser: PASS
Snapshot validation: PASS (4 fixtures, 6 kinds)
Diagnostic rules: PASS (12 golden cases, 10 rules)
AI provider: PASS (12 lifecycle/validation cases)
Viewer stress: PASS (11192 frames, checksum/sync/unknown=0, dangling references=0)
JTAG mailbox model: PASS (7 tests)
FTDI MPSSE/backend: PASS (6 tests)
JTAG Bridge: PASS (9 tests)
M36 release validator: PASS (3 tests)
JavaScript syntax gates: PASS
```

离线门禁结论：WP6无硬件部分通过。`board qualification manifest`仍报告2项硬件签署待完成；该结果不替代WP2、WP4、WP5和Vivado候选构建。

### 2026-07-16：WP2 Monitor读路径复测

- 新增`just monitor-read-validate`，在POSIX环境使用标准库完成只读Monitor事务，不依赖PowerShell或pyserial。
- `/dev/ttyUSB1`连续接收10秒：25272 bytes、1662 frames、checksum/version error为0。
- `MONITOR_ID(0x0000)`读取PASS：`0x4F464D30`。
- `MONITOR_VERSION(0x0004)`读取PASS：`0x00010000`。
- 历史UART RX“无响应”阻塞已解除；WP2剩余写寄存器、错误响应与30分钟双向长稳。
