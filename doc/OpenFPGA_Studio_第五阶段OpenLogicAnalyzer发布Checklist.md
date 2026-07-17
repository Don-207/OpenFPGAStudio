# OpenFPGA Studio 第五阶段 Open Logic Analyzer 发布 Checklist

- [x] Debug Protocol v1 定义 LA `0x40..0x46` 类型和 payload。
- [x] Parser 回归包含 LA 完整、缺块、乱序、malformed 和 checksum 场景。
- [x] Web Viewer 具备无硬件样例、波形视图和 VCD/JSONL 导出。
- [x] M23 LA Core XSim testbench 已存在。
- [x] M25 board demo XSim testbench 已存在。
- [x] M25 Vivado RTL elaboration 脚本已存在。
- [x] Monitor `0x0060..0x0094` register map 已接入。
- [x] Logic Analyzer 使用说明已完成。
- [x] M26 Python 串口验证器及离线自测已完成。
- [x] M26 回归、bitstream、program 和 board validate 命令已收口到 `justfile`。
- [x] 本轮 Parser、LA validator self-test、M23 Core XSim、M25 Board XSim 通过。
- [x] 本轮 Viewer 无硬件样例通过。
- [x] 本轮 `just la-elab` 通过（Vivado 2020.2，0 warnings/critical warnings/errors）。
- [x] M26 bitstream 已生成并记录 Vivado/part/path；当前目录非 Git 工作树，commit 待补。
- [x] Profiler latency average 已改为 32 周期精确 restoring divider，M19/M21/M25 仿真通过。
- [x] 修复后重新实现 timing closure：WNS +3.945 ns，TNS 0，setup/hold/pulse-width 均 0 failing endpoints。
- [x] 指定 JTAG target `Digilent/210512180081` / `xcku5p_0` 下载成功。
- [x] COM8 真实串口 arm、force-trigger、readout、clear 和 capture_id 递增通过，checksum errors=0。
- [x] Windows Edge Viewer 波形、触发位置和 11 路通道名通过：capture_id=0x3F，64 samples，13/13 chunks，malformed=0。
- [x] VCD/JSONL 导出文件人工检查通过：capture_id=0x42，divisor=50000，64 samples，13/13 chunks，解析计数全零。
- [x] stop/clear/re-arm 和 capture_id 递增通过。
- [x] Debug/Trace/Monitor/Profiler/LA 30 分钟共存长稳通过：62 次采集，drop/checksum/overflow/malformed=0。

## P0 已知限制

- 单采样时钟域；跨域 probe 需先同步。
- sample width 固定 32 bit，推荐 depth 32–128。
- 捕获后通过共享 UART 分片读出，不是连续流式采集。
- 不支持压缩波形、复杂序列触发，也不替代 Vivado ILA/SignalTap。

所有未勾选的硬件项完成前，第五阶段保持候选发布状态。
