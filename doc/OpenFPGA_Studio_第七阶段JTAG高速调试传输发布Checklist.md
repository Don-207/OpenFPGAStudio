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
- [x] JTAG disabled 配置无 BSCANE2/JTAG ring BRAM；JTAG 配置恰有一个 BSCANE2/RAMB36E2。
- [ ] JTAG+ILA 使用明确独立 chain，Hardware Manager 与 Bridge 可同时工作。
- [x] 精确目标 `Digilent/210512180081` 下载成功，`xcku5p_0` 枚举到 1 个 ILA。
- [x] USER2 mailbox 读取/commit 与 1024-sample ILA 触发上传可在释放线缆后双向恢复。
- [ ] 功能双输出镜像持续吞吐达标；6 MHz 短矩阵当前最高 66,610 B/s，低于门槛。
- [ ] JTAG-only 完成 Debug/Trace/Profiler/LA/AI Debug 数据闭环。
- [ ] 双输出 UART/JTAG Parser 记录及 drop/overflow 统计一致。
- [x] Performance+ILA 发布配置持续 30 分钟有效吞吐 144,500 B/s，达到门槛。
- [x] 30 分钟数据面运行无死锁或崩溃；验证客户端最大 RSS 28,536 KiB。
- [ ] Bridge RSS 时间序列无持续增长（尚未单独采样 Bridge 进程 RSS）。
- [x] 长稳期间 drop/overflow 均为 0；功能镜像超载时 drop 计数可见。
- [ ] cable 或 hw_server 断线恢复至少 3 次，均恢复合法 session/帧边界。
- [ ] ILA 在长稳期间可触发并读取。
- [x] 候选 bitstream、LTX 和实现报告已归档，bitstream/LTX 已记录 SHA-256。
- [x] 性能/长稳 CSV 已记录 SHA-256。
- [ ] 板级截图记录 SHA-256。
- [ ] 使用说明中的 build ID、TCK、block、回退步骤与实测一致。

## 停止发布条件

任一 P0 发布证据未完成，或出现不可见数据丢失、跨 session 拼帧、错误目标自动连接、
无依据 CDC 豁免、USER chain 冲突、持续内存增长、吞吐未达门槛时，保持候选发布状态。
