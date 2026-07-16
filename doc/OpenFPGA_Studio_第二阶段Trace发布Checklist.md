# OpenFPGA Studio 第二阶段 Trace 发布 Checklist

WP3 状态标记：`PASS`已有直接证据，`PENDING`仍需执行，`WAIVED`为仅适用于历史阶段边界且已由后续版本取代。审计日期：2026-07-16。

## 文档

- [x] **PASS** `doc/OpenFPGA_Debug_Protocol_v1.md`包含`0x10..0x14` Trace消息定义。
- [x] **PASS** `doc/OpenFPGA_Trace_使用说明.md`覆盖RTL接入、Viewer使用和验收命令。
- [x] **PASS** `doc/OpenFPGA_Web_Viewer_使用说明.md`描述Trace视图、Inject Sample和JSONL导出。
- [x] **PASS** `doc/OpenFPGA_Studio_第二阶段Trace验证记录.md`记录命令、环境和结果。
- [x] **PASS** `README.md`包含Trace能力、仿真/门禁说明和文档入口。

## RTL

- [x] **PASS** `openfpga_trace_pkg.vh`的类型、长度、status、trace_id与协议文档一致。
- [x] **PASS** `openfpga_trace_adapter.v` payload使用little-endian布局；M9向量通过。
- [x] **PASS** `openfpga_debug_core.v`接入Trace adapter，M10共存仿真证明原Debug消息未回退。
- [x] **PASS** `openfpga_debug_top.v`向用户逻辑暴露Trace API。
- [x] **PASS** DMA、Frame、FIFO、IRQ probe均带`ENABLE`参数。
- [x] **PASS** Board Demo当前源码M10 XSim输出Debug与Trace帧。

## Viewer

- [x] **PASS** Parser解析`TRACE_SPAN_BEGIN/END/MARK/VALUE/DROP`。
- [x] **PASS** begin/end合成span，未匹配end保留为orphan。
- [x] **PASS** Trace视图显示lane、span、mark、Latest Values和details。
- [x] **PASS** 过滤器支持lane、problem/status和时间范围。
- [x] **PASS** Inject Sample覆盖Frame、DMA、FIFO、Interrupt、timeout和drop。
- [x] **PASS** JSONL导出包含Trace记录。

## 回归

- [x] **PASS** `python tools/viewer/protocol_parser_test.py`。
- [x] **PASS** `python tools/viewer/web/run_perf_test.py`：11,192 frames，2,400 spans，2,400 marks，800 values，错误计数为0。
- [x] **PASS** `just trace-adapter-sim`：M9 payload/handshake通过。
- [x] **PASS** `just trace-board-sim`：M10 Debug/Trace共存通过。
- [x] **PASS** `vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl`：当前完整顶层依赖elaboration通过，0 errors。

## 板级

- [x] **PASS** 已用当前WP3 RTL重新生成M36 JTAG+ILA候选bitstream；Vivado 2024.2实现完成，WNS `+3.298 ns`、TNS `0`、未布线网络 `0`、DRC `0 error`。
- [x] **PASS** 当前M36 JTAG+ILA候选bitstream已下载到`Digilent/210512180081`的`xcku5p_0`；启动状态HIGH，刷新后枚举1个ILA，JTAG build ID为`0x4D360001`。
- [ ] **PENDING** Web Viewer连接当前候选板卡串口并记录浏览器/版本。
- [x] **PASS** 当前板级UART数据包含Debug、Status、Trace和Watch，10秒基线checksum/version error为0。
- [x] **PASS** Windows Chrome板级截图确认Trace视图渲染Frame、DMA、FIFO、Interrupt四条泳道。
- [x] **PASS** Windows Chrome板级截图确认DMA timeout使用红色problem样式高亮。
- [x] **PASS** 1800秒Monitor共存长稳期间持续解析背景协议流，checksum error为0，启动sync drops未增长。
- [x] **PASS** 当前候选bitstream连续15秒收到750个STATUS帧，`drop_count`首值、末值和最大值均为0；无增长，无需丢帧归因。

## 发布边界

- [x] **WAIVED** 第二阶段历史发布只承诺Trace；当前v1.0候选已包含后续Monitor/Profiler/LA/AI能力。
- [x] **WAIVED** Monitor入口历史上留给第三阶段；当前协议已按第三阶段设计加入双向控制。
- [x] **WAIVED** Profiler/Logic Analyzer/AI Debug历史上属于后续规划；当前均已有实现和独立门禁。

## WP3 结论

文档、RTL、Viewer、软件回归、XSim、Vivado elaboration、候选镜像构建/下载及板级视觉验收均为PASS。截图同时暴露并修复了32位timestamp回绕导致负duration的问题；当前只剩补录Windows Chrome精确版本号。
