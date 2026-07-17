# OpenFPGA Studio 第五阶段 Open Logic Analyzer 验证记录

## 实现状态

M22–M25 已完成协议、RTL Core、Viewer 和 board demo 接入。M26 新增统一回归入口、LA 串口验证器、发布 bitstream 入口和安全的 JTAG target 选择。

## 发布信息

| 项目 | 内容 |
| --- | --- |
| FPGA part | `xcku5p-ffvb676-2-i` |
| Board | JTAG target `Digilent/210512180081`，FPGA `xcku5p_0`；板卡商品型号/版本待补 |
| Vivado version | `2020.2`（RTL elaboration） |
| Bitstream path | `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m26.bit`（15431260 bytes，2026-07-10 17:02:51） |
| Build command | `just la-bitstream` |
| Commit id | 当前目录未识别为 Git 工作树，待在仓库根目录填写 |
| UART | `COM8`，`115200 8N1` |
| LA depth/divisor | 验证器默认 `64 / 4` |

## 自动回归

短回归入口：

```text
just m26-check
```

单项命令可通过 `just --list` 查看。Vivado elaboration 和 bitstream 构建是独立确认门，不包含在短回归中。

| 检查项 | 命令 | 状态/证据 |
| --- | --- | --- |
| Parser | `just parser-test` | PASS：`OpenFPGA Debug Protocol parser test vectors passed` |
| Viewer 无硬件样例 | `just viewer-test` | PASS：11192 frames，checksumErrors=0，LA capture=1，LA channels=11 |
| LA 验证器离线自测 | `just la-validator-self-test` | PASS：`OpenFPGA Logic Analyzer validator self-test passed` |
| M23 Core XSim | `just la-core-sim` | PASS：`OpenFPGA Logic Analyzer M23 core capture checks passed` |
| M25 Board XSim | `just la-board-sim` | PASS：`OpenFPGA Logic Analyzer M25 board demo checks passed` |
| M25 RTL elaboration | `just la-elab` | PASS：0 warnings，0 critical warnings，0 errors |
| M26 bitstream | `just la-bitstream` | PASS：WNS +3.945 ns，TNS 0，0 failing endpoints |

## Bitstream 构建核验

2026-07-10 手动执行 `just la-bitstream`，成功生成：

```text
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m26.bit
size: 15431260 bytes
timestamp: 2026-07-10 16:45:22
```

实现报告结论：

- Route：11446/11446 routable nets fully routed，0 routing errors。
- Setup timing：未闭合，WNS `-14.194 ns`、TNS `-155.050 ns`、21 failing endpoints。
- Hold/Pulse width：无违例。
- Setup 违例集中在 `u_latency_profiler_probe` 的 `complete_count` 到 `metric_value3` 路径；RTL 对应可变 32-bit 除法 `next_latency_sum / next_complete_count`，最差路径 181 级逻辑。
- DRC：1 个 `RTSTAT-10 No routable loads` warning，涉及 Vivado `dbg_hub/u_ila_monitor` 内部网络；无 routing error。

上述结果对应 16:45 的首次镜像；该镜像仅完成写出但未满足 M26 发布时序门槛，现已被后续修复后镜像替代。

## Timing 修复

2026-07-10 已将 `openfpga_profiler_latency` 的单周期可变 32-bit 除法替换为 32 周期 restoring divider：

- 平均值仍为精确整数 `floor(latency_sum / complete_count)`，协议字段不变。
- 完成事件的 `metric_valid` 延迟 32 个 `sys_clk` 周期；board demo 既有 pending 机制负责接收。
- 除法期间锁存 numerator、divisor 和 metric values，阻止新测量覆盖在途结果。
- 单周期关键路径由最高 181 级组合除法缩短为 33-bit 比较/减法。

修复后已通过：

- `PASS: OpenFPGA Profiler M19 probe checks passed`
- `PASS: OpenFPGA Profiler M21 board demo checks passed`
- `PASS: OpenFPGA Logic Analyzer M25 board demo checks passed`

以下重新实现结果用于确认修复后的 timing closure；前述负 WNS/TNS 仅保留为问题定位记录。

### 修复后重新实现结果

2026-07-10 17:02 完成重新实现：

