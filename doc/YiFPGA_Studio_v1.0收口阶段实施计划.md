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
| Trace | 协议、Probe、Viewer、仿真、候选镜像构建/下载和板级记录 | WP3复核完成 |
| Monitor | RTL/仿真、真实读写/错误响应、控制行为和30分钟长稳通过 | WP2完成 |
| Profiler | Probe重复累计缺陷已修复；离线回归、候选构建/下载、30分钟板级长稳和Edge视觉签署通过 | WP3复核完成 |
| Logic Analyzer | 自动arm/trigger/readout、30分钟长稳、Edge波形及VCD/JSONL导出签署通过 | WP3复核完成 |
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
just monitor-safe-validate /dev/ttyUSB1 115200
just monitor-soak /dev/ttyUSB1 115200 1800 1
```

`monitor-read-validate`只发送`MONITOR_READ_REQ`。`monitor-safe-validate`短暂修改LED低2位并保证恢复，用于验证RW、RO拒绝和非法地址；`monitor-soak`只周期读取ID，不写寄存器。

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

2026-07-17 补充：M36 normal build 的 JTAG 普通功能流已取得 Debug/Trace/Profiler/LA
原始捕获，14,051 帧且 JTAG checksum/version error 为 0；Bridge RSS 30 秒采样无增长。
双输出窗口的字节数与类型分布接近，但 UART 出现 checksum error 且 drop 计数增长，故
双输出完整性、3 次物理重连和真正并发 ILA/USER2 仍是 WP5 未关闭项。普通功能镜像约
0.884 KB/s，不纳入 100 KB/s 承诺；性能门槛仍仅适用于 performance build。

同日已完成严格功能 JTAG-only+ILA 构建：`ENABLE_UART=0`、`JTAG_PERF_MODE=0`，
WNS `+3.003 ns`、TNS `0`、WHS `+0.013 ns`、DRC `0 error`。该结果只关闭构建缺口，
板级 JTAG-only 功能闭环仍以下载和实测结果为准。

严格 JTAG-only 镜像随后完成精确目标下载与板级验证：UART RX 命令经 JTAG 返回
Monitor 响应，并收到 Debug、Trace、Profiler、LA 全部功能类型；完整 capture 9,112 帧，
checksum/version/sync error 均为 0，配置恢复成功。V1.WP5 的 JTAG-only 功能闭环据此关闭。

随后完成 FT232H cable 三次物理断线恢复：Bridge reconnects=3，90.032 秒持续收到
51,428 B，session 未变化且 overflow/drop/slow-client 均为 0。V1.WP5 的物理重连项据此关闭。

normal 双输出最终复核中，UART 3,360 帧与 JTAG 逐帧按序匹配，对齐率 100%，两路
checksum/version error 均为 0，drop/overflow 在受控窗口内不增长。Hardware Manager raw
USER-DR adapter 当前未实现，v1.0 将同线缆真并发明确列为不支持；独立 chain 与释放线缆后
交替恢复已经验证。V1.WP5 据此按已冻结发布边界完成收口。

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
- 安全suite PASS：`LED_CONTROL`掩码写入、读回和原值恢复通过；RO写返回`DENIED(2)`，非法地址返回`BAD_ADDR(1)`。
- 60秒双向soak冒烟PASS：60次周期读、timeout=0、checksum error=0；随后继续执行正式1800秒门禁。
- 正式1800秒双向soak PASS：1800次周期读、timeout=0、checksum error=0；启动`sync_drops=2`且全程未增长。
- Monitor发布Checklist现已全部勾选；随后专项验证也覆盖`DEMO_PERIOD`和`CLEAR_COUNTERS`，避免用ID轮询替代全部寄存器语义。

### 2026-07-16：WP2 Monitor完成

- `DEMO_PERIOD`可写、可读回、写0返回`BAD_VALUE(5)`，且测试后恢复原值10,000,000。
- `CLEAR_COUNTERS`触发后`COUNTER0`从4,189,421,936回落到375,120，证明真实清零脉冲生效。
- WP2的身份读取、RW、RO拒绝、非法地址、非法值、Trigger、恢复和1800秒双向长稳均已通过。
- 下一步：执行WP3，统一复核第二至第七阶段Checklist与验证记录，按PASS/FAIL/PENDING/WAIVED消除矛盾状态。

### 2026-07-16：WP3第二阶段Trace复核

- 第二阶段Checklist已统一为PASS/PENDING/WAIVED，原32个未勾选项不再被误读为全部未实现。
- 当前Parser、Viewer、M9 XSim、M10 XSim和完整顶层Vivado elaboration通过。
- WP3复跑发现并修复Monitor默认周期覆盖Board Demo仿真参数的回归；真实板默认周期不变。
- 更新陈旧的M10 elaboration文件清单，使其覆盖当前Profiler、LA和JTAG顶层依赖。
- 当前WP3 RTL的M36 JTAG+ILA候选镜像已重新构建：WNS `+3.298 ns`、TNS `0`、未布线网络 `0`、DRC `0 error`；bitstream与LTX哈希已记录在Trace验证记录。
- 候选镜像已下载到`Digilent/210512180081`的`xcku5p_0`，启动状态HIGH并枚举1个ILA；JTAG build ID为`0x4D360001`。
- 候选镜像UART采样确认Trace ID `0x0001..0x0004`、DMA timeout状态均到达Host；750个STATUS帧的`drop_count`始终为0。
- Windows Microsoft Edge `150.0.4078.65`正式版本（64位）截图确认四泳道渲染和DMA timeout高亮；由截图发现并修复32位timestamp回绕造成负duration的问题，Parser与Viewer压力回归通过。
- 第二阶段Trace Checklist无PENDING或FAIL项，WP3 Trace复核完成；下一项为第四阶段Profiler Checklist复核。

### 2026-07-16：WP3第四阶段Profiler复核

- 更新Profiler一键回归与POSIX板级长稳入口，Parser、Viewer压力、M18、M19、M21和Vivado elaboration通过。
- 首次旧候选1800秒运行暴露FIFO metric重复累计并将overflow计数推至65,535；该次结果明确记为FAIL并用于定位，不以checksum/drop为0掩盖功能错误。
- 修复FIFO probe仅在level变化、读写和异常事件时发出metric，并加入稳定level不得重复发出的XSim断言。
- 重新构建并下载当前M36 UART+JTAG+ILA候选：WNS `+3.522 ns`、TNS `0`、未布线网络`0`、DRC `0 error`。
- 修复镜像120秒预检和1800秒正式长稳均通过；正式窗口得到7,203个snapshot、1,801个alert、90,000个status，checksum error与设备drop均为0，FIFO overflow峰值为0，原始配置恢复成功。
- Windows Edge Profiler视图人工确认通过：99 snapshots、49 alerts、0 malformed，四类指标、趋势、alert和控制区均正常显示。
- 第四阶段Profiler Checklist无PENDING或FAIL项，WP3 Profiler复核完成；下一项为第五阶段Logic Analyzer Checklist复核。

### 2026-07-16 至 2026-07-17：WP3第五阶段Logic Analyzer修复审计

- 恢复并扩展 POSIX LA 板级验证器，覆盖两次采集、stop/clear/re-arm、配置恢复、
  checksum、malformed、overflow、Profiler snapshot 和 Debug Core `drop_count`。
- 旧镜像快速采集功能通过，但 60 秒共存预检暴露 `drop_count` 持续增长；该结果记为
  FAIL，不以采集帧完整掩盖链路拥塞。
- 修复 Debug Core 对可回压 `valid` 的重复丢包计数，并在仲裁中为 Legacy pulse
  保留 FIFO 余量；双槽预留会阻塞 LA 尾帧，最终设计收敛为单槽预留。
- 修正 Board Demo 默认 Watch/Status 频率，使默认流量符合 115200 baud 容量。
- 修正 LA 验收脚本 Profiler 周期单位错误：`100,000,000` 个 100 MHz 周期才是 1 秒。
- 为 Trace Adapter 增加一项 pending，避免单周期 Trace 在下游背压时直接丢失。
- 断电恢复后确认 CH340 `/dev/ttyUSB1`、Digilent FT232H/JTAG 和 `brltty` inactive；
  位流构建、指定 target 下载和 ILA 枚举链路恢复正常。
- 多个中间 M36 镜像均完成正 WNS、0 未布线网络和 DRC 0 error；最新源码仍需重新
  构建和板测，故 WP3 Logic Analyzer 当前状态保持 `IN PROGRESS`。
- 下一步：构建/下载最新单槽+Trace pending 镜像，依次执行快速验证、60 秒预检和
  1800 秒正式长稳；之后再进行 Edge 波形与 VCD/JSONL 人工签署。
- 2026-07-17 最新单槽镜像快速验证和 60 秒预检已通过；1800 秒运行在 300 秒时
  因 `drop_count 1->4` 判定 FAIL 并停止，checksum/overflow/malformed 仍为 0。
  下一修复为在已降载并带 Trace pending 的前提下恢复双槽 FIFO 余量，然后重新执行门禁。
- 2026-07-17 双槽候选构建 WNS `+3.210 ns`；快速验证和 60 秒预检均 PASS，
  60 秒窗口 `drop_count 1->1` 且 checksum/overflow/malformed 为 0。下一步执行
  同参数 1800 秒正式长稳。
- 带宽感知调度版正式长稳的 5/10/15 分钟门禁通过，但约 18 分钟后 LA readout
  尾帧停滞，故仍记为 FAIL。根因是 16 项 FIFO 小于一次 16 帧 LA readout 加后台
  最坏突发；Board Demo FIFO 已扩展为 64 项，待重新构建和执行门禁。
- 64 项 FIFO 候选构建 WNS `+4.315 ns`，快速验证与 60 秒预检均 PASS；下一步
  使用同一镜像执行 1800 秒正式长稳。
- 64 项 FIFO 候选 1800 秒正式长稳 PASS：62 次采集，最终 `capture_id=62`，
  `drop_count 0->0`，checksum/overflow/malformed 为 0，Profiler snapshot 723，
  所有临时配置恢复成功。WP3 Logic Analyzer 自动板级长稳门禁完成；剩余 Edge
  波形/触发线/通道名和 VCD/JSONL 导出人工签署。
- Windows Edge 人工验收发现并修复 Viewer Monitor 并发写入争用 writer lock、LA Apply
  遗漏 `LA_CONTROL` 使能两项缺陷；回归测试通过。真实板采集 `capture_id=0x3F`、
  64 samples、13/13 chunks、malformed=0，波形、触发位置和 11 路通道名签署通过；
  随后以合法 divisor `50000` 重采 capture `0x42`，VCD/JSONL 的64 samples、
  13个连续chunks、触发标记、通道名和零错误计数全部通过。第五阶段 WP3 复核完成。

### 2026-07-17：WP3第六阶段AI Debug复核启动

- 将第五阶段 capture `0x42` 的脱敏 JSONL 作为共同板级原始证据，完成 Transport checksum/malformed 与 LA 缺 chunk 两类离线派生 snapshot 绑定。
- 新增门禁校验原始捕获 SHA-256、snapshot schema/hash、派生与 baseline 关系、规则命中、禁止规则、evidence 引用和未修改 baseline 恢复。
- 第六阶段 Checklist 的两项派生证据绑定已完成；下一步为补齐其余实板场景 snapshot、执行不少于30分钟周期诊断长稳并完成发布签署。
- 板卡恢复后的 LA trigger-missing 复测暴露 `LA_STATUS[2:0]` 将互斥状态当作粘滞位 OR 的缺陷；配置已完整恢复，失败结果保留。RTL 已改为低三位实时状态、高位粘滞/W1C，并由 `la-board-sim` 新断言覆盖。下一步需重建并下载候选镜像后复测。
- 修复候选构建 WNS `+2.907 ns`，0 warning/error，指定 target 下载和 ILA 枚举通过；10 秒 UART 纯接收、Profiler 受控场景及 LA trigger-missing 实板复测均 PASS，临时配置完整恢复。下一步执行第六阶段 1800 秒持续接收与周期诊断门禁。
- 修复镜像 1800 秒 LA/Profiler 共存长稳 PASS：62 次采集、最终 capture ID 63、720 个 Profiler snapshots，checksum/drop/overflow/malformed 全为 0。硬件持续接收门槛完成；第六阶段组合条目仅余 Viewer 内存与取消次数度量及最终签署。
- Chromium 补测记录 11,194 frames、5,920 evidence、heap used 21,174,608 bytes、5 次取消全部正确收敛并保留本地 finding；与 1800 秒硬件结果合并后，第六阶段组合长稳条目完成。
- 五类 AI Debug 场景现全部绑定可复现 snapshot 和 baseline：Performance 使用等长窗口的受控 `DEMO_PERIOD` 注入，吞吐帧率 10.0/s→0.1/s，配置恢复通过。Release 门禁验证 5/5 源哈希、snapshot hash、规则、引用和恢复；第六阶段仅待发布负责人签署。
- 2026-07-17 发布负责人确认签署；第六阶段 AI Debug 自动门禁、五类板级场景、恢复、组合长稳和已知限制复核全部完成，WP3 第六阶段复核收口。
