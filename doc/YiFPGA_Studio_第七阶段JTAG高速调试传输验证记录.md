# OpenFPGA Studio 第七阶段 JTAG 高速调试传输验证记录

## 验证基线

- 日期：2026-07-15
- 目标器件：Xilinx Kintex UltraScale `xcku5p-ffvb676-2-i`
- Transport USER chain：USER2
- M36 normal build ID：`0x4D360001`
- M35 performance build ID：`0x4D350001`
- 发布最低持续吞吐：100,000 B/s

## 自动化入口

| 范围 | 命令 | 证据 |
|---|---|---|
| M32–M35 + M36 离线回归 | `just m36-check` | 终端日志 |
| 构建裁剪矩阵 | `just m36-matrix` | `prj/OpenFPGAStudio.runs/m36_matrix/*` |
| JTAG+ILA 实现镜像 | `just m36-ila-bitstream` | `prj/OpenFPGAStudio.runs/m36_ila/*` |
| 30 分钟 Bridge 数据面 | `just m36-soak` | `prj/OpenFPGAStudio.runs/m36/m36_soak.csv` |

`m36-matrix` 对 UART/JTAG/双输出/JTAG disabled/performance 五个综合配置记录
utilization、CDC、clock interaction 和 manifest，并强制检查启用配置恰有一个 BSCANE2、
禁用配置没有 BSCANE2。综合、实现、bitstream 与下载按实施计划分别授权执行。

`m36-soak` 记录有效吞吐、数据到达间隔 P50/P99、验证进程 CPU/最大 RSS、buffer、
drop/overflow、Bridge 重连和慢客户端计数；默认运行 1800 秒并主动重连本地客户端 3 次。
该客户端重连不等价于 cable/hw_server 断线，后者必须人工执行并单独记录。

## 本轮结果

- [x] M36 normal build ID 与 M35 performance build ID 已区分。
- [x] `ENABLE_JTAG=0` 具备结构性裁剪路径，禁用分支不实例化 performance source 或 BSCAN Transport。
- [x] 多目标 Bridge 仍要求精确 `--target`，重连重新校验稳定 identity/build ID。
- [x] `just m36-check` 于 2026-07-15 通过：FTDI/MPSSE 3 项、FTDI backend 3 项、
  Bridge 9 项、Parser、Viewer 性能样例及 M36 recorder 2 项全部通过。
- [x] 五配置 Vivado 2024.2 综合矩阵通过（2026-07-15）：每项 0 errors、
  0 critical warnings；manifest、utilization、CDC、clock interaction 已归档。
- [x] JTAG+ILA 实现、布线和时序通过：WNS +3.298 ns、TNS 0、WHS +0.017 ns、
  0 routing errors、1 个 USER2 BSCANE2、1 个 ILA（2026-07-15）。
- [x] M36 bitstream 已下载到精确目标 `Digilent/210512180081` / `xcku5p_0`，
  Hardware Manager 刷新后枚举到恰好 1 个 ILA（2026-07-15）。
- [x] 交替共存通过：M36 USER2 header/build/session/payload/commit 合法；释放 direct-MPSSE
  后 Hardware Manager 恢复并完成 1024-sample ILA 触发/上传。
- [x] 同线缆并发边界已冻结：当前不支持；独立 chain 和释放线缆后的交替恢复通过，
  vendor raw USER-DR adapter 留待后续版本。
- [x] 6 MHz performance+ILA 矩阵完成：256 B 78,931 B/s、512 B 122,970 B/s、
  1024 B 222,880 B/s；512/1024 B 达到发布门槛。
- [x] 30 分钟数据面长稳通过：260,101,120 B、平均 144,500 B/s、3 次客户端重连，
  overflow/drop/slow-client 均为 0。
- [x] Bridge 进程 RSS 时间序列验证无持续增长（2026-07-17：30 秒、7 个样本，
  22,540 KiB 恒定；证据 `m36_wp5/bridge_rss.csv`）。
- [x] FT232H cable 物理断线恢复 3 次（2026-07-17）。
- [x] JTAG-only Debug/Trace/Profiler/LA/AI Debug 板级闭环（2026-07-17）。
- [x] UART/JTAG 双输出 Parser 记录比较通过（2026-07-17，3,360 帧全部匹配）。

未勾选项完成前，状态为“候选发布”，不得宣称第七阶段正式发布。

## 已知限制与判读

- 当前 direct FT232H backend 的 mailbox 最大 block 为 1024 B；2 KB/4 KB 项只能在提升
  Mailbox ABI/后端上限后测试，不能用拆分后的 1 KB 事务冒充单次大 block。
- `validate_m36_release.py` 的 P50/P99 是 Host 收到 DATA record 的到达间隔，不是 FPGA
  单字节链路延迟；端到端命令 RTT 需另行采样。
- ILA 使用 debug hub，Transport 使用 USER2。只有实现后 Hardware Manager 同时枚举、触发、
  读取的记录才能证明共存；静态 chain 约定本身不算板级通过。
