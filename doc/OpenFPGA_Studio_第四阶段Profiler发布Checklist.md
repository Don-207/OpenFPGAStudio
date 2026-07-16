# OpenFPGA Studio 第四阶段 Profiler 发布 Checklist

WP3状态标记：`PASS`已有直接证据，`PENDING`仍需执行，`WAIVED`为历史环境已由当前候选复测取代。审计日期：2026-07-16。

- [x] **PASS** `OpenFPGA_Debug_Protocol_v1.md`定义`PROFILER_SNAPSHOT/ALERT` payload。
- [x] **PASS** Parser回归覆盖snapshot、alert、malformed和checksum error。
- [x] **PASS** M18 Profiler Core XSim通过。
- [x] **PASS** M19四类Probe XSim通过；新增稳定FIFO level不得重复发出累计metric的断言。
- [x] **PASS** M20 Web Viewer Profiler指标卡、趋势、alert和控制视图已实现。
- [x] **PASS** M21 Board Demo RTL接入Profiler core、adapter和四类demo probe。
- [x] **PASS** M21 Monitor register map接入Profiler控制、状态和阈值寄存器。
- [x] **PASS** M21 Board Demo XSim通过。
- [x] **PASS** M21完整当前顶层Vivado elaboration通过，0 critical warning、0 error。
- [x] **PASS** Profiler使用说明与Probe接入说明已存在。
- [x] **PASS** 本轮Parser与Web Viewer压力回归通过：11,194帧，checksum/sync/unknown均为0，Profiler正常与异常路径均覆盖。
- [x] **PASS** 当前RTL重新生成M36 UART+JTAG+ILA候选镜像；Vivado 2024.2，WNS `+3.522 ns`、TNS `0`、未布线网络`0`、DRC `0 error`。
- [x] **PASS** 候选镜像已下载到`Digilent/210512180081`的`xcku5p_0`，startup HIGH且枚举1个ILA。
- [x] **WAIVED** 历史COM7板级结果仅作为旧环境记录；当前候选已在Ubuntu `/dev/ttyUSB1`重新完成更严格验证，不再以COM7作为发布依据。
- [x] **PASS** 当前候选120秒预检通过：483 snapshots、121 alerts、6000 status，checksum error与设备drop均为0。
- [x] **PASS** 当前候选1800秒长稳通过：7203 snapshots、1801 alerts、90000 status，checksum error与设备drop均为0；FIFO overflow峰值为0，配置恢复成功。
- [ ] **PENDING** Windows Edge人工确认Profiler指标卡、趋势、alert和控制状态显示，并保存截图或观察记录。

## WP3当前结论

Profiler RTL重复累计缺陷已经修复，离线回归、当前候选构建/下载及30分钟实板长稳均为PASS。仅剩Windows Edge Web Viewer人工视觉签署；完成该项后可关闭第四阶段Profiler复核。