- Bitstream：`openfpga_debug_board_demo_m26.bit`，15431260 bytes。
- SHA-256：`D3E4774B2ED70631CE8D97D2AF5B18DE73A73094CD3D68EAB8FBE424B3D4299C`。
- Setup：WNS `+3.945 ns`，TNS `0.000 ns`，0 failing endpoints。
- Hold：WHS `+0.011 ns`，THS `0.000 ns`，0 failing endpoints。
- Pulse width：WPWS `+4.458 ns`，TPWS `0.000 ns`，0 failing endpoints。
- Route：10466/10466 routable nets fully routed，0 routing errors。
- DRC：保留 1 个 Vivado `dbg_hub/u_ila_monitor` 内部网络的 `RTSTAT-10 No routable loads` warning；不涉及用户 RTL 路由错误。

结论：Profiler 除法时序阻塞已消除，新 M26 bitstream 满足现有用户时序约束，可进入下载和板级验收阶段。

## 板级验收

下载和串口验证均属于硬件操作，执行前确认 JTAG target、串口和板卡状态。

```text
just la-program "*JTAG目标序列号*"
just la-board-validate COM7 115200
```

验证器覆盖 LA ID/version、配置读回、arm、force trigger、done、readout、header/data/status 帧、capture_id 递增和 clear。Viewer 波形显示及 VCD/JSONL 文件内容仍需人工验收并在下表签字。

| 日期 | Board/串口 | arm/trigger/readout | Viewer | VCD | JSONL | 结论/证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-10 | `xcku5p_0` / COM8 | PASS，capture_id=4 | 待人工确认 | 待人工确认 | 待人工确认 | header=1，trigger=1，data=13，status=1，checksum=0 |
| 2026-07-17 | `xcku5p_0` / Windows Edge | PASS，capture_id=`0x3F` | PASS | 待人工确认 | 待人工确认 | 64 samples，trigger=0，13/13 chunks，11 路通道正常，malformed=0 |
| 2026-07-17 | `xcku5p_0` / Windows Edge | PASS，capture_id=`0x42` | PASS | PASS | PASS | divisor=50000，64 samples，13/13 chunks，error/malformed/missing/out-of-order/drop=0 |

### 自动板级验证记录

- JTAG target：`localhost:3121/xilinx_tcf/Digilent/210512180081`。
- 下载结果：`PASS: Programmed xcku5p_0 with .../openfpga_debug_board_demo_m26.bit`，startup status HIGH。
- 串口命令：`python tools/viewer/logic_analyzer_validate.py --port COM8 --baud 115200`。
- 串口结果：`PASS: OpenFPGA Logic Analyzer board validation passed`。
- 观测：`LA_VERSION=0x00010000`，`capture_id=4`，header/data/status/trigger=`1/13/1/1`，checksum errors=`0`。
- 首次诊断暴露验证器会在 Monitor response 后丢弃同批后续帧；已修复为处理完整 decoded batch 后返回，离线自测与真实链路复测均通过。

## 30 分钟共存长稳

| 时间 | checksum error | dropped frames | LA overflow | malformed | capture_id | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 min |  |  |  |  |  |  |
| 5 min |  |  |  |  |  |  |
| 10 min |  |  |  |  |  |  |
| 15 min |  |  |  |  |  |  |
| 20 min |  |  |  |  |  |  |
| 25 min |  |  |  |  |  |  |
| 30 min |  |  |  |  |  |  |

2026-07-17 使用 64 项共享 FIFO 候选完成正式运行；记录如下：

| 时间 | checksum error | dropped frames | LA overflow | malformed | capture_id | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 min | 0 | 0 | 0 | 0 | 2 | 两次初始完整采集 |
| 5 min | 0 | 0 | 0 | 0 | 12 | 12 captures |
| 10 min | 0 | 0 | 0 | 0 | 22 | 22 captures |
| 15 min | 0 | 0 | 0 | 0 | 32 | 32 captures |
| 20 min | 0 | 0 | 0 | 0 | 42 | 越过旧版约18分钟失败点 |
| 25 min | 0 | 0 | 0 | 0 | 52 | 52 captures |
| 30 min | 0 | 0 | 0 | 0 | 62 | PASS，Profiler snapshots 723 |

正式命令：

```text
just la-soak /dev/ttyUSB1 115200 1800 30
```

最终结果：`capture_id=62`，62 次采集，`drop_count 0->0`，checksum error、
LA overflow、malformed 均为 0，Profiler snapshot 723；结束后 LA、Profiler 和
Demo 配置恢复 PASS。64 项 FIFO 候选的 30 分钟自动共存长稳门禁通过。