- JTAG-only 已改为由 mailbox ready 直接驱动 packetizer，不受 UART 波特率限制；双输出为了保持
  UART 帧完整仍由 UART ready 定拍，JTAG 满时通过 transport drop/overflow 计数显式呈现。
  M35 performance source 的吞吐仍不代表普通双输出业务流吞吐。
- `just m36-ftdi-bridge` 强制期望 M36 build ID；旧的 M34 默认值保留用于向后兼容。

## 待填板级记录

| 项目 | 参数/结果 | 证据路径 | 结论 |
|---|---|---|---|
| Vivado/线缆/器件 | 2024.2 / Digilent/210512180081 / xcku5p_0 | hw_server 下载日志 | PASS |
| JTAG+ILA 枚举 | 下载成功，1 个 ILA，USER2 Transport 待并发读取 | hw_server 刷新日志 | PARTIAL |
| 功能镜像短性能 | 6 MHz：256 B 66,610 B/s；512 B 53,760 B/s；1024 B 21,122 B/s | 终端日志 | FAIL（未达 100 KB/s） |
| Performance+ILA 短矩阵 | 6 MHz：256 B 78,931；512 B 122,970；1024 B 222,880 B/s | 终端日志 | PASS（推荐 1024 B） |
| 30 分钟长稳 | 144,500 B/s；260,101,120 B；P50/P99 7.516/10.614 ms；3 次客户端重连 | `m36_perf_ila/m36_soak.csv` | PASS |
| 3 次物理重连 | 90.032 秒，51,428 B，Bridge reconnects=3；session不变，overflow/drop=0 | `m36_wp5/physical_reconnect.csv` | PASS |

### 2026-07-17 普通功能流补充证据

当前 M36 normal build `0x4D360001` 未重刷，使用 direct FT232H、6 MHz TCK、1024 B
block 采集。JTAG 原始流 224,166 B，解析为 14,051 帧，checksum/version error 为 0；
其中 Profiler snapshot 67、alert 19，LA header/data/status/trigger 分别为 2/26/2/2，
并持续包含 Debug、Trace、Status、Watch 和 Event。UART 完成两次 LA capture 和 Profiler
临时配置后均读取确认恢复。

同一 30 秒窗口 UART/JTAG 字节数为 26,567/26,565，基础类型和速率近似一致；UART
出现 1 个 checksum error，后续 Profiler 窗口再次出现 1 个 checksum error，Debug Core
历史 drop 由 3 增至 4。因此本轮证明了 JTAG 普通功能流的 Parser 完整性，但不把双输出
逐帧一致性标为 PASS。当前 direct backend 与 Hardware Manager 对 FT232H 仍互斥，3 次
物理 cable/hw_server 恢复也尚未执行，阶段状态继续保持候选发布。

### 2026-07-17 严格 JTAG-only+ILA 构建

用户执行 `just m36-jtag-only-ila-bitstream` 完成实现。manifest 确认
`ENABLE_UART=0`、`ENABLE_JTAG=1`、`JTAG_PERF_MODE=0`、USER2、1 个 BSCANE2、
1 个 ILA。WNS +3.003 ns、TNS 0、WHS +0.013 ns，routing error 0，DRC 0 error。
DRC/CDC warning 均限定在 Vivado debug hub，与既有 M36 共存证据一致。

