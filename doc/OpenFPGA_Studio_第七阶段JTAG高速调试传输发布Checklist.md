# OpenFPGA Studio 第七阶段 JTAG 高速调试传输发布 Checklist

## P0 自动化与实现

- [x] M32 Mailbox ABI、模型和 fixture 已冻结。
- [x] M33 BSCAN/CDC RTL 与仿真入口已存在。
- [x] M34 Host Bridge、精确目标选择、commit 和重连回归已存在。
- [x] M35 Viewer 共用 Parser、Bridge 状态和性能 source 已存在。
- [x] M36 `ENABLE_JTAG=0` 从 board top 结构性裁剪 JTAG Transport。
- [x] M36 normal build ID 为 `0x4D360001`，与 M34/M35 证据可区分。
- [x] `just m36-check` 离线发布回归入口已收口。
- [x] `just m36-matrix` 构建矩阵和 BSCANE2 数量门禁已收口。
- [x] `just m36-soak` 长稳 CSV、吞吐、CPU/RSS、drop/overflow 和客户端重连记录入口已收口。

## P0 发布证据

- [x] `just m36-check` 本轮全部通过（2026-07-15）。
- [x] 五配置 Vivado 2024.2 综合矩阵通过，资源/CDC/clock interaction 报告归档。
- [x] JTAG+ILA 发布候选实现 WNS +3.298 ns、TNS 0、WHS +0.017 ns，DRC 无阻断错误。
- [x] 严格功能 JTAG-only+ILA 镜像完成实现：`ENABLE_UART=0`、`JTAG_PERF_MODE=0`，
  WNS +3.003 ns、TNS 0、WHS +0.013 ns，DRC 0 error（2026-07-17）。
- [x] JTAG disabled 配置无 BSCANE2/JTAG ring BRAM；JTAG 配置恰有一个 BSCANE2/RAMB36E2。
- [x] JTAG/ILA 发布边界已冻结：独立 chain 且释放线缆后交替恢复通过；当前不支持同一
  FT232H 上 Hardware Manager 与 direct-MPSSE Bridge 真并发，列为 v1.0 明确限制。
- [x] 精确目标 `Digilent/210512180081` 下载成功，`xcku5p_0` 枚举到 1 个 ILA。
- [x] USER2 mailbox 读取/commit 与 1024-sample ILA 触发上传可在释放线缆后双向恢复。
- [ ] 功能双输出镜像持续吞吐达标；6 MHz 短矩阵当前最高 66,610 B/s，低于门槛。
- [x] JTAG-only 完成 Debug/Trace/Profiler/LA/AI Debug 数据闭环（2026-07-17；
  UART RX 命令、JTAG Monitor 响应与数据，9,112 帧、0 协议错误）。
- [x] 双输出 UART/JTAG Parser 记录一致：60 秒 UART 3,360 帧全部按序匹配 JTAG，
  对齐率 100%，两路 checksum/version error=0；drop/overflow 观察窗口内不增长。
- [x] Performance+ILA 发布配置持续 30 分钟有效吞吐 144,500 B/s，达到门槛。
- [x] 30 分钟数据面运行无死锁或崩溃；验证客户端最大 RSS 28,536 KiB。
- [x] Bridge 本体 RSS 时间序列无持续增长（2026-07-17，30 秒/7 点，22,540 KiB ->
  22,540 KiB，`m36_wp5/bridge_rss.csv`）。
- [x] 长稳期间 drop/overflow 均为 0；功能镜像超载时 drop 计数可见。
- [x] FT232H cable 物理断线恢复 3 次，Bridge backend reconnects=3；恢复后持续合法帧，
  session 未变化，overflow/drop/slow-client 均为 0（2026-07-17）。
- [ ] ILA 在长稳期间可触发并读取。
- [x] 候选 bitstream、LTX 和实现报告已归档，bitstream/LTX 已记录 SHA-256。
- [x] 性能/长稳 CSV 已记录 SHA-256。
- [ ] 板级截图记录 SHA-256。
- [ ] 使用说明中的 build ID、TCK、block、回退步骤与实测一致。

## 停止发布条件

任一 P0 发布证据未完成，或出现不可见数据丢失、跨 session 拼帧、错误目标自动连接、
无依据 CDC 豁免、USER chain 冲突、持续内存增长、吞吐未达门槛时，保持候选发布状态。

## 2026-07-17 WP5 普通功能流复核

- M36 normal build `0x4D360001`、6 MHz、1024 B，JTAG capture 共 224,166 B、
  14,051 个合法 Debug Protocol 帧，checksum/version error 均为 0。
- JTAG 流包含 Debug、Trace、Profiler snapshot/alert，以及两次 LA capture 的
  header/trigger/data/status；因此共享 Parser 与 AI Debug 的普通功能输入已具备板级原始证据。