自动板级采集与 30 分钟共存长稳已完成。Windows Edge Viewer 波形、触发位置和
11 路通道名人工检查通过；VCD/JSONL 导出仍待人工检查，完成前保持候选发布状态。

Windows Edge 首次人工验收中，Monitor 单次读取正常但 LA 按钮无响应。定位并修复
Viewer 的两项控制面缺陷：Monitor 并发写入争用 Web Serial writer lock，以及 Apply
遗漏写入 `LA_CONTROL (0x0068)` 使能位。修复后 Apply 会串行写入控制与配置寄存器；
Mask 等非 Disabled 模式写入 `0x00000005`，Disabled 模式写入 `0x00000001`。
Viewer 回归为 11,194 frames、checksum/sync drop/unknown 均为 0，随后真实板人工采集通过。

最终导出复核使用合法的 16 位 divisor `50000`。JSONL 共 556 条，包含 1 个 header、
1 个 trigger、13 个连续 sample chunks（索引 0–12）、1 个 status 和 1 个 parser
counters；capture_id=`0x42`、64 samples、13/13 chunks，error、malformed、missing、
out-of-order、dropped 均为 0。VCD 共 794 行，包含 11 路命名信号和 trigger marker，
时间点覆盖 `#0` 至 `#63`。归档校验值：

- `openfpga-la-0x00000042-1784268893553.vcd`：SHA-256 `2e8a61430d8a6c1926c92ffc48dcfb6e66b17f8e70ffc69ee0f49946a39090ea`
- `openfpga-debug-1784268897418.jsonl`：SHA-256 `f161dd54cac33a7a237d5700305047ad3d9e9c25808228046d6ab3c4753ad4d8`

第五阶段 Logic Analyzer 自动板测、30分钟共存长稳、Windows Edge 波形与
VCD/JSONL 导出均已签署通过。

## 2026-07-16 至 2026-07-17：v1.0 收口复测与修复记录

本轮使用当前 M36 UART+JTAG+ILA 候选镜像复核第五阶段。硬件为
`Digilent/210512180081` / `xcku5p_0`，Linux 串口为 CH340
`/dev/ttyUSB1`，Vivado 为 2024.2。

### 已确认的基础能力

- 旧镜像快速验证曾通过两次完整采集：`capture_id 0->1->2`，每次
  `header/data/status/trigger=1/13/1/1`，checksum error 为 0。
- `stop/clear/re-arm`、配置保存与恢复均通过。
- M36 构建和下载链路可重复；断电恢复后 USB 映射确认 CH340 为
  `/dev/ttyUSB1`，FT232H 为 Digilent JTAG，`brltty` 服务保持 inactive。
- 2026-07-17 08:59 构建的中间镜像 WNS 为 `+3.210 ns`，下载后 FPGA
  startup status HIGH，并枚举 1 个 ILA。

### 失败现象与根因链

1. 旧实现 60 秒共存预检出现 `drop_count 521->32730`。根因是 Debug Core
   把可回压的 LA/Trace/Profiler `valid` 在 FIFO 满期间按每拍重复计为丢包。
2. 仅修正重复计数后仍有少量增长。根因包括不可回压 Legacy 消息与可回压流
   同周期竞争，以及流式突发占满 FIFO 后没有 Legacy 写入余量。
3. 加入双槽预留后 LA readout 在水位处停滞；因此收敛为单槽预留。
4. Board Demo 默认 Watch 10 ms、Status 20 ms，单是两路就超过 115200 baud
   的物理容量；默认值已调整为 Watch 50 ms、Status 100 ms。
5. 验收脚本曾把 Profiler 的 `1,000,000` 个 100 MHz 周期误认为 1 秒，实际为
   10 ms；已修正为 `100,000,000` 周期。
6. Trace Adapter 原先没有保持寄存器，单周期 Trace 事件遇到 `ready=0` 就丢失；
   已增加 1 项 pending，只有 pending 已占用且又到达新事件才报告真正丢失。
7. LA divisor=4 时，16 个预触发样本在串口 Force Trigger 到达前必然循环覆盖，
   造成 Header/Status overflow 标志；验收参数已改为适合串口控制延迟的采样周期。
8. 启动配置和轮询产生的 Status 队列会污染稳定期基线；验证器现先排空启动帧，
   再建立 `drop_count` 基线。

