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

- [ ] **PENDING** 用当前WP3 RTL重新生成并下载候选bitstream；默认周期参数新增后尚未重建。
- [ ] **PENDING** Web Viewer连接当前候选板卡串口并记录浏览器/版本。
- [x] **PASS** 当前板级UART数据包含Debug、Status、Trace和Watch，10秒基线checksum/version error为0。
- [ ] **PENDING** 人工确认Trace视图的Frame、DMA、FIFO、Interrupt泳道。
- [ ] **PENDING** 人工确认板级DMA timeout/error高亮。
- [x] **PASS** 1800秒Monitor共存长稳期间持续解析背景协议流，checksum error为0，启动sync drops未增长。
- [ ] **PENDING** 当前候选bitstream下记录`drop_count`最终值及增长解释。

## 发布边界

- [x] **WAIVED** 第二阶段历史发布只承诺Trace；当前v1.0候选已包含后续Monitor/Profiler/LA/AI能力。
- [x] **WAIVED** Monitor入口历史上留给第三阶段；当前协议已按第三阶段设计加入双向控制。
- [x] **WAIVED** Profiler/Logic Analyzer/AI Debug历史上属于后续规划；当前均已有实现和独立门禁。

## WP3 结论

文档、RTL、Viewer、软件回归、XSim和Vivado elaboration均为PASS。第二阶段Trace不能单独标记为当前v1.0板级发布完成，剩余阻塞为候选bitstream重建/下载、Viewer人工泳道与异常高亮确认、以及`drop_count`记录。