- 同一 30 秒窗口 UART/JTAG 分别收到 26,567/26,565 B，速率 885.6/883.9 B/s，
  基础业务类型分布一致；但 UART 出现 1 个 checksum error，历史 Debug Core drop 从 3
  增至 4，故“双输出完整性一致”仍保持未签署。
- 普通功能镜像实测速率约 0.884 KB/s，明确不承担 100 KB/s 性能承诺；100 KB/s 仅由
  performance build 验收，不能替代本节功能完整性证据。
- 原始证据位于 `prj/OpenFPGAStudio.runs/m36_wp5/`：`jtag_raw.bin` SHA-256
  `60276c5978f5628c1c9950de163a49b48cf623ae153ef87fb592764b21e8316d`，RSS CSV
  SHA-256 `dd17243fe21f6a8c2d8057bc73bc464383c0ecdeec82e0bd358c141d7bf88e9b`。

## 2026-07-17 严格 JTAG-only 构建证据

- 配置：`m36_jtag_only_ila`，`ENABLE_UART=0`、`ENABLE_JTAG=1`、
  `JTAG_PERF_MODE=0`、USER2、1 个 BSCANE2、1 个 ILA。
- 实现：WNS +3.003 ns、TNS 0、WHS +0.013 ns、THS 0；11,086 个可布线网络
  全部完成，routing error 0。
- DRC：0 error，3 个 PDCN-1569 和 1 个 RTSTAT-10 warning 均来自 Vivado debug hub。
- CDC：9 个 CDC-3 info、2 个 CDC-9 info；4 个 CDC-15 warning 均来自 debug hub。
- bitstream SHA-256：`b8e9700043abbf3728000f6ee58897e7bcebe7a3582a29fb170994bc56057336`。
- LTX SHA-256：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`。
- 本节只签署构建；下载、JTAG 功能流和 ILA 枚举完成前，JTAG-only 板级闭环仍未签署。

## 2026-07-17 严格 JTAG-only 板级证据

- 用户通过精确目标 `Digilent/210512180081` 下载成功，program Tcl 确认枚举 1 个 ILA。
- `validate_jtag_only_board.py` 通过 UART RX 发送 Monitor 命令，Monitor read/write 响应
  只从 JTAG Bridge 返回；Profiler snapshot/alert 和 LA header/13 data/status/trigger 齐全。
- 完整原始捕获 146,376 B、9,112 帧，checksum/version/sync error 均为 0；包含
  Debug、Trace、Profiler、LA 以及 AI Debug 共享 Parser 所需数据。
- 15 秒基础窗口 13,323 B，3 次客户端重连，overflow/drop/slow-client 均为 0。
- Profiler/LA 临时配置在验证结束后读取确认恢复。
- JTAG-only raw SHA-256：`977dbb676d272df805b5898fe7703b83077092a5e5b176921353c7c2386383bf`；
  bridge CSV SHA-256：`8ea47c21f13632f9760c64cf601299e6afba4da20a994e8bcdf55430a7233b93`。

## 剩余项执行边界

- 自动 FT232H USB reset 在当前主机返回 `EPERM`，没有产生重连，不能记为 PASS；保留
  `just m36-ftdi-reset` 供具备设备 reset 权限的环境复跑。
- 随后人工物理拔插 FT232H 三次完成门禁：90.032 秒、51,428 B、Bridge reconnects=3，
  session record=0，overflow/drop/slow-client=0。CSV SHA-256：
  `ec6ca5be329a028de8929097e44ddc4a84f251750e596e1bcb2dfb32200f9b52`。
- Hardware Manager backend 的 raw USER read/commit 尚为 error stub，同线缆 ILA/USER2
  真并发在当前实现中不可用；已验证的是两者释放线缆后的安全交替恢复。

## 2026-07-17 normal 双输出复核

- 同窗口 UART 3,360 帧全部按序匹配 JTAG capture，对齐率 1.000000；UART/JTAG
  checksum/version error 均为 0，先前偶发 UART checksum error 未复现。
- 60 秒 JTAG 客户端窗口收到 53,122 B，884.696 B/s。启动前历史 mailbox
  overflow/drop 为 79,051；独立 15 秒稳定窗口 first/last 均为 115,605，证明观察期间
  无新增丢弃（两次启动之间无人读取造成的历史累计不归入验证窗口）。
- UART raw SHA-256：`cf8d854744e6f69bcdfc1a5d0d946827d43fead4e24db4172414416104eb9a12`；
  JTAG raw SHA-256：`59b43124200e0cb6f36958427e4abaf03f09017f7b43471c3d217fd64c363ce4`；
  counter stability CSV SHA-256：
  `36a8420858c04b45c17ba3e707606ce2d5d1851485c1afaebdc45a972e20f4b3`。
