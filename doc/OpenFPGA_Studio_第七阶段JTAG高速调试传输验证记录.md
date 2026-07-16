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
- [ ] 同一线缆真正并发读取（当前 direct-MPSSE 与 Hardware Manager 互斥）。
- [x] 6 MHz performance+ILA 矩阵完成：256 B 78,931 B/s、512 B 122,970 B/s、
  1024 B 222,880 B/s；512/1024 B 达到发布门槛。
- [x] 30 分钟数据面长稳通过：260,101,120 B、平均 144,500 B/s、3 次客户端重连，
  overflow/drop/slow-client 均为 0。
- [ ] Bridge 进程 RSS 时间序列验证无持续增长（当前记录的是验证客户端最大 RSS）。
- [ ] cable 或 hw_server 断线恢复 3 次。
- [ ] JTAG-only Debug/Trace/Profiler/LA/AI Debug 板级闭环。
- [ ] UART/JTAG 双输出 Parser 记录比较通过。

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
| 3 次物理重连 | 待执行 | 待补 | PENDING |

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