### 当前代码修复

- Debug Core 仲裁按消息是否可回压分层，并为 Legacy pulse 保留一个 FIFO 槽位。
- Trace Adapter 增加单项保持寄存器。
- Board Demo 默认输出频率限制在 UART 可承载范围内。
- LA validator 支持 POSIX 串口、配置恢复、重复采集、Profiler 共存、稳定期
  `drop_count`、checksum、overflow、malformed 和 soak 统计。
- `justfile` 增加 `debug-core-sim`、`la-board-validate` 和 `la-soak` 等可复现入口。

### 当前结论

中间失败均保留为问题定位证据，不能作为发布 PASS。最新源码已完成单槽预留、
UART 安全默认速率、Profiler 1 秒窗口和 Trace pending 修复，但尚需重新构建下载。
下一门禁为：最新镜像快速验证通过后执行 60 秒预检，再执行 1800 秒正式共存长稳。

### 2026-07-17 最新镜像板测进展

- 最新单槽+Trace pending 镜像于 09:23 构建完成：WNS `+3.525 ns`；指定
  `Digilent/210512180081` 下载成功，startup HIGH，枚举 1 个 ILA。
- 快速验证 PASS：`capture_id 2->3->4`，两次均为
  `header/data/status/trigger=1/13/1/1`，checksum/overflow/malformed 为 0，
  `drop_count 1->1`，Profiler snapshot 6，配置恢复成功。
- 60 秒预检（30 秒重采集间隔）PASS：共 4 次采集，`capture_id 0->1->2->4`，
  checksum/overflow/malformed 为 0，`drop_count 0->0`，Profiler snapshot 31。
- 首次 1800 秒正式长稳在 300 秒门禁点判定 FAIL 并主动终止：12 次采集，
  checksum/overflow/malformed 为 0，但 `drop_count 1->4`。终止路径仍成功恢复 LA
  和 Profiler 配置。
- 低频增长与每 30 秒 Monitor 控制/readout 突发相关。单槽只能覆盖一个 Legacy
  写入余量；现有 Profiler 周期和 Trace pending 已消除早期双槽停滞条件，因此下一版
  恢复双槽预留，覆盖 Monitor response 与 Legacy pulse 同窗口到达。
- 2026-07-17 09:51 双槽候选重新构建 PASS：WNS `+3.210 ns`，下载后 startup
  HIGH，枚举 1 个 ILA。
- 双槽候选快速验证 PASS：`capture_id 0->1->2`，两次帧结构均为
  `1/13/1/1`，checksum/drop/overflow/malformed 均为 0，Profiler snapshot 7。
- 双槽候选 60 秒预检 PASS：30 秒重采集间隔，共 4 次采集，最终
  `capture_id=6`，`drop_count 1->1`，checksum/overflow/malformed 为 0，
  Profiler snapshot 28，配置恢复成功。
- 下一门禁：使用同一双槽候选执行 1800 秒正式长稳，不再修改测试参数。
- 带宽感知调度后的正式长稳在 5/10/15 分钟门禁均通过：分别完成
  12/22/32 次采集，`drop_count 0->0`，checksum/overflow/malformed 为 0。
  约 18 分钟后的周期读出仍在尾部停滞（Header 1、Data 11/13、Trigger 1），
  配置恢复成功；该次 1800 秒结果记为 FAIL。
- 根因收敛为容量而非平均带宽：默认 16 项共享 FIFO 无法同时容纳 16 帧 LA
  readout 和最坏后台突发。下一版将 Board Demo `BUFFER_ADDR_WIDTH` 从 4 提升为 6，
  即 64 项 FIFO，并继续保留双槽余量。
- 2026-07-17 10:37，64 项 FIFO 候选构建 PASS：WNS `+4.315 ns`；下载后
  startup HIGH，枚举 1 个 ILA。
- 64 项候选快速验证 PASS：两次完整 `1/13/1/1` 采集，`drop_count 0->0`，
  checksum/overflow/malformed 为 0，Profiler snapshot 8。
- 64 项候选 60 秒预检 PASS：30 秒重采集间隔，共 4 次采集，最终
  `capture_id=6`，稳定窗口 checksum/overflow/malformed 为 0；配置恢复成功。
  验证器摘要已改为冻结恢复前的稳定窗口计数，防止恢复命令产生的 Status 帧污染证据。