bitstream SHA-256 为
`b8e9700043abbf3728000f6ee58897e7bcebe7a3582a29fb170994bc56057336`，LTX
SHA-256 为 `019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
构建完成时尚未把该镜像标为板级 PASS；精确目标下载、ILA 枚举和 JTAG 普通功能流读取
由下一节板级记录完成签署。

### 2026-07-17 严格 JTAG-only 板级闭环

用户执行精确目标下载成功，program Tcl 确认枚举 1 个 ILA。随后 direct FT232H Bridge
读取 build `0x4D360001`。15 秒基础窗口收到 13,323 B，完成 3 次客户端重连，mailbox
overflow/drop、slow client 均为 0。

新增 `tools/jtag/validate_jtag_only_board.py`，从 UART RX 写入 Monitor 命令，但只从
JTAG Bridge 接收 Monitor read/write response、Profiler 和 LA 帧。验证收到 Profiler
snapshot/alert 及 LA header/13 data/status/trigger，临时配置在 finally 中恢复。完整 capture
为 146,376 B、9,112 帧，checksum/version/sync error 均为 0。raw SHA-256 为
`977dbb676d272df805b5898fe7703b83077092a5e5b176921353c7c2386383bf`。

该结果关闭严格 JTAG-only 功能闭环缺口；AI Debug 使用同一 Parser 数据模型，离线
`m36-check` 已覆盖对应诊断工作流。物理 cable/hw_server 三次恢复和同线缆真正并发读取
仍保持独立未签署项。

### 2026-07-17 剩余重连/并发项复核

- 新增精确 VID/PID、拒绝多匹配的 `reset_usb_device.py` 和
  `--min-bridge-reconnects` 门禁；当前主机对 `USBDEVFS_RESET` 返回 `EPERM`，实际 reset
  次数为 0，Bridge reconnect 仍为 0。本轮不计作物理恢复证据，需物理拔插 FT232H 三次
  或由管理员授予对应 USB reset 权限后复跑。
- Xilinx Hardware Manager backend 当前不能支持同线缆 Bridge：
  `openfpga_jtag_read.tcl` 的 `ofjt_shift_read` 和 `ofjt_shift_commit` 是显式未实现的
  error stub。因此当前只能签署 direct-MPSSE USER2 与 Hardware Manager/ILA 的安全交替
  恢复，不能宣称真正并发。关闭该项需要实现并验证 vendor raw USER-DR adapter，或在
  v1.0 发布边界中明确列为不支持。

人工物理拔插 FT232H 三次后，`validate_m36_release.py --min-bridge-reconnects 3`
通过：90.032 秒收到 51,428 B，Bridge backend reconnects=3，session record=0，
overflow/drop/slow-client 均为 0，P50/P99 数据到达间隔为 53.359/57.834 ms。
证据 `m36_wp5/physical_reconnect.csv` SHA-256 为
`ec6ca5be329a028de8929097e44ddc4a84f251750e596e1bcb2dfb32200f9b52`。

### 2026-07-17 normal 双输出逐帧复核

UART/JTAG 同窗口采集后使用 `compare_transport_captures.py` 按完整 Debug Protocol 帧
对齐。UART 的 3,360 帧全部按序出现在 JTAG 流中，common ratio=1.000000；两路
checksum/version error 均为 0。60 秒 JTAG 窗口 53,122 B、884.696 B/s。

Mailbox counter 是上电以来的累计值：Bridge 首次启动前为 79,051；两次 Bridge 之间
无人读取时继续累计到 115,605。随后 15 秒受控窗口的 overflow/drop first/last 都是
115,605，证明验证窗口内没有新增 drop。UART/JTAG raw 及稳定性 CSV 均归档于
`prj/OpenFPGAStudio.runs/m36_wp5/`。

当前 Hardware Manager backend 的 raw USER shift/commit 为未实现 stub，因此 v1.0 不承诺
同一 FT232H 上 ILA 与 direct Bridge 真并发；发布能力定义为独立 USER chain、精确目标选择，
以及释放线缆后的双向交替恢复。该限制不影响已签署的 JTAG-only、双输出和物理重连闭环。

## M36 JTAG+ILA 构建证据（2026-07-15）

- Vivado：2024.2，器件 `xcku5p-ffvb676-2-i`。
- bitstream SHA-256：`81d878a4e9f8bc78832f9a54e9a27bbbe5e5686bbd555275a381d72145d13eec`。
- LTX SHA-256：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
- ILA CSV：1024 samples，SHA-256
  `ad3d3d6b3af3c104f6414deae6cf1b30635d8e6ac037d8ed892135512916e120`。
- DRC：0 errors；4 个 warning 均位于 Vivado 生成的 debug hub（3 个 PDCN-1569、
  1 个 RTSTAT-10），未发现用户 Transport 结构违规。
- CDC：9 个 ASYNC_REG 单 bit同步、2 个异步复位同步；4 个 CDC-15 warning 均位于
  Vivado debug hub 的异步 FIFO RAM/寄存输出结构，未发现用户 JTAG mailbox 的未同步多 bit CDC。
- FT232H direct-MPSSE 和 Vivado Hardware Manager 对同一物理线缆互斥；当前可验证安全交替恢复，
  不能宣称 ILA 上传与 Host Bridge 同时占用线缆。真正并发需要 Hardware Manager raw USER-DR
  适配器或第二条独立调试链路。

## M36 Performance+ILA 证据（2026-07-15）

- 配置：`ENABLE_UART=0`、`ENABLE_JTAG=1`、`JTAG_PERF_MODE=1`、6 MHz、1024 B。
- 实现：WNS +3.730 ns、TNS 0、WHS +0.013 ns、1 个 BSCANE2、1 个 ILA。
- bitstream SHA-256：`ff6188bed396b8a2a7bfadb471a03dfc5fb1918a666699d6bbee77e2fa1f7ee5`。
- LTX SHA-256：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
- 长稳 CSV SHA-256：`7f8b211421016474fac0d2cf620fd009a75ca4ad3943d95edad7d13dd3b1ab2c`。
- 30 分钟平均 144,500.009 B/s，payload 260,101,120 B，P50 7.516 ms，
  P99 10.614 ms，客户端 CPU 0.426%，最大 RSS 28,536 KiB。
- 3 次客户端断开重连共收到 4 个合法 HELLO；session 未改变；overflow、drop、
  Bridge reconnect、slow client 均为 0。
- 2 KiB/4 KiB 单事务超过冻结的 1024 B Mailbox ABI 上限，记为不适用。
